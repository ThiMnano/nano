[CmdletBinding()]
param()

#region Assembly Loading
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
}
catch {
    Write-Error "Erro ao carregar assemblies do Windows Forms: $_"
    exit 1
}
#endregion

#region Global Variables
$script:Config = @{
    pgBinPath = $null
    pgRestorePath = $null
    psqlPath = $null
    pgDumpPath = $null
    FormTitle = "PostgreSQL Backup & Restore Pro"
    Version = "2.2"  # Versão atualizada com melhorias na criação de banco
}

$script:PredefinedHosts = @{
    "localhost" = @{
        Port = "5432"
        User = "postgres"
        Pass = ""
    }
    "cloud1.sistemasnano.com.br" = @{
        Port = "5432"
        User = "postgres"
        Pass = ""
    }
    "cloud2.sistemasnano.com.br" = @{
        Port = "5432"
        User = "postgres"
        Pass = ""
    }
}

# UI Controls - declarados em escopo de script para acesso global
$script:UI = @{
    Form = $null
    rtbLog = $null
    # Backup Tab
    cboHostBkp = $null
    txtPortBkp = $null
    txtUserBkp = $null
    txtPassBkp = $null
    cboDBBkp = $null
    btnConnectBkp = $null
    btnBackup = $null
    # Restore Tab
    txtHostRestore = $null
    txtPortRestore = $null
    txtUserRestore = $null
    txtPassRestore = $null
    txtFileRestore = $null
    btnTestConnection = $null
    btnRestore = $null
}
#endregion

#region Logging Functions
function Write-Log {
    <#
    .SYNOPSIS
        Escreve mensagem no log com timestamp
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    try {
        if ($null -eq $script:UI.rtbLog) { return }
        
        $timestamp = Get-Date -Format "HH:mm:ss"
        $prefix = switch ($Level) {
            'Success' { '✓' }
            'Error'   { '✗' }
            'Warning' { '⚠' }
            default   { '•' }
        }
        
        $color = switch ($Level) {
            'Success' { [System.Drawing.Color]::LimeGreen }
            'Error'   { [System.Drawing.Color]::Red }
            'Warning' { [System.Drawing.Color]::Yellow }
            default   { [System.Drawing.Color]::LightGray }
        }
        
        $script:UI.rtbLog.SelectionStart = $script:UI.rtbLog.TextLength
        $script:UI.rtbLog.SelectionLength = 0
        $script:UI.rtbLog.SelectionColor = $color
        $script:UI.rtbLog.AppendText("[$timestamp] $prefix $Message`r`n")
        $script:UI.rtbLog.SelectionColor = $script:UI.rtbLog.ForeColor
        $script:UI.rtbLog.ScrollToCaret()
        
        [System.Windows.Forms.Application]::DoEvents()
    }
    catch {
        Write-Warning "Erro ao escrever log: $_"
    }
}

function Clear-Log {
    <#
    .SYNOPSIS
        Limpa o log
    #>
    [CmdletBinding()]
    param()
    
    if ($null -ne $script:UI.rtbLog) {
        $script:UI.rtbLog.Clear()
    }
}
#endregion

#region PostgreSQL Binary Detection
function Find-PostgreSQLBinaries {
    <#
    .SYNOPSIS
        Detecta automaticamente os binários do PostgreSQL
    .DESCRIPTION
        Procura em múltiplos locais comuns e no registro do Windows
    #>
    [CmdletBinding()]
    param()
    
    Write-Log "Procurando binários do PostgreSQL..." -Level Info
    
    $searchPaths = @()
    
    # 1. Registro do Windows (instalações oficiais)
    try {
        $regPath = "HKLM:\SOFTWARE\PostgreSQL\Installations"
        if (Test-Path $regPath) {
            $installations = Get-ChildItem -Path $regPath -ErrorAction SilentlyContinue
            foreach ($installation in $installations) {
                try {
                    $props = Get-ItemProperty -Path $installation.PSPath -ErrorAction SilentlyContinue
                    if ($props.BaseDirectory) {
                        $binPath = Join-Path $props.BaseDirectory "bin"
                        $searchPaths += $binPath
                        Write-Verbose "Encontrado no registro: $binPath"
                    }
                }
                catch {
                    Write-Verbose "Erro ao ler instalação: $_"
                }
            }
        }
    }
    catch {
        Write-Log "Aviso: Não foi possível acessar registro - $($_.Exception.Message)" -Level Warning
    }
    
    # 2. Program Files (64-bit)
    $programFiles = ${env:ProgramFiles}
    $pgFolder = Join-Path $programFiles "PostgreSQL"
    if (Test-Path $pgFolder) {
        Get-ChildItem -Path $pgFolder -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $binPath = Join-Path $_.FullName "bin"
            if (Test-Path $binPath) {
                $searchPaths += $binPath
                Write-Verbose "Encontrado em Program Files: $binPath"
            }
        }
    }
    
    # 3. Program Files (x86)
    if (${env:ProgramFiles(x86)}) {
        $pgFolderX86 = Join-Path ${env:ProgramFiles(x86)} "PostgreSQL"
        if (Test-Path $pgFolderX86) {
            Get-ChildItem -Path $pgFolderX86 -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $binPath = Join-Path $_.FullName "bin"
                if (Test-Path $binPath) {
                    $searchPaths += $binPath
                    Write-Verbose "Encontrado em Program Files (x86): $binPath"
                }
            }
        }
    }
    
    # 4. pgAdmin 4 runtime
    $localAppData = $env:LOCALAPPDATA
    $pgAdminPaths = @(
        (Join-Path $localAppData "Programs\pgAdmin 4\runtime"),
        (Join-Path $localAppData "Programs\pgAdmin 4\v4\runtime"),
        (Join-Path $localAppData "Programs\pgAdmin 4\v5\runtime"),
        (Join-Path $localAppData "Programs\pgAdmin 4\v6\runtime"),
        (Join-Path $localAppData "Programs\pgAdmin 4\v7\runtime")
    )
    
    foreach ($pgAdminPath in $pgAdminPaths) {
        if (Test-Path $pgAdminPath) {
            $searchPaths += $pgAdminPath
            Write-Verbose "Encontrado pgAdmin: $pgAdminPath"
        }
    }
    
    # 5. PATH environment variable
    $pathEnv = $env:PATH -split ';'
    foreach ($path in $pathEnv) {
        if ($path -match 'postgres' -and (Test-Path $path)) {
            $searchPaths += $path
            Write-Verbose "Encontrado no PATH: $path"
        }
    }
    
    # Remover duplicatas
    $searchPaths = $searchPaths | Select-Object -Unique
    
    Write-Verbose "Total de caminhos para verificar: $($searchPaths.Count)"
    
    # 6. Verificar binários necessários em cada caminho
    $requiredBinaries = @('pg_restore.exe', 'psql.exe', 'pg_dump.exe')
    
    foreach ($binPath in $searchPaths) {
        $foundAll = $true
        $binaryPaths = @{}
        
        foreach ($binary in $requiredBinaries) {
            $fullPath = Join-Path $binPath $binary
            if (Test-Path $fullPath) {
                $binaryPaths[$binary] = $fullPath
            }
            else {
                $foundAll = $false
                break
            }
        }
        
        if ($foundAll) {
            $script:Config.pgBinPath = $binPath
            $script:Config.pgRestorePath = $binaryPaths['pg_restore.exe']
            $script:Config.psqlPath = $binaryPaths['psql.exe']
            $script:Config.pgDumpPath = $binaryPaths['pg_dump.exe']
            
            # Obter versão do PostgreSQL
            try {
                $versionOutput = & $script:Config.psqlPath --version 2>&1
                Write-Log "✓ PostgreSQL encontrado: $binPath" -Level Success
                Write-Log "  Versão: $versionOutput" -Level Info
            }
            catch {
                Write-Log "✓ PostgreSQL encontrado: $binPath" -Level Success
            }
            
            return $true
        }
    }
    
    # Não encontrou
    Write-Log "✗ ERRO: Binários PostgreSQL não encontrados!" -Level Error
    Write-Log "  Caminhos verificados: $($searchPaths.Count)" -Level Error
    
    [System.Windows.Forms.MessageBox]::Show(
        "PostgreSQL não encontrado!`r`n`r`n" +
        "Certifique-se de ter o PostgreSQL instalado.`r`n" +
        "Os seguintes binários são necessários:`r`n" +
        "  • pg_dump.exe`r`n" +
        "  • pg_restore.exe`r`n" +
        "  • psql.exe`r`n`r`n" +
        "Download: https://www.postgresql.org/download/",
        "PostgreSQL não encontrado",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    
    return $false
}
#endregion

#region Connection Functions
function Test-PostgreSQLConnection {
    <#
    .SYNOPSIS
        Testa conexão com servidor PostgreSQL
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,
        
        [Parameter(Mandatory = $true)]
        [string]$Port,
        
        [Parameter(Mandatory = $true)]
        [string]$User,
        
        [Parameter(Mandatory = $true)]
        [string]$Password
    )
    
    if ([string]::IsNullOrWhiteSpace($script:Config.psqlPath)) {
        Write-Log "PostgreSQL não configurado!" -Level Error
        return $false
    }
    
    Write-Log "Testando conexão com $HostName`:$Port..." -Level Info
    
    try {
        $env:PGPASSWORD = $Password
        
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $script:Config.psqlPath
        $psi.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -d postgres -c `"SELECT version();`" -t"
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        
        # Timeout de 10 segundos
        if (-not $process.WaitForExit(10000)) {
            $process.Kill()
            Write-Log "✗ Timeout ao conectar (10s)" -Level Error
            return $false
        }
        
        if ($process.ExitCode -eq 0) {
            $version = $stdout.Trim()
            Write-Log "✓ Conexão bem-sucedida!" -Level Success
            if ($version) {
                Write-Log "  $version" -Level Info
            }
            return $true
        }
        else {
            $errorMsg = if ($stderr) { $stderr.Trim() } else { "Código de saída: $($process.ExitCode)" }
            Write-Log "✗ Falha na conexão: $errorMsg" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "✗ Erro ao testar conexão: $($_.Exception.Message)" -Level Error
        return $false
    }
    finally {
        $env:PGPASSWORD = $null
        if ($process -and -not $process.HasExited) {
            $process.Kill()
        }
    }
}

function Get-DatabaseList {
    <#
    .SYNOPSIS
        Lista todos os bancos de dados não-template
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,
        
        [Parameter(Mandatory = $true)]
        [string]$Port,
        
        [Parameter(Mandatory = $true)]
        [string]$User,
        
        [Parameter(Mandatory = $true)]
        [string]$Password
    )
    
    if ([string]::IsNullOrWhiteSpace($HostName) -or 
        [string]::IsNullOrWhiteSpace($Port) -or 
        [string]::IsNullOrWhiteSpace($User) -or 
        [string]::IsNullOrWhiteSpace($Password)) {
        Write-Log "Dados de conexão inválidos!" -Level Error
        return @()
    }
    
    $sql = "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname"
    
    try {
        $env:PGPASSWORD = $Password
        
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $script:Config.psqlPath
        $psi.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -d postgres -t -A -c `"$sql`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        
        $null = $process.Start()
        $output = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        
        if (-not $process.WaitForExit(10000)) {
            $process.Kill()
            Write-Log "✗ Timeout ao listar bancos" -Level Error
            return @()
        }
        
        if ($process.ExitCode -eq 0) {
            $databases = $output -split "`n" | 
                         ForEach-Object { $_.Trim() } | 
                         Where-Object { $_ -ne "" }
            
            Write-Log "✓ Total de bancos encontrados: $($databases.Count)" -Level Success
            return $databases
        }
        else {
            Write-Log "✗ Erro ao listar bancos: $stderr" -Level Error
            return @()
        }
    }
    catch {
        Write-Log "✗ Erro ao listar bancos: $($_.Exception.Message)" -Level Error
        return @()
    }
    finally {
        $env:PGPASSWORD = $null
    }
}
#endregion

#region Validation Functions
function Test-ConnectionParameters {
    <#
    .SYNOPSIS
        Valida parâmetros de conexão
    #>
    [CmdletBinding()]
    param(
        [string]$HostName,
        [string]$Port,
        [string]$User,
        [string]$Password
    )
    
    $errors = @()
    
    if ([string]::IsNullOrWhiteSpace($HostName)) {
        $errors += "Host não pode ser vazio"
    }
    
    if ([string]::IsNullOrWhiteSpace($Port)) {
        $errors += "Porta não pode ser vazia"
    }
    elseif ($Port -notmatch '^\d+$') {
        $errors += "Porta deve ser um número"
    }
    elseif ([int]$Port -lt 1 -or [int]$Port -gt 65535) {
        $errors += "Porta deve estar entre 1 e 65535"
    }
    
    if ([string]::IsNullOrWhiteSpace($User)) {
        $errors += "Usuário não pode ser vazio"
    }
    
    if ([string]::IsNullOrWhiteSpace($Password)) {
        $errors += "Senha não pode ser vazia"
    }
    
    if ($errors.Count -gt 0) {
        $message = "Erros de validação:`r`n`r`n" + ($errors -join "`r`n")
        [System.Windows.Forms.MessageBox]::Show(
            $message,
            "Validação",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        return $false
    }
    
    return $true
}
#endregion

#region Backup Functions
function Get-BackupType {
    <#
    .SYNOPSIS
        Detecta tipo de arquivo de backup (CUSTOM ou PLAIN)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    try {
        if (-not (Test-Path $FilePath)) {
            return "UNKNOWN"
        }
        
        $bytes = [System.IO.File]::ReadAllBytes($FilePath)
        if ($bytes.Length -ge 5) {
            $header = [System.Text.Encoding]::ASCII.GetString($bytes[0..4])
            if ($header -eq "PGDMP") {
                return "CUSTOM"
            }
        }
        return "PLAIN"
    }
    catch {
        Write-Log "Erro ao detectar tipo de backup: $($_.Exception.Message)" -Level Warning
        return "PLAIN"
    }
}

function Get-DatabaseNameFromBackup {
    <#
    .SYNOPSIS
        Tenta extrair nome do banco do arquivo de backup CUSTOM
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BackupFile,
        
        [Parameter(Mandatory = $true)]
        [string]$Password
    )
    
    try {
        $env:PGPASSWORD = $Password
        
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $script:Config.pgRestorePath
        $psi.Arguments = "-l `"$BackupFile`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        
        $null = $process.Start()
        $output = $process.StandardOutput.ReadToEnd()
        
        if (-not $process.WaitForExit(5000)) {
            $process.Kill()
            return ""
        }
        
        $lines = $output -split "`n"
        foreach ($line in $lines) {
            if ($line -match ";\s*DATABASE\s+-\s+Name:\s+(\S+)" -or
                $line -match "CREATE\s+DATABASE\s+(\S+)") {
                return $matches[1].Trim()
            }
        }
    }
    catch {
        Write-Verbose "Erro ao detectar nome do banco: $_"
    }
    finally {
        $env:PGPASSWORD = $null
    }
    
    return ""
}

function New-PostgreSQLDatabase {
    <#
    .SYNOPSIS
        Cria banco de dados se não existir
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,
        
        [Parameter(Mandatory = $true)]
        [string]$Port,
        
        [Parameter(Mandatory = $true)]
        [string]$User,
        
        [Parameter(Mandatory = $true)]
        [string]$Password,
        
        [Parameter(Mandatory = $true)]
        [string]$DatabaseName
    )
    
    Write-Log "----------------------------------------" -Level Info
    Write-Log "VERIFICANDO/CRIANDO BANCO DE DADOS" -Level Info
    Write-Log "Nome: $DatabaseName" -Level Info
    Write-Log "Host: $HostName`:$Port" -Level Info
    Write-Log "----------------------------------------" -Level Info
    
    try {
        $env:PGPASSWORD = $Password
        
        # Primeiro, testar conexão com postgres (banco padrão)
        Write-Log "Testando conexão com servidor..." -Level Info
        
        $testPsi = New-Object System.Diagnostics.ProcessStartInfo
        $testPsi.FileName = $script:Config.psqlPath
        $testPsi.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -d postgres -c `"SELECT 1;`" -t"
        $testPsi.UseShellExecute = $false
        $testPsi.RedirectStandardOutput = $true
        $testPsi.RedirectStandardError = $true
        $testPsi.CreateNoWindow = $true
        $testPsi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        
        $testProcess = New-Object System.Diagnostics.Process
        $testProcess.StartInfo = $testPsi
        
        $null = $testProcess.Start()
        $testStderr = $testProcess.StandardError.ReadToEnd()
        
        if (-not $testProcess.WaitForExit(10000)) {
            $testProcess.Kill()
            Write-Log "✗ Timeout ao conectar ao servidor" -Level Error
            Write-Log "  Verifique se o PostgreSQL está rodando" -Level Error
            return $false
        }
        
        if ($testProcess.ExitCode -ne 0) {
            Write-Log "✗ Falha ao conectar ao servidor" -Level Error
            Write-Log "  Erro: $testStderr" -Level Error
            Write-Log "  Verifique host, porta, usuário e senha" -Level Error
            return $false
        }
        
        Write-Log "✓ Conexão com servidor OK" -Level Success
        
        # Verificar se banco existe
        Write-Log "Verificando se banco '$DatabaseName' existe..." -Level Info
        
        $checkSql = "SELECT 1 FROM pg_database WHERE datname = '$DatabaseName'"
        
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $script:Config.psqlPath
        $psi.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -d postgres -t -A -c `"$checkSql`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        
        $null = $process.Start()
        $output = $process.StandardOutput.ReadToEnd().Trim()
        $checkStderr = $process.StandardError.ReadToEnd()
        
        if (-not $process.WaitForExit(10000)) {
            $process.Kill()
            Write-Log "✗ Timeout ao verificar banco" -Level Error
            return $false
        }
        
        if ($process.ExitCode -ne 0) {
            Write-Log "✗ Erro ao verificar banco: $checkStderr" -Level Error
            return $false
        }
        
        if ($output -eq "1") {
            Write-Log "✓ Banco '$DatabaseName' já existe - prosseguindo" -Level Success
            return $true
        }
        
        # Criar banco
        Write-Log "Banco não existe - criando '$DatabaseName'..." -Level Info
        
        $createSql = "CREATE DATABASE `"$DatabaseName`""
        
        $psi.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -d postgres -c `"$createSql`""
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        
        if (-not $process.WaitForExit(10000)) {
            $process.Kill()
            Write-Log "✗ Timeout ao criar banco" -Level Error
            return $false
        }
        
        if ($process.ExitCode -eq 0) {
            Write-Log "✓ Banco '$DatabaseName' criado com sucesso!" -Level Success
            
            # Verificar novamente se foi criado
            Start-Sleep -Milliseconds 500
            
            $verifyPsi = New-Object System.Diagnostics.ProcessStartInfo
            $verifyPsi.FileName = $script:Config.psqlPath
            $verifyPsi.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -d postgres -t -A -c `"$checkSql`""
            $verifyPsi.UseShellExecute = $false
            $verifyPsi.RedirectStandardOutput = $true
            $verifyPsi.RedirectStandardError = $true
            $verifyPsi.CreateNoWindow = $true
            $verifyPsi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
            
            $verifyProcess = New-Object System.Diagnostics.Process
            $verifyProcess.StartInfo = $verifyPsi
            
            $null = $verifyProcess.Start()
            $verifyOutput = $verifyProcess.StandardOutput.ReadToEnd().Trim()
            $verifyProcess.WaitForExit()
            
            if ($verifyOutput -eq "1") {
                Write-Log "✓ Verificação confirmada: banco existe no servidor" -Level Success
                Write-Log "----------------------------------------" -Level Info
                return $true
            }
            else {
                Write-Log "✗ AVISO: Banco parece ter sido criado mas verificação falhou" -Level Warning
                Write-Log "  Tentando prosseguir mesmo assim..." -Level Warning
                Write-Log "----------------------------------------" -Level Info
                return $true
            }
        }
        else {
            Write-Log "✗ Erro ao criar banco (Exit code: $($process.ExitCode))" -Level Error
            Write-Log "  Saída de erro: $stderr" -Level Error
            
            # Analisar erro comum
            if ($stderr -match "permission denied|not authorized") {
                Write-Log "  CAUSA: Usuário não tem permissão para criar bancos" -Level Error
                Write-Log "  SOLUÇÃO: Use um usuário com privilégios CREATEDB ou superuser" -Level Error
            }
            elseif ($stderr -match "already exists") {
                Write-Log "  INFO: Banco já existe (conflito de timing)" -Level Warning
                Write-Log "  Prosseguindo..." -Level Warning
                Write-Log "----------------------------------------" -Level Info
                return $true
            }
            
            Write-Log "----------------------------------------" -Level Info
            return $false
        }
    }
    catch {
        Write-Log "✗ Exceção ao criar banco: $($_.Exception.Message)" -Level Error
        Write-Log "  Stack: $($_.ScriptStackTrace)" -Level Error
        Write-Log "----------------------------------------" -Level Info
        return $false
    }
    finally {
        $env:PGPASSWORD = $null
    }
}

function Start-DatabaseBackup {
    <#
    .SYNOPSIS
        Executa backup de banco de dados SEM OWNER
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,
        
        [Parameter(Mandatory = $true)]
        [string]$Port,
        
        [Parameter(Mandatory = $true)]
        [string]$User,
        
        [Parameter(Mandatory = $true)]
        [string]$Password,
        
        [Parameter(Mandatory = $true)]
        [string]$Database,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )
    
    Write-Log "========================================" -Level Info
    Write-Log "INICIANDO BACKUP (SEM OWNER/ACL)" -Level Info
    Write-Log "========================================" -Level Info
    Write-Log "Host: $HostName`:$Port" -Level Info
    Write-Log "Banco: $Database" -Level Info
    Write-Log "Arquivo: $OutputPath" -Level Info
    Write-Log "Flags: --no-owner --no-acl" -Level Info
    Write-Log "========================================" -Level Info
    
    try {
        # Criar diretório se necessário
        $outputDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $outputDir)) {
            $null = New-Item -ItemType Directory -Path $outputDir -Force
            Write-Log "Diretório criado: $outputDir" -Level Info
        }
        
        $env:PGPASSWORD = $Password
        
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $script:Config.pgDumpPath
        # ✅ CORREÇÃO: Adicionado --no-owner e --no-acl
        $psi.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -F c -b -v --no-owner --no-acl -f `"$OutputPath`" `"$Database`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        
        Write-Log "Executando pg_dump..." -Level Info
        Write-Log "Comando: pg_dump -h $HostName -p $Port -U $User -F c -b -v --no-owner --no-acl -f `"$OutputPath`" `"$Database`"" -Level Info
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        
        $null = $process.Start()
        
        # Ler saída em tempo real
        while (-not $process.StandardError.EndOfStream) {
            $line = $process.StandardError.ReadLine()
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                Write-Log $line -Level Info
            }
        }
        
        $process.WaitForExit()
        
        if ($process.ExitCode -eq 0) {
            Write-Log "========================================" -Level Success
            Write-Log "✓ Backup concluído com sucesso!" -Level Success
            
            if (Test-Path $OutputPath) {
                $fileInfo = Get-Item $OutputPath
                $fileSize = $fileInfo.Length / 1MB
                Write-Log "Arquivo: $($fileInfo.FullName)" -Level Success
                Write-Log "Tamanho: $([math]::Round($fileSize, 2)) MB" -Level Success
                Write-Log "Data: $($fileInfo.LastWriteTime)" -Level Success
                Write-Log "Owner/ACL: Removidos (--no-owner --no-acl)" -Level Success
            }
            
            Write-Log "========================================" -Level Success
            
            [System.Windows.Forms.MessageBox]::Show(
                "Backup concluído com sucesso!`r`n`r`n" +
                "Arquivo: $OutputPath`r`n" +
                "Tamanho: $([math]::Round($fileSize, 2)) MB`r`n`r`n" +
                "✓ Backup criado SEM informações de owner/ACL",
                "Backup Concluído",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            
            return $true
        }
        else {
            Write-Log "========================================" -Level Error
            Write-Log "✗ pg_dump retornou código de erro: $($process.ExitCode)" -Level Error
            Write-Log "========================================" -Level Error
            
            [System.Windows.Forms.MessageBox]::Show(
                "Erro ao realizar backup!`r`n`r`nCódigo de erro: $($process.ExitCode)`r`n`r`nVerifique o log para detalhes.",
                "Erro no Backup",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            
            return $false
        }
    }
    catch {
        Write-Log "✗ Erro no backup: $($_.Exception.Message)" -Level Error
        [System.Windows.Forms.MessageBox]::Show(
            "Erro: $($_.Exception.Message)",
            "Erro",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $false
    }
    finally {
        $env:PGPASSWORD = $null
    }
}
#endregion

#region Restore Functions
function Start-DatabaseRestore {
    <#
    .SYNOPSIS
        Executa restore de banco de dados
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,
        
        [Parameter(Mandatory = $true)]
        [string]$Port,
        
        [Parameter(Mandatory = $true)]
        [string]$User,
        
        [Parameter(Mandatory = $true)]
        [string]$Password,
        
        [Parameter(Mandatory = $true)]
        [string]$BackupFile,
        
        [Parameter(Mandatory = $false)]
        [string]$DatabaseName = ""
    )
    
    Write-Log "========================================" -Level Info
    Write-Log "INICIANDO RESTORE" -Level Info
    Write-Log "========================================" -Level Info
    Write-Log "Arquivo: $BackupFile" -Level Info
    
    # Verificar tipo de backup
    $backupType = Get-BackupType -FilePath $BackupFile
    Write-Log "Tipo de backup: $backupType" -Level Info
    
    # Obter nome do banco
    if ([string]::IsNullOrWhiteSpace($DatabaseName)) {
        if ($backupType -eq "CUSTOM") {
            $detectedName = Get-DatabaseNameFromBackup -BackupFile $BackupFile -Password $Password
            if (-not [string]::IsNullOrWhiteSpace($detectedName)) {
                Write-Log "Nome detectado automaticamente: $detectedName" -Level Info
                $DatabaseName = $detectedName
            }
        }
        
        if ([string]::IsNullOrWhiteSpace($DatabaseName)) {
            # Solicitar nome via InputBox
            $DatabaseName = Show-InputDialog -Title "Nome do Banco de Dados" `
                                            -Prompt "Informe o nome do banco de dados para restauração:" `
                                            -DefaultValue $detectedName
            
            if ([string]::IsNullOrWhiteSpace($DatabaseName)) {
                Write-Log "Operação cancelada ou nome vazio" -Level Warning
                return $false
            }
        }
    }
    
    Write-Log "Banco de destino: $DatabaseName" -Level Info
    Write-Log "Host de destino: $HostName`:$Port" -Level Info
    
    # Criar banco se necessário
    Write-Log "Verificando/criando banco de dados..." -Level Info
    $created = New-PostgreSQLDatabase -HostName $HostName -Port $Port -User $User -Password $Password -DatabaseName $DatabaseName
    
    if (-not $created) {
        Write-Log "========================================" -Level Error
        Write-Log "✗ RESTORE CANCELADO" -Level Error
        Write-Log "✗ Não foi possível criar/acessar o banco de dados '$DatabaseName'" -Level Error
        Write-Log "========================================" -Level Error
        
        [System.Windows.Forms.MessageBox]::Show(
            "Não foi possível criar ou acessar o banco '$DatabaseName'`r`n`r`n" +
            "Possíveis causas:`r`n" +
            "• Usuário não tem permissão para criar bancos (precisa de CREATEDB ou superuser)`r`n" +
            "• Falha na conexão com o servidor`r`n" +
            "• Banco com nome conflitante`r`n`r`n" +
            "Verifique o log para mais detalhes e tente:`r`n" +
            "1. Usar um usuário com mais privilégios (ex: postgres)`r`n" +
            "2. Criar o banco manualmente antes do restore`r`n" +
            "3. Verificar se o PostgreSQL está acessível",
            "Erro ao Criar Banco",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        
        return $false
    }
    
    # Executar restore baseado no tipo
    Write-Log "========================================" -Level Info
    
    if ($backupType -eq "CUSTOM") {
        return Invoke-CustomRestore -HostName $HostName -Port $Port -User $User -Password $Password -DatabaseName $DatabaseName -BackupFile $BackupFile
    }
    else {
        return Invoke-PlainRestore -HostName $HostName -Port $Port -User $User -Password $Password -DatabaseName $DatabaseName -BackupFile $BackupFile
    }
}

function Invoke-CustomRestore {
    <#
    .SYNOPSIS
        Restaura backup no formato CUSTOM (.backup) COM TRATAMENTO COMPLETO DE ERROS
    #>
    [CmdletBinding()]
    param(
        [string]$HostName,
        [string]$Port,
        [string]$User,
        [string]$Password,
        [string]$DatabaseName,
        [string]$BackupFile
    )
    
    Write-Log "Tipo: CUSTOM (.backup)" -Level Info
    Write-Log "Executando pg_restore com --no-owner --no-acl..." -Level Info
    
    try {
        $env:PGPASSWORD = $Password
        
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $script:Config.pgRestorePath
        $psi.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -d `"$DatabaseName`" -v --no-owner --no-acl `"$BackupFile`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.RedirectStandardInput = $true
        $psi.CreateNoWindow = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        
        Write-Log "Comando: pg_restore -h $HostName -p $Port -U $User -d $DatabaseName -v --no-owner --no-acl" -Level Info
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        
        $null = $process.Start()
        $process.StandardInput.Close()
        
        # ✅ CORREÇÃO: Capturar erros críticos vs avisos
        $errorLines = @()
        $warningLines = @()
        $infoLines = @()
        
        while (-not $process.StandardError.EndOfStream) {
            $line = $process.StandardError.ReadLine()
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                # Classificar por tipo
                if ($line -match "FATAL|ERROR.*authentication failed|ERROR.*does not exist|ERROR.*permission denied|ERROR.*syntax error") {
                    # Erros críticos
                    $errorLines += $line
                    Write-Log $line -Level Error
                }
                elseif ($line -match "WARNING|ERROR.*already exists") {
                    # Avisos (não críticos)
                    $warningLines += $line
                    Write-Log $line -Level Warning
                }
                else {
                    # Informação
                    $infoLines += $line
                    Write-Log $line -Level Info
                }
            }
        }
        
        $process.WaitForExit()
        
        # ✅ CORREÇÃO: Análise inteligente do exit code
        Write-Log "========================================" -Level Info
        Write-Log "Código de saída pg_restore: $($process.ExitCode)" -Level Info
        Write-Log "Erros críticos: $($errorLines.Count)" -Level Info
        Write-Log "Avisos: $($warningLines.Count)" -Level Info
        Write-Log "========================================" -Level Info
        
        # Determinar sucesso baseado em exit code E presença de erros críticos
        $isSuccess = $false
        $resultMessage = ""
        
        if ($process.ExitCode -eq 0) {
            # Sucesso total
            $isSuccess = $true
            $resultMessage = "✓ Restore concluído com sucesso!"
            Write-Log $resultMessage -Level Success
        }
        elseif ($process.ExitCode -eq 1 -and $errorLines.Count -eq 0) {
            # Exit code 1 mas sem erros críticos = apenas avisos
            $isSuccess = $true
            $resultMessage = "✓ Restore concluído com avisos (objetos já existentes)"
            Write-Log $resultMessage -Level Success
            Write-Log "  Os avisos são normais quando restaurando em banco existente" -Level Info
        }
        else {
            # Erro real
            $isSuccess = $false
            $resultMessage = "✗ Restore falhou com erros críticos"
            Write-Log $resultMessage -Level Error
        }
        
        # ✅ CORREÇÃO: Relatório detalhado de erros
        if ($errorLines.Count -gt 0) {
            Write-Log "========================================" -Level Error
            Write-Log "ERROS CRÍTICOS ENCONTRADOS:" -Level Error
            Write-Log "========================================" -Level Error
            foreach ($err in $errorLines) {
                Write-Log "  $err" -Level Error
            }
            Write-Log "========================================" -Level Error
            
            # Análise de erros comuns
            $errorAnalysis = @()
            foreach ($err in $errorLines) {
                if ($err -match "authentication failed") {
                    $errorAnalysis += "• Senha incorreta ou usuário sem permissão"
                }
                elseif ($err -match "does not exist") {
                    $errorAnalysis += "• Banco de dados ou objeto não existe"
                }
                elseif ($err -match "permission denied") {
                    $errorAnalysis += "• Usuário não tem permissões necessárias"
                }
                elseif ($err -match "syntax error") {
                    $errorAnalysis += "• Erro de sintaxe SQL (possível incompatibilidade de versão)"
                }
            }
            
            if ($errorAnalysis.Count -gt 0) {
                Write-Log "POSSÍVEIS CAUSAS:" -Level Error
                foreach ($analysis in $errorAnalysis) {
                    Write-Log $analysis -Level Error
                }
            }
        }
        
        # Mostrar resumo de avisos se houver
        if ($warningLines.Count -gt 0 -and $warningLines.Count -le 10) {
            Write-Log "========================================" -Level Warning
            Write-Log "AVISOS (não críticos):" -Level Warning
            foreach ($warn in $warningLines) {
                Write-Log "  $warn" -Level Warning
            }
            Write-Log "========================================" -Level Warning
        }
        elseif ($warningLines.Count -gt 10) {
            Write-Log "========================================" -Level Warning
            Write-Log "Total de avisos: $($warningLines.Count) (muitos objetos já existiam)" -Level Warning
            Write-Log "========================================" -Level Warning
        }
        
        Write-Log "========================================" -Level Info
        
        # Mensagem final ao usuário
        if ($isSuccess) {
            $msgText = "$resultMessage`r`n`r`nBanco: $DatabaseName`r`n"
            if ($warningLines.Count -gt 0) {
                $msgText += "`r`nAvisos: $($warningLines.Count) (normal para bancos existentes)"
            }
            
            [System.Windows.Forms.MessageBox]::Show(
                $msgText,
                "Restore Concluído",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        else {
            $msgText = "$resultMessage`r`n`r`nErros encontrados: $($errorLines.Count)`r`n`r`nVerifique o log para detalhes completos."
            
            [System.Windows.Forms.MessageBox]::Show(
                $msgText,
                "Restore com Erros",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
        
        return $isSuccess
    }
    catch {
        Write-Log "✗ Erro no restore CUSTOM: $($_.Exception.Message)" -Level Error
        [System.Windows.Forms.MessageBox]::Show(
            "Erro: $($_.Exception.Message)",
            "Erro",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $false
    }
    finally {
        $env:PGPASSWORD = $null
    }
}

function Invoke-PlainRestore {
    <#
    .SYNOPSIS
        Restaura backup no formato PLAIN (.sql) COM TRATAMENTO COMPLETO DE ERROS
    #>
    [CmdletBinding()]
    param(
        [string]$HostName,
        [string]$Port,
        [string]$User,
        [string]$Password,
        [string]$DatabaseName,
        [string]$BackupFile
    )
    
    Write-Log "Tipo: PLAIN SQL (.sql)" -Level Info
    Write-Log "Executando psql..." -Level Info
    
    try {
        $env:PGPASSWORD = $Password
        
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $script:Config.psqlPath
        $psi.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -d `"$DatabaseName`" -f `"$BackupFile`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.RedirectStandardInput = $true
        $psi.CreateNoWindow = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        
        Write-Log "Comando: psql -h $HostName -p $Port -U $User -d $DatabaseName -f `"$BackupFile`"" -Level Info
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        
        $null = $process.Start()
        $process.StandardInput.Close()
        
        # ✅ CORREÇÃO: Capturar erros críticos vs avisos (mesmo para PLAIN)
        $errorLines = @()
        $warningLines = @()
        $infoLines = @()
        
        while (-not $process.StandardError.EndOfStream) {
            $line = $process.StandardError.ReadLine()
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                # Classificar por tipo
                if ($line -match "FATAL|ERROR.*authentication failed|ERROR.*does not exist|ERROR.*permission denied|ERROR.*syntax error") {
                    # Erros críticos
                    $errorLines += $line
                    Write-Log $line -Level Error
                }
                elseif ($line -match "WARNING|ERROR.*already exists|NOTICE") {
                    # Avisos (não críticos)
                    $warningLines += $line
                    Write-Log $line -Level Warning
                }
                else {
                    # Informação
                    $infoLines += $line
                    Write-Log $line -Level Info
                }
            }
        }
        
        $process.WaitForExit()
        
        # ✅ CORREÇÃO: Análise inteligente do exit code
        Write-Log "========================================" -Level Info
        Write-Log "Código de saída psql: $($process.ExitCode)" -Level Info
        Write-Log "Erros críticos: $($errorLines.Count)" -Level Info
        Write-Log "Avisos: $($warningLines.Count)" -Level Info
        Write-Log "========================================" -Level Info
        
        # Determinar sucesso
        $isSuccess = $false
        $resultMessage = ""
        
        if ($process.ExitCode -eq 0) {
            $isSuccess = $true
            $resultMessage = "✓ Restore concluído com sucesso!"
            Write-Log $resultMessage -Level Success
        }
        elseif ($process.ExitCode -eq 1 -or $process.ExitCode -eq 2) {
            # Para psql, exit codes 1-2 podem ser avisos
            if ($errorLines.Count -eq 0) {
                $isSuccess = $true
                $resultMessage = "✓ Restore concluído com avisos"
                Write-Log $resultMessage -Level Success
            }
            else {
                $isSuccess = $false
                $resultMessage = "✗ Restore falhou com erros críticos"
                Write-Log $resultMessage -Level Error
            }
        }
        else {
            $isSuccess = $false
            $resultMessage = "✗ Restore falhou (código $($process.ExitCode))"
            Write-Log $resultMessage -Level Error
        }
        
        # ✅ CORREÇÃO: Relatório detalhado de erros (igual ao CUSTOM)
        if ($errorLines.Count -gt 0) {
            Write-Log "========================================" -Level Error
            Write-Log "ERROS CRÍTICOS ENCONTRADOS:" -Level Error
            Write-Log "========================================" -Level Error
            foreach ($err in $errorLines) {
                Write-Log "  $err" -Level Error
            }
            Write-Log "========================================" -Level Error
            
            # Análise de erros comuns
            $errorAnalysis = @()
            foreach ($err in $errorLines) {
                if ($err -match "authentication failed") {
                    $errorAnalysis += "• Senha incorreta ou usuário sem permissão"
                }
                elseif ($err -match "does not exist") {
                    $errorAnalysis += "• Banco de dados ou objeto não existe"
                }
                elseif ($err -match "permission denied") {
                    $errorAnalysis += "• Usuário não tem permissões necessárias"
                }
                elseif ($err -match "syntax error") {
                    $errorAnalysis += "• Erro de sintaxe SQL (possível incompatibilidade de versão)"
                }
            }
            
            if ($errorAnalysis.Count -gt 0) {
                Write-Log "POSSÍVEIS CAUSAS:" -Level Error
                foreach ($analysis in $errorAnalysis) {
                    Write-Log $analysis -Level Error
                }
            }
        }
        
        Write-Log "========================================" -Level Info
        
        # Mensagem final ao usuário
        if ($isSuccess) {
            $msgText = "$resultMessage`r`n`r`nBanco: $DatabaseName`r`n"
            if ($warningLines.Count -gt 0) {
                $msgText += "`r`nAvisos: $($warningLines.Count)"
            }
            
            [System.Windows.Forms.MessageBox]::Show(
                $msgText,
                "Restore Concluído",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        else {
            $msgText = "$resultMessage`r`n`r`nErros encontrados: $($errorLines.Count)`r`n`r`nVerifique o log para detalhes completos."
            
            [System.Windows.Forms.MessageBox]::Show(
                $msgText,
                "Restore com Erros",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
        
        return $isSuccess
    }
    catch {
        Write-Log "✗ Erro no restore SQL: $($_.Exception.Message)" -Level Error
        [System.Windows.Forms.MessageBox]::Show(
            "Erro: $($_.Exception.Message)",
            "Erro",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        return $false
    }
    finally {
        $env:PGPASSWORD = $null
    }
}
#endregion

#region UI Helper Functions
function Show-InputDialog {
    <#
    .SYNOPSIS
        Mostra diálogo de input customizado
    #>
    [CmdletBinding()]
    param(
        [string]$Title = "Input",
        [string]$Prompt = "Digite o valor:",
        [string]$DefaultValue = ""
    )
    
    $inputForm = New-Object System.Windows.Forms.Form
    $inputForm.Text = $Title
    $inputForm.Size = New-Object System.Drawing.Size(400, 150)
    $inputForm.StartPosition = "CenterScreen"
    $inputForm.FormBorderStyle = "FixedDialog"
    $inputForm.MaximizeBox = $false
    $inputForm.MinimizeBox = $false
    $inputForm.TopMost = $true
    
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Prompt
    $label.Location = New-Object System.Drawing.Point(10, 20)
    $label.Size = New-Object System.Drawing.Size(370, 20)
    $inputForm.Controls.Add($label)
    
    $textBox = New-Object System.Windows.Forms.TextBox
    $textBox.Location = New-Object System.Drawing.Point(10, 45)
    $textBox.Size = New-Object System.Drawing.Size(360, 20)
    $textBox.Text = $DefaultValue
    $inputForm.Controls.Add($textBox)
    
    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Text = "OK"
    $okButton.Location = New-Object System.Drawing.Point(215, 75)
    $okButton.Size = New-Object System.Drawing.Size(75, 25)
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $inputForm.Controls.Add($okButton)
    $inputForm.AcceptButton = $okButton
    
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancelar"
    $cancelButton.Location = New-Object System.Drawing.Point(295, 75)
    $cancelButton.Size = New-Object System.Drawing.Size(75, 25)
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $inputForm.Controls.Add($cancelButton)
    $inputForm.CancelButton = $cancelButton
    
    $result = $inputForm.ShowDialog()
    
    $returnValue = if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $textBox.Text.Trim()
    } else {
        ""
    }
    
    $inputForm.Dispose()
    
    return $returnValue
}

function Enable-Controls {
    <#
    .SYNOPSIS
        Habilita/desabilita controles durante operações
    #>
    [CmdletBinding()]
    param(
        [bool]$Enabled = $true
    )
    
    # Backup Tab
    if ($script:UI.btnConnectBkp) { $script:UI.btnConnectBkp.Enabled = $Enabled }
    if ($script:UI.btnBackup) { $script:UI.btnBackup.Enabled = $Enabled }
    
    # Restore Tab
    if ($script:UI.btnTestConnection) { $script:UI.btnTestConnection.Enabled = $Enabled }
    if ($script:UI.btnRestore) { $script:UI.btnRestore.Enabled = $Enabled }
    
    if ($script:UI.Form) {
        $script:UI.Form.Cursor = if ($Enabled) { 
            [System.Windows.Forms.Cursors]::Default 
        } else { 
            [System.Windows.Forms.Cursors]::WaitCursor 
        }
    }
    
    [System.Windows.Forms.Application]::DoEvents()
}
#endregion

#region UI Creation
function Initialize-MainForm {
    <#
    .SYNOPSIS
        Cria e configura o formulário principal
    #>
    [CmdletBinding()]
    param()
    
    # Criar formulário principal
    $script:UI.Form = New-Object System.Windows.Forms.Form
    $script:UI.Form.Text = "$($script:Config.FormTitle) v$($script:Config.Version)"
    $script:UI.Form.Size = New-Object System.Drawing.Size(700, 600)
    $script:UI.Form.StartPosition = "CenterScreen"
    $script:UI.Form.FormBorderStyle = "FixedDialog"
    $script:UI.Form.MaximizeBox = $false
    $script:UI.Form.Icon = [System.Drawing.SystemIcons]::Application
    
    # Panel superior com informações
    $panelInfo = New-Object System.Windows.Forms.Panel
    $panelInfo.Location = New-Object System.Drawing.Point(10, 10)
    $panelInfo.Size = New-Object System.Drawing.Size(665, 75)
    $panelInfo.BorderStyle = "FixedSingle"
    $script:UI.Form.Controls.Add($panelInfo)
    
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "PostgreSQL Backup & Restore"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(10, 10)
    $lblTitle.Size = New-Object System.Drawing.Size(645, 30)
    $panelInfo.Controls.Add($lblTitle)
    
    $lblVersion = New-Object System.Windows.Forms.Label
    $lblVersion.Name = "lblVersion"
    $lblVersion.Text = "Versão $($script:Config.Version) | PostgreSQL: Verificando..."
    $lblVersion.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblVersion.ForeColor = [System.Drawing.Color]::Gray
    $lblVersion.Location = New-Object System.Drawing.Point(10, 40)
    $lblVersion.Size = New-Object System.Drawing.Size(645, 20)
    $panelInfo.Controls.Add($lblVersion)
    
    # Guardar referência do label
    $script:UI.lblVersion = $lblVersion
    
    # TabControl
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Location = New-Object System.Drawing.Point(10, 95)
    $tabControl.Size = New-Object System.Drawing.Size(665, 260)
    $script:UI.Form.Controls.Add($tabControl)
    
    # Criar abas
    Initialize-BackupTab -TabControl $tabControl
    Initialize-RestoreTab -TabControl $tabControl
    
    # RichTextBox Log
    $lblLog = New-Object System.Windows.Forms.Label
    $lblLog.Text = "Log de Operações:"
    $lblLog.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblLog.Location = New-Object System.Drawing.Point(10, 360)
    $lblLog.Size = New-Object System.Drawing.Size(200, 20)
    $script:UI.Form.Controls.Add($lblLog)
    
    $btnClearLog = New-Object System.Windows.Forms.Button
    $btnClearLog.Text = "Limpar Log"
    $btnClearLog.Location = New-Object System.Drawing.Point(585, 357)
    $btnClearLog.Size = New-Object System.Drawing.Size(90, 23)
    $btnClearLog.Add_Click({ Clear-Log })
    $script:UI.Form.Controls.Add($btnClearLog)
    
    $script:UI.rtbLog = New-Object System.Windows.Forms.RichTextBox
    $script:UI.rtbLog.Location = New-Object System.Drawing.Point(10, 385)
    $script:UI.rtbLog.Size = New-Object System.Drawing.Size(665, 165)
    $script:UI.rtbLog.ReadOnly = $true
    $script:UI.rtbLog.Font = New-Object System.Drawing.Font("Consolas", 9)
    $script:UI.rtbLog.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
    $script:UI.rtbLog.ForeColor = [System.Drawing.Color]::LightGray
    $script:UI.rtbLog.BorderStyle = "FixedSingle"
    $script:UI.Form.Controls.Add($script:UI.rtbLog)
    
    # Event handlers
    $script:UI.Form.Add_Load({
        Write-Log "========================================" -Level Info
        Write-Log "PostgreSQL Backup & Restore Pro v$($script:Config.Version)" -Level Info
        Write-Log "✅ MELHORIAS: Backup sem owner/ACL + Restore com análise de erros" -Level Info
        Write-Log "========================================" -Level Info
        Write-Log "Iniciando aplicação..." -Level Info
        
        if (Find-PostgreSQLBinaries) {
            Write-Log "Aplicação pronta para uso!" -Level Success
            # Atualizar label de versão
            if ($script:UI.lblVersion) {
                $script:UI.lblVersion.Text = "Versão $($script:Config.Version) | PostgreSQL: ✓ Encontrado"
                $script:UI.lblVersion.ForeColor = [System.Drawing.Color]::Green
            }
        }
        else {
            Write-Log "ATENÇÃO: Configure o PostgreSQL para continuar" -Level Warning
            # Atualizar label de versão
            if ($script:UI.lblVersion) {
                $script:UI.lblVersion.Text = "Versão $($script:Config.Version) | PostgreSQL: ✗ Não encontrado"
                $script:UI.lblVersion.ForeColor = [System.Drawing.Color]::Red
            }
        }
        
        Write-Log "========================================" -Level Info
    })
    
    $script:UI.Form.Add_FormClosing({
        param($sender, $e)
        
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Deseja realmente sair?",
            "Confirmar Saída",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )
        
        if ($result -eq [System.Windows.Forms.DialogResult]::No) {
            $e.Cancel = $true
        }
    })
}

function Initialize-BackupTab {
    <#
    .SYNOPSIS
        Cria aba de Backup
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.TabControl]$TabControl
    )
    
    $tabBackup = New-Object System.Windows.Forms.TabPage
    $tabBackup.Text = "Backup"
    $tabBackup.UseVisualStyleBackColor = $true
    $TabControl.Controls.Add($tabBackup)
    
    # GroupBox Conexão
    $grpConnection = New-Object System.Windows.Forms.GroupBox
    $grpConnection.Text = "Conexão com Servidor"
    $grpConnection.Location = New-Object System.Drawing.Point(10, 10)
    $grpConnection.Size = New-Object System.Drawing.Size(635, 90)
    $tabBackup.Controls.Add($grpConnection)
    
    # Host
    $lblHostBkp = New-Object System.Windows.Forms.Label
    $lblHostBkp.Text = "Host:"
    $lblHostBkp.Font = New-Object System.Drawing.Font("Tahoma", 9, [System.Drawing.FontStyle]::Bold)
    $lblHostBkp.Location = New-Object System.Drawing.Point(15, 25)
    $lblHostBkp.Size = New-Object System.Drawing.Size(50, 20)
    $lblHostBkp.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $grpConnection.Controls.Add($lblHostBkp)
    
    $script:UI.cboHostBkp = New-Object System.Windows.Forms.ComboBox
    $script:UI.cboHostBkp.Location = New-Object System.Drawing.Point(75, 23)
    $script:UI.cboHostBkp.Size = New-Object System.Drawing.Size(230, 21)
    $script:UI.cboHostBkp.DropDownStyle = "DropDown"
    $script:UI.cboHostBkp.Items.AddRange(@($script:PredefinedHosts.Keys))
    $script:UI.cboHostBkp.Add_SelectedIndexChanged({
        $selectedHost = $script:UI.cboHostBkp.SelectedItem
        if ($script:PredefinedHosts.ContainsKey($selectedHost)) {
            $config = $script:PredefinedHosts[$selectedHost]
            $script:UI.txtPortBkp.Text = $config.Port
            $script:UI.txtUserBkp.Text = $config.User
            $script:UI.txtPassBkp.Text = $config.Pass
            Write-Log "Host pré-configurado selecionado: $selectedHost" -Level Info
        }
    })
    $grpConnection.Controls.Add($script:UI.cboHostBkp)
    
    # Port
    $lblPortBkp = New-Object System.Windows.Forms.Label
    $lblPortBkp.Text = "Porta:"
    $lblPortBkp.Font = New-Object System.Drawing.Font("Tahoma", 9, [System.Drawing.FontStyle]::Bold)
    $lblPortBkp.Location = New-Object System.Drawing.Point(315, 25)
    $lblPortBkp.Size = New-Object System.Drawing.Size(50, 20)
    $lblPortBkp.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $grpConnection.Controls.Add($lblPortBkp)
    
    $script:UI.txtPortBkp = New-Object System.Windows.Forms.TextBox
    $script:UI.txtPortBkp.Location = New-Object System.Drawing.Point(375, 23)
    $script:UI.txtPortBkp.Size = New-Object System.Drawing.Size(50, 20)
    $script:UI.txtPortBkp.Text = "5432"
    $script:UI.txtPortBkp.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
    $grpConnection.Controls.Add($script:UI.txtPortBkp)
    
    # User
    $lblUserBkp = New-Object System.Windows.Forms.Label
    $lblUserBkp.Text = "Usuário:"
    $lblUserBkp.Font = New-Object System.Drawing.Font("Tahoma", 9, [System.Drawing.FontStyle]::Bold)
    $lblUserBkp.Location = New-Object System.Drawing.Point(15, 53)
    $lblUserBkp.Size = New-Object System.Drawing.Size(60, 20)
    $lblUserBkp.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $grpConnection.Controls.Add($lblUserBkp)
    
    $script:UI.txtUserBkp = New-Object System.Windows.Forms.TextBox
    $script:UI.txtUserBkp.Location = New-Object System.Drawing.Point(75, 53)
    $script:UI.txtUserBkp.Size = New-Object System.Drawing.Size(230, 20)
    $grpConnection.Controls.Add($script:UI.txtUserBkp)
    
    # Password
    $lblPassBkp = New-Object System.Windows.Forms.Label
    $lblPassBkp.Text = "Senha:"
    $lblPassBkp.Font = New-Object System.Drawing.Font("Tahoma", 9, [System.Drawing.FontStyle]::Bold)
    $lblPassBkp.Location = New-Object System.Drawing.Point(315, 53)
    $lblPassBkp.Size = New-Object System.Drawing.Size(60, 20)
    $lblPassBkp.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $grpConnection.Controls.Add($lblPassBkp)
    
    $script:UI.txtPassBkp = New-Object System.Windows.Forms.TextBox
    $script:UI.txtPassBkp.Location = New-Object System.Drawing.Point(375, 53)
    $script:UI.txtPassBkp.Size = New-Object System.Drawing.Size(135, 20)
    $script:UI.txtPassBkp.UseSystemPasswordChar = $true
    $grpConnection.Controls.Add($script:UI.txtPassBkp)
    
    # Botão Conectar
    $script:UI.btnConnectBkp = New-Object System.Windows.Forms.Button
    $script:UI.btnConnectBkp.Text = "Conectar"
    $script:UI.btnConnectBkp.Location = New-Object System.Drawing.Point(520, 23)
    $script:UI.btnConnectBkp.Size = New-Object System.Drawing.Size(100, 50)
    $script:UI.btnConnectBkp.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $script:UI.btnConnectBkp.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $script:UI.btnConnectBkp.ForeColor = [System.Drawing.Color]::White
    $script:UI.btnConnectBkp.FlatStyle = "Flat"
    $script:UI.btnConnectBkp.Add_Click({
        $hostname = $script:UI.cboHostBkp.Text
        $port = $script:UI.txtPortBkp.Text
        $user = $script:UI.txtUserBkp.Text
        $pass = $script:UI.txtPassBkp.Text
        
        if (-not (Test-ConnectionParameters -HostName $hostname -Port $port -User $user -Password $pass)) {
            return
        }
        
        Enable-Controls -Enabled $false
        
        try {
            Write-Log "Conectando ao servidor..." -Level Info
            
            if (Test-PostgreSQLConnection -HostName $hostname -Port $port -User $user -Password $pass) {
                Write-Log "Listando bancos de dados..." -Level Info
                $databases = Get-DatabaseList -HostName $hostname -Port $port -User $user -Password $pass
                
                $script:UI.cboDBBkp.Items.Clear()
                if ($databases.Count -gt 0) {
                    $script:UI.cboDBBkp.Items.AddRange($databases)
                    $script:UI.cboDBBkp.SelectedIndex = 0
                }
            }
        }
        finally {
            Enable-Controls -Enabled $true
        }
    })
    $grpConnection.Controls.Add($script:UI.btnConnectBkp)
    
    # GroupBox Banco de Dados
    $grpDatabase = New-Object System.Windows.Forms.GroupBox
    $grpDatabase.Text = "Selecionar Banco de Dados"
    $grpDatabase.Location = New-Object System.Drawing.Point(10, 110)
    $grpDatabase.Size = New-Object System.Drawing.Size(635, 60)
    $tabBackup.Controls.Add($grpDatabase)
    
    $lblDBBkp = New-Object System.Windows.Forms.Label
    $lblDBBkp.Text = "Banco:"
    $lblDBBkp.Font = New-Object System.Drawing.Font("Tahoma", 9, [System.Drawing.FontStyle]::Bold)
    $lblDBBkp.Location = New-Object System.Drawing.Point(15, 28)
    $lblDBBkp.Size = New-Object System.Drawing.Size(60, 20)
    $lblDBBkp.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $grpDatabase.Controls.Add($lblDBBkp)
    
    $script:UI.cboDBBkp = New-Object System.Windows.Forms.ComboBox
    $script:UI.cboDBBkp.Location = New-Object System.Drawing.Point(75, 26)
    $script:UI.cboDBBkp.Size = New-Object System.Drawing.Size(330, 21)
    $script:UI.cboDBBkp.DropDownStyle = "DropDownList"
    $grpDatabase.Controls.Add($script:UI.cboDBBkp)
    
    # Botão Backup
    $script:UI.btnBackup = New-Object System.Windows.Forms.Button
    $script:UI.btnBackup.Text = "🗄 Realizar Backup"
    $script:UI.btnBackup.Location = New-Object System.Drawing.Point(415, 23)
    $script:UI.btnBackup.Size = New-Object System.Drawing.Size(205, 30)
    $script:UI.btnBackup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $script:UI.btnBackup.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 0)
    $script:UI.btnBackup.ForeColor = [System.Drawing.Color]::White
    $script:UI.btnBackup.FlatStyle = "Flat"
    $script:UI.btnBackup.Add_Click({
        if ($script:UI.cboDBBkp.SelectedIndex -eq -1) {
            [System.Windows.Forms.MessageBox]::Show(
                "Selecione um banco de dados!",
                "Validação",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        # Diálogo para salvar arquivo
        $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
        $saveDialog.Title = "Salvar backup como"
        $saveDialog.Filter = "Backup PostgreSQL (*.backup)|*.backup|Arquivo SQL (*.sql)|*.sql|Todos os arquivos (*.*)|*.*"
        $saveDialog.FilterIndex = 1
        $saveDialog.FileName = "$($script:UI.cboDBBkp.SelectedItem)_$(Get-Date -Format 'yyyyMMdd_HHmmss').backup"
        $saveDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
        
        if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            Enable-Controls -Enabled $false
            
            try {
                Start-DatabaseBackup -HostName $script:UI.cboHostBkp.Text `
                                    -Port $script:UI.txtPortBkp.Text `
                                    -User $script:UI.txtUserBkp.Text `
                                    -Password $script:UI.txtPassBkp.Text `
                                    -Database $script:UI.cboDBBkp.SelectedItem `
                                    -OutputPath $saveDialog.FileName
            }
            finally {
                Enable-Controls -Enabled $true
            }
        }
    })
    $grpDatabase.Controls.Add($script:UI.btnBackup)
}

function Initialize-RestoreTab {
    <#
    .SYNOPSIS
        Cria aba de Restore
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Windows.Forms.TabControl]$TabControl
    )
    
    $tabRestore = New-Object System.Windows.Forms.TabPage
    $tabRestore.Text = "Restaurar"
    $tabRestore.UseVisualStyleBackColor = $true
    $TabControl.Controls.Add($tabRestore)
    
    # GroupBox Conexão
    $grpConnection = New-Object System.Windows.Forms.GroupBox
    $grpConnection.Text = "Conexão com Servidor de Destino"
    $grpConnection.Location = New-Object System.Drawing.Point(10, 10)
    $grpConnection.Size = New-Object System.Drawing.Size(635, 90)
    $tabRestore.Controls.Add($grpConnection)
    
    # Host
    $lblHostRestore = New-Object System.Windows.Forms.Label
    $lblHostRestore.Text = "Host:"
    $lblHostRestore.Font = New-Object System.Drawing.Font("Tahoma", 9, [System.Drawing.FontStyle]::Bold)
    $lblHostRestore.Location = New-Object System.Drawing.Point(15, 25)
    $lblHostRestore.Size = New-Object System.Drawing.Size(50, 20)
    $lblHostRestore.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $grpConnection.Controls.Add($lblHostRestore)
    
    $script:UI.txtHostRestore = New-Object System.Windows.Forms.TextBox
    $script:UI.txtHostRestore.Location = New-Object System.Drawing.Point(75, 23)
    $script:UI.txtHostRestore.Size = New-Object System.Drawing.Size(230, 20)
    $grpConnection.Controls.Add($script:UI.txtHostRestore)
    
    # Port
    $lblPortRestore = New-Object System.Windows.Forms.Label
    $lblPortRestore.Text = "Porta:"
    $lblPortRestore.Font = New-Object System.Drawing.Font("Tahoma", 9, [System.Drawing.FontStyle]::Bold)
    $lblPortRestore.Location = New-Object System.Drawing.Point(315, 25)
    $lblPortRestore.Size = New-Object System.Drawing.Size(50, 20)
    $lblPortRestore.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $grpConnection.Controls.Add($lblPortRestore)
    
    $script:UI.txtPortRestore = New-Object System.Windows.Forms.TextBox
    $script:UI.txtPortRestore.Location = New-Object System.Drawing.Point(375, 23)
    $script:UI.txtPortRestore.Size = New-Object System.Drawing.Size(50, 20)
    $script:UI.txtPortRestore.Text = "5432"
    $script:UI.txtPortRestore.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
    $grpConnection.Controls.Add($script:UI.txtPortRestore)
    
    # User
    $lblUserRestore = New-Object System.Windows.Forms.Label
    $lblUserRestore.Text = "Usuário:"
    $lblUserRestore.Font = New-Object System.Drawing.Font("Tahoma", 9, [System.Drawing.FontStyle]::Bold)
    $lblUserRestore.Location = New-Object System.Drawing.Point(15, 53)
    $lblUserRestore.Size = New-Object System.Drawing.Size(60, 20)
    $lblUserRestore.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $grpConnection.Controls.Add($lblUserRestore)
    
    $script:UI.txtUserRestore = New-Object System.Windows.Forms.TextBox
    $script:UI.txtUserRestore.Location = New-Object System.Drawing.Point(75, 53)
    $script:UI.txtUserRestore.Size = New-Object System.Drawing.Size(230, 20)
    $grpConnection.Controls.Add($script:UI.txtUserRestore)
    
    # Password
    $lblPassRestore = New-Object System.Windows.Forms.Label
    $lblPassRestore.Text = "Senha:"
    $lblPassRestore.Font = New-Object System.Drawing.Font("Tahoma", 9, [System.Drawing.FontStyle]::Bold)
    $lblPassRestore.Location = New-Object System.Drawing.Point(315, 53)
    $lblPassRestore.Size = New-Object System.Drawing.Size(60, 20)
    $lblPassRestore.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $grpConnection.Controls.Add($lblPassRestore)
    
    $script:UI.txtPassRestore = New-Object System.Windows.Forms.TextBox
    $script:UI.txtPassRestore.Location = New-Object System.Drawing.Point(375, 53)
    $script:UI.txtPassRestore.Size = New-Object System.Drawing.Size(135, 20)
    $script:UI.txtPassRestore.UseSystemPasswordChar = $true
    $grpConnection.Controls.Add($script:UI.txtPassRestore)
    
    # Botão Test Connection
    $script:UI.btnTestConnection = New-Object System.Windows.Forms.Button
    $script:UI.btnTestConnection.Text = "Testar Conexão"
    $script:UI.btnTestConnection.Location = New-Object System.Drawing.Point(520, 23)
    $script:UI.btnTestConnection.Size = New-Object System.Drawing.Size(100, 50)
    $script:UI.btnTestConnection.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $script:UI.btnTestConnection.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $script:UI.btnTestConnection.ForeColor = [System.Drawing.Color]::White
    $script:UI.btnTestConnection.FlatStyle = "Flat"
    $script:UI.btnTestConnection.Add_Click({
        $hostname = $script:UI.txtHostRestore.Text
        $port = $script:UI.txtPortRestore.Text
        $user = $script:UI.txtUserRestore.Text
        $pass = $script:UI.txtPassRestore.Text
        
        if (-not (Test-ConnectionParameters -HostName $hostname -Port $port -User $user -Password $pass)) {
            return
        }
        
        Enable-Controls -Enabled $false
        
        try {
            Test-PostgreSQLConnection -HostName $hostname -Port $port -User $user -Password $pass
        }
        finally {
            Enable-Controls -Enabled $true
        }
    })
    $grpConnection.Controls.Add($script:UI.btnTestConnection)
    
    # GroupBox Arquivo
    $grpFile = New-Object System.Windows.Forms.GroupBox
    $grpFile.Text = "Arquivo de Backup"
    $grpFile.Location = New-Object System.Drawing.Point(10, 110)
    $grpFile.Size = New-Object System.Drawing.Size(635, 60)
    $tabRestore.Controls.Add($grpFile)
    
    $lblFileRestore = New-Object System.Windows.Forms.Label
    $lblFileRestore.Text = "Arquivo:"
    $lblFileRestore.Font = New-Object System.Drawing.Font("Tahoma", 9, [System.Drawing.FontStyle]::Bold)
    $lblFileRestore.Location = New-Object System.Drawing.Point(15, 28)
    $lblFileRestore.Size = New-Object System.Drawing.Size(60, 20)
    $lblFileRestore.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $grpFile.Controls.Add($lblFileRestore)
    
    $script:UI.txtFileRestore = New-Object System.Windows.Forms.TextBox
    $script:UI.txtFileRestore.Location = New-Object System.Drawing.Point(75, 26)
    $script:UI.txtFileRestore.Size = New-Object System.Drawing.Size(435, 20)
    $script:UI.txtFileRestore.ReadOnly = $true
    $script:UI.txtFileRestore.BackColor = [System.Drawing.Color]::White
    $grpFile.Controls.Add($script:UI.txtFileRestore)
    
    # Botão Browse
    $btnBrowseFile = New-Object System.Windows.Forms.Button
    $btnBrowseFile.Text = "..."
    $btnBrowseFile.Location = New-Object System.Drawing.Point(515, 24)
    $btnBrowseFile.Size = New-Object System.Drawing.Size(35, 23)
    $btnBrowseFile.Add_Click({
        $openDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openDialog.Title = "Selecione o arquivo de backup"
        $openDialog.Filter = "Arquivos de Backup (*.backup;*.sql;*.dump)|*.backup;*.sql;*.dump|Todos os arquivos (*.*)|*.*"
        $openDialog.FilterIndex = 1
        $openDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
        
        if ($openDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $script:UI.txtFileRestore.Text = $openDialog.FileName
            Write-Log "Arquivo selecionado: $(Split-Path $openDialog.FileName -Leaf)" -Level Info
            
            # Detectar tipo
            $type = Get-BackupType -FilePath $openDialog.FileName
            Write-Log "Tipo detectado: $type" -Level Info
        }
    })
    $grpFile.Controls.Add($btnBrowseFile)
    
    # Botão Restore
    $script:UI.btnRestore = New-Object System.Windows.Forms.Button
    $script:UI.btnRestore.Text = "🔄 Restaurar Backup"
    $script:UI.btnRestore.Location = New-Object System.Drawing.Point(10, 180)
    $script:UI.btnRestore.Size = New-Object System.Drawing.Size(635, 40)
    $script:UI.btnRestore.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $script:UI.btnRestore.BackColor = [System.Drawing.Color]::FromArgb(200, 100, 0)
    $script:UI.btnRestore.ForeColor = [System.Drawing.Color]::White
    $script:UI.btnRestore.FlatStyle = "Flat"
    $script:UI.btnRestore.Add_Click({
        if ([string]::IsNullOrWhiteSpace($script:UI.txtFileRestore.Text)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Selecione um arquivo de backup!",
                "Validação",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        if (-not (Test-Path $script:UI.txtFileRestore.Text)) {
            [System.Windows.Forms.MessageBox]::Show(
                "Arquivo não encontrado!`r`n`r`n$($script:UI.txtFileRestore.Text)",
                "Erro",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return
        }
        
        $hostname = $script:UI.txtHostRestore.Text
        $port = $script:UI.txtPortRestore.Text
        $user = $script:UI.txtUserRestore.Text
        $pass = $script:UI.txtPassRestore.Text
        
        if (-not (Test-ConnectionParameters -HostName $hostname -Port $port -User $user -Password $pass)) {
            return
        }
        
        # Confirmar operação
        $result = [System.Windows.Forms.MessageBox]::Show(
            "ATENÇÃO: Esta operação irá restaurar o backup no servidor.`r`n`r`n" +
            "Servidor: $hostname`:$port`r`n" +
            "Arquivo: $(Split-Path $script:UI.txtFileRestore.Text -Leaf)`r`n`r`n" +
            "Deseja continuar?",
            "Confirmar Restore",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            Enable-Controls -Enabled $false
            
            try {
                Start-DatabaseRestore -HostName $hostname `
                                     -Port $port `
                                     -User $user `
                                     -Password $pass `
                                     -BackupFile $script:UI.txtFileRestore.Text
            }
            finally {
                Enable-Controls -Enabled $true
            }
        }
    })
    $tabRestore.Controls.Add($script:UI.btnRestore)
}
#endregion

#region Main Execution
try {
    Write-Verbose "Inicializando aplicação..."
    Initialize-MainForm
    
    Write-Verbose "Exibindo formulário..."
    [void]$script:UI.Form.ShowDialog()
    
    Write-Verbose "Aplicação encerrada"
}
catch {
    $errorMsg = "Erro fatal na aplicação: $($_.Exception.Message)`r`n`r`n$($_.ScriptStackTrace)"
    
    [System.Windows.Forms.MessageBox]::Show(
        $errorMsg,
        "Erro Fatal",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    
    Write-Error $errorMsg
    exit 1
}
finally {
    # Cleanup
    if ($script:UI.Form) {
        $script:UI.Form.Dispose()
    }
}
#endregion
