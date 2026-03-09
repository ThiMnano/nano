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
    Version = "3.1"  # Bugfix: already exists tratado corretamente
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

# UI Controls
$script:UI = @{
    Form = $null
    rtbLog = $null
    cboHostBkp = $null
    txtPortBkp = $null
    txtUserBkp = $null
    txtPassBkp = $null
    cboDBBkp = $null
    btnConnectBkp = $null
    btnBackup = $null
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
    [CmdletBinding()]
    param()
    
    if ($null -ne $script:UI.rtbLog) {
        $script:UI.rtbLog.Clear()
    }
}
#endregion

#region PostgreSQL Binary Detection
function Find-PostgreSQLBinaries {
    [CmdletBinding()]
    param()
    
    Write-Log "Procurando binários do PostgreSQL..." -Level Info
    
    $searchPaths = @()
    
    # Registro do Windows
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
                    }
                }
                catch { }
            }
        }
    }
    catch { }
    
    # Program Files
    $programFiles = ${env:ProgramFiles}
    $pgFolder = Join-Path $programFiles "PostgreSQL"
    if (Test-Path $pgFolder) {
        Get-ChildItem -Path $pgFolder -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $binPath = Join-Path $_.FullName "bin"
            if (Test-Path $binPath) {
                $searchPaths += $binPath
            }
        }
    }
    
    # Program Files (x86)
    if (${env:ProgramFiles(x86)}) {
        $pgFolderX86 = Join-Path ${env:ProgramFiles(x86)} "PostgreSQL"
        if (Test-Path $pgFolderX86) {
            Get-ChildItem -Path $pgFolderX86 -Directory -ErrorAction SilentlyContinue | ForEach-Object {
                $binPath = Join-Path $_.FullName "bin"
                if (Test-Path $binPath) {
                    $searchPaths += $binPath
                }
            }
        }
    }
    
    # pgAdmin
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
        }
    }
    
    # PATH
    $pathEnv = $env:PATH -split ';'
    foreach ($path in $pathEnv) {
        if ($path -match 'postgres' -and (Test-Path $path)) {
            $searchPaths += $path
        }
    }
    
    $searchPaths = $searchPaths | Select-Object -Unique
    
    # Verificar binários
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
    
    Write-Log "✗ ERRO: Binários PostgreSQL não encontrados!" -Level Error
    
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

#region Database Management Functions
function Test-DatabaseExists {
    <#
    .SYNOPSIS
        Verifica se banco de dados existe
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
    
    try {
        $env:PGPASSWORD = $Password
        
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
        $process.WaitForExit(5000) | Out-Null
        
        return ($output -eq "1")
    }
    catch {
        Write-Log "✗ Erro ao verificar banco: $($_.Exception.Message)" -Level Error
        return $false
    }
    finally {
        $env:PGPASSWORD = $null
    }
}

function Remove-DatabaseIfExists {
    <#
    .SYNOPSIS
        Remove banco de dados se existir
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
    
    Write-Log "Removendo banco existente '$DatabaseName'..." -Level Warning
    
    try {
        $env:PGPASSWORD = $Password
        
        # Terminar conexões ativas
        $killConnSql = @"
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = '$DatabaseName'
  AND pid <> pg_backend_pid();
"@
        
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $script:Config.psqlPath
        $psi.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -d postgres -c `"$killConnSql`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        $null = $process.Start()
        $process.WaitForExit(5000) | Out-Null
        
        Write-Log "  Conexões ativas terminadas" -Level Info
        
        # Aguardar
        Start-Sleep -Milliseconds 500
        
        # Drop database
        $dropSql = "DROP DATABASE IF EXISTS `"$DatabaseName`""
        
        $psi.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -d postgres -c `"$dropSql`""
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        
        $null = $process.Start()
        $stderr = $process.StandardError.ReadToEnd()
        
        if (-not $process.WaitForExit(10000)) {
            $process.Kill()
            Write-Log "✗ Timeout ao remover banco" -Level Error
            return $false
        }
        
        if ($process.ExitCode -eq 0) {
            Write-Log "✓ Banco removido com sucesso" -Level Success
            Start-Sleep -Seconds 2  # CRÍTICO: Aguardar liberação completa
            return $true
        }
        else {
            Write-Log "✗ Erro ao remover banco: $stderr" -Level Error
            return $false
        }
    }
    catch {
        Write-Log "✗ Exceção ao remover banco: $($_.Exception.Message)" -Level Error
        return $false
    }
    finally {
        $env:PGPASSWORD = $null
    }
}

function New-PostgreSQLDatabase {
    <#
    .SYNOPSIS
        Cria banco de dados e GARANTE que está pronto para conexões
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
    
    Write-Log "Criando banco '$DatabaseName' com UTF8..." -Level Info
    
    try {
        $env:PGPASSWORD = $Password
        
        # Criar com encoding UTF8 e template0
        $createSql = "CREATE DATABASE `"$DatabaseName`" WITH ENCODING 'UTF8' TEMPLATE template0"
        
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $script:Config.psqlPath
        $psi.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -d postgres -c `"$createSql`""
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
        
        if (-not $process.WaitForExit(15000)) {
            $process.Kill()
            Write-Log "✗ Timeout ao criar banco (15s)" -Level Error
            return $false
        }
        
        if ($process.ExitCode -eq 0) {
            Write-Log "✓ Banco criado!" -Level Success
            
            # CRÍTICO: Aguardar banco estar pronto
            Write-Log "  Aguardando banco ficar pronto para conexões..." -Level Info
            Start-Sleep -Seconds 3
            
            # Testar conexão 3 vezes para garantir
            $maxAttempts = 3
            $connected = $false
            
            for ($i = 1; $i -le $maxAttempts; $i++) {
                Write-Log "  Tentativa $i/$maxAttempts - Testando conexão com '$DatabaseName'..." -Level Info
                
                $testPsi = New-Object System.Diagnostics.ProcessStartInfo
                $testPsi.FileName = $script:Config.psqlPath
                $testPsi.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -d `"$DatabaseName`" -c `"SELECT 1;`" -t"
                $testPsi.UseShellExecute = $false
                $testPsi.RedirectStandardOutput = $true
                $testPsi.RedirectStandardError = $true
                $testPsi.CreateNoWindow = $true
                $testPsi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
                
                $testProcess = New-Object System.Diagnostics.Process
                $testProcess.StartInfo = $testPsi
                
                $null = $testProcess.Start()
                $testStdout = $testProcess.StandardOutput.ReadToEnd()
                $testStderr = $testProcess.StandardError.ReadToEnd()
                $testProcess.WaitForExit(5000) | Out-Null
                
                if ($testProcess.ExitCode -eq 0) {
                    Write-Log "✓ Conexão com '$DatabaseName' OK!" -Level Success
                    $connected = $true
                    break
                }
                else {
                    Write-Log "  Tentativa $i falhou: $testStderr" -Level Warning
                    if ($i -lt $maxAttempts) {
                        Start-Sleep -Seconds 2
                    }
                }
            }
            
            if ($connected) {
                Write-Log "✓ Banco '$DatabaseName' PRONTO PARA RESTORE!" -Level Success
                return $true
            }
            else {
                Write-Log "✗ Banco criado mas não aceita conexões após $maxAttempts tentativas" -Level Error
                return $false
            }
        }
        else {
            # Exit code != 0
            Write-Log "✗ Erro ao criar banco (Exit: $($process.ExitCode))" -Level Error
            
            if ($stderr) {
                Write-Log "  Erro: $stderr" -Level Error
            }
            
            # CORREÇÃO CRÍTICA: Verificar se erro é "already exists"
            if ($stderr -match "already exists|j├í existe|já existe") {
                Write-Log "✓ Banco '$DatabaseName' já existe - prosseguindo" -Level Success
                
                # Testar conexão mesmo assim
                Start-Sleep -Seconds 1
                
                $testPsi = New-Object System.Diagnostics.ProcessStartInfo
                $testPsi.FileName = $script:Config.psqlPath
                $testPsi.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -d `"$DatabaseName`" -c `"SELECT 1;`" -t"
                $testPsi.UseShellExecute = $false
                $testPsi.RedirectStandardOutput = $true
                $testPsi.RedirectStandardError = $true
                $testPsi.CreateNoWindow = $true
                $testPsi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
                
                $testProcess = New-Object System.Diagnostics.Process
                $testProcess.StartInfo = $testPsi
                
                $null = $testProcess.Start()
                $testProcess.WaitForExit(5000) | Out-Null
                
                if ($testProcess.ExitCode -eq 0) {
                    Write-Log "✓ Banco existente está acessível!" -Level Success
                    return $true
                }
                else {
                    Write-Log "✗ Banco existe mas não está acessível" -Level Error
                    return $false
                }
            }
            
            # Análise de outros erros
            if ($stderr -match "permission denied|not authorized") {
                Write-Log "  CAUSA: Usuário não tem permissão CREATEDB" -Level Error
                Write-Log "  SOLUÇÃO: Execute como superuser ou: ALTER USER $User CREATEDB;" -Level Error
            }
            
            return $false
        }
    }
    catch {
        Write-Log "✗ Exceção ao criar banco: $($_.Exception.Message)" -Level Error
        return $false
    }
    finally {
        $env:PGPASSWORD = $null
    }
}
#endregion

#region Backup Functions
function Get-BackupType {
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

function Start-DatabaseBackup {
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
    Write-Log "========================================" -Level Info
    
    try {
        $outputDir = Split-Path $OutputPath -Parent
        if (-not (Test-Path $outputDir)) {
            $null = New-Item -ItemType Directory -Path $outputDir -Force
            Write-Log "Diretório criado: $outputDir" -Level Info
        }
        
        $env:PGPASSWORD = $Password
        
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $script:Config.pgDumpPath
        $psi.Arguments = "-h `"$HostName`" -p $Port -U `"$User`" -F c -b -v --no-owner --no-acl -f `"$OutputPath`" `"$Database`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.CreateNoWindow = $true
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        
        Write-Log "Executando pg_dump..." -Level Info
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi
        
        $null = $process.Start()
        
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

#region Restore Functions - PROFISSIONAL
function Start-DatabaseRestore {
    <#
    .SYNOPSIS
        Restore PROFISSIONAL com confirmações e garantias
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
    Write-Log "INICIANDO RESTORE PROFISSIONAL v3.0" -Level Info
    Write-Log "========================================" -Level Info
    Write-Log "Arquivo: $BackupFile" -Level Info
    
    # Detectar tipo
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
            $DatabaseName = Show-InputDialog -Title "Nome do Banco de Dados" `
                                            -Prompt "Informe o nome do banco de dados para restauração:" `
                                            -DefaultValue $detectedName
            
            if ([string]::IsNullOrWhiteSpace($DatabaseName)) {
                Write-Log "Operação cancelada" -Level Warning
                return $false
            }
        }
    }
    
    Write-Log "Banco de destino: $DatabaseName" -Level Info
    Write-Log "Host: $HostName`:$Port" -Level Info
    Write-Log "========================================" -Level Info
    
    # PASSO 1: Verificar se banco existe
    Write-Log "PASSO 1: Verificando se banco existe..." -Level Info
    $dbExists = Test-DatabaseExists -HostName $HostName -Port $Port -User $User -Password $Password -DatabaseName $DatabaseName
    
    if ($dbExists) {
        Write-Log "⚠ ATENÇÃO: Banco '$DatabaseName' JÁ EXISTE!" -Level Warning
        
        # CONFIRMAÇÃO OBRIGATÓRIA
        $result = [System.Windows.Forms.MessageBox]::Show(
            "O banco '$DatabaseName' JÁ EXISTE no servidor!`r`n`r`n" +
            "O que deseja fazer?`r`n`r`n" +
            "• SIM = Remover e recriar (APAGA TODOS OS DADOS)`r`n" +
            "• NÃO = Restaurar por cima (MESCLA com dados existentes)`r`n" +
            "• CANCELAR = Cancelar operação`r`n`r`n" +
            "⚠ ATENÇÃO: Esta ação não pode ser desfeita!",
            "Banco Existente - Escolha uma Opção",
            [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            # Usuário escolheu REMOVER e RECRIAR
            Write-Log "Usuário escolheu: REMOVER E RECRIAR" -Level Warning
            Write-Log "========================================" -Level Warning
            
            # CONFIRMAÇÃO DUPLA para segurança
            $doubleCheck = [System.Windows.Forms.MessageBox]::Show(
                "CONFIRMAÇÃO FINAL`r`n`r`n" +
                "Você tem CERTEZA que deseja APAGAR o banco '$DatabaseName'?`r`n`r`n" +
                "TODOS OS DADOS SERÃO PERDIDOS!`r`n`r`n" +
                "Esta ação é IRREVERSÍVEL!",
                "⚠ CONFIRMAÇÃO FINAL",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Exclamation
            )
            
            if ($doubleCheck -ne [System.Windows.Forms.DialogResult]::Yes) {
                Write-Log "Operação cancelada pelo usuário" -Level Info
                return $false
            }
            
            Write-Log "PASSO 2: Removendo banco existente..." -Level Warning
            $removed = Remove-DatabaseIfExists -HostName $HostName -Port $Port -User $User -Password $Password -DatabaseName $DatabaseName
            
            if (-not $removed) {
                Write-Log "✗ Falha ao remover banco existente" -Level Error
                [System.Windows.Forms.MessageBox]::Show(
                    "Não foi possível remover o banco existente.`r`n`r`nVerifique o log para detalhes.",
                    "Erro",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                return $false
            }
            
            Write-Log "PASSO 3: Criando banco limpo..." -Level Info
            $created = New-PostgreSQLDatabase -HostName $HostName -Port $Port -User $User -Password $Password -DatabaseName $DatabaseName
            
            if (-not $created) {
                Write-Log "✗ Falha ao criar banco" -Level Error
                [System.Windows.Forms.MessageBox]::Show(
                    "Não foi possível criar o banco.`r`n`r`nVerifique o log para detalhes.",
                    "Erro",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                return $false
            }
        }
        elseif ($result -eq [System.Windows.Forms.DialogResult]::No) {
            # Usuário escolheu MESCLAR
            Write-Log "Usuário escolheu: RESTAURAR POR CIMA (mesclar)" -Level Warning
            Write-Log "PASSO 2: Pulando criação (banco existe)" -Level Info
        }
        else {
            # Usuário CANCELOU
            Write-Log "Operação cancelada pelo usuário" -Level Info
            return $false
        }
    }
    else {
        # Banco não existe - criar novo
        Write-Log "✓ Banco não existe - será criado" -Level Success
        Write-Log "PASSO 2: Criando banco novo..." -Level Info
        
        $created = New-PostgreSQLDatabase -HostName $HostName -Port $Port -User $User -Password $Password -DatabaseName $DatabaseName
        
        if (-not $created) {
            Write-Log "✗ Falha ao criar banco" -Level Error
            [System.Windows.Forms.MessageBox]::Show(
                "Não foi possível criar o banco.`r`n`r`n" +
                "Possíveis causas:`r`n" +
                "• Usuário não tem permissão CREATEDB`r`n" +
                "• Servidor inacessível`r`n`r`n" +
                "Verifique o log para detalhes.",
                "Erro ao Criar Banco",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return $false
        }
    }
    
    # PASSO 3: Executar restore
    Write-Log "========================================" -Level Info
    Write-Log "PASSO FINAL: Executando RESTORE..." -Level Info
    Write-Log "========================================" -Level Info
    
    if ($backupType -eq "CUSTOM") {
        return Invoke-CustomRestore -HostName $HostName -Port $Port -User $User -Password $Password -DatabaseName $DatabaseName -BackupFile $BackupFile
    }
    else {
        return Invoke-PlainRestore -HostName $HostName -Port $Port -User $User -Password $Password -DatabaseName $DatabaseName -BackupFile $BackupFile
    }
}

function Invoke-CustomRestore {
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
        
        # Capturar erros críticos vs avisos
        $errorLines = @()
        $warningLines = @()
        
        while (-not $process.StandardError.EndOfStream) {
            $line = $process.StandardError.ReadLine()
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                if ($line -match "FATAL|ERROR.*authentication failed|ERROR.*does not exist|ERROR.*permission denied|ERROR.*syntax error") {
                    $errorLines += $line
                    Write-Log $line -Level Error
                }
                elseif ($line -match "WARNING|ERROR.*already exists") {
                    $warningLines += $line
                    Write-Log $line -Level Warning
                }
                else {
                    Write-Log $line -Level Info
                }
            }
        }
        
        $process.WaitForExit()
        
        Write-Log "========================================" -Level Info
        Write-Log "Código de saída: $($process.ExitCode)" -Level Info
        Write-Log "Erros críticos: $($errorLines.Count)" -Level Info
        Write-Log "Avisos: $($warningLines.Count)" -Level Info
        Write-Log "========================================" -Level Info
        
        $isSuccess = $false
        
        if ($process.ExitCode -eq 0) {
            $isSuccess = $true
            Write-Log "✓ Restore concluído com sucesso!" -Level Success
        }
        elseif ($process.ExitCode -eq 1 -and $errorLines.Count -eq 0) {
            $isSuccess = $true
            Write-Log "✓ Restore concluído com avisos (objetos já existentes)" -Level Success
        }
        else {
            Write-Log "✗ Restore falhou" -Level Error
        }
        
        if ($errorLines.Count -gt 0) {
            Write-Log "========================================" -Level Error
            Write-Log "ERROS CRÍTICOS:" -Level Error
            foreach ($err in $errorLines) {
                Write-Log "  $err" -Level Error
            }
            Write-Log "========================================" -Level Error
        }
        
        Write-Log "========================================" -Level Success
        
        if ($isSuccess) {
            [System.Windows.Forms.MessageBox]::Show(
                "Restore concluído com sucesso!`r`n`r`n" +
                "Banco: $DatabaseName`r`n" +
                "Avisos: $($warningLines.Count) (normal)",
                "Restore Concluído",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        else {
            [System.Windows.Forms.MessageBox]::Show(
                "Restore falhou!`r`n`r`nErros: $($errorLines.Count)`r`n`r`nVerifique o log.",
                "Erro no Restore",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
        
        return $isSuccess
    }
    catch {
        Write-Log "✗ Erro no restore: $($_.Exception.Message)" -Level Error
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
        
        $errorLines = @()
        $warningLines = @()
        
        while (-not $process.StandardError.EndOfStream) {
            $line = $process.StandardError.ReadLine()
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                if ($line -match "FATAL|ERROR.*authentication failed|ERROR.*does not exist|ERROR.*permission denied|ERROR.*syntax error") {
                    $errorLines += $line
                    Write-Log $line -Level Error
                }
                elseif ($line -match "WARNING|ERROR.*already exists|NOTICE") {
                    $warningLines += $line
                    Write-Log $line -Level Warning
                }
                else {
                    Write-Log $line -Level Info
                }
            }
        }
        
        $process.WaitForExit()
        
        $isSuccess = ($process.ExitCode -eq 0) -or (($process.ExitCode -eq 1 -or $process.ExitCode -eq 2) -and $errorLines.Count -eq 0)
        
        if ($isSuccess) {
            Write-Log "✓ Restore concluído!" -Level Success
            [System.Windows.Forms.MessageBox]::Show(
                "Restore concluído com sucesso!`r`n`r`nBanco: $DatabaseName",
                "Restore Concluído",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        else {
            Write-Log "✗ Restore falhou" -Level Error
            [System.Windows.Forms.MessageBox]::Show(
                "Restore falhou!`r`n`r`nErros: $($errorLines.Count)`r`n`r`nVerifique o log.",
                "Erro",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
        
        return $isSuccess
    }
    catch {
        Write-Log "✗ Erro no restore: $($_.Exception.Message)" -Level Error
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
    [CmdletBinding()]
    param(
        [bool]$Enabled = $true
    )
    
    if ($script:UI.btnConnectBkp) { $script:UI.btnConnectBkp.Enabled = $Enabled }
    if ($script:UI.btnBackup) { $script:UI.btnBackup.Enabled = $Enabled }
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
    [CmdletBinding()]
    param()
    
    $script:UI.Form = New-Object System.Windows.Forms.Form
    $script:UI.Form.Text = "$($script:Config.FormTitle) v$($script:Config.Version)"
    $script:UI.Form.Size = New-Object System.Drawing.Size(700, 600)
    $script:UI.Form.StartPosition = "CenterScreen"
    $script:UI.Form.FormBorderStyle = "FixedDialog"
    $script:UI.Form.MaximizeBox = $false
    $script:UI.Form.Icon = [System.Drawing.SystemIcons]::Application
    
    # Panel superior
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
    $lblVersion.Text = "Versão $($script:Config.Version) PROFISSIONAL | PostgreSQL: Verificando..."
    $lblVersion.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $lblVersion.ForeColor = [System.Drawing.Color]::Gray
    $lblVersion.Location = New-Object System.Drawing.Point(10, 40)
    $lblVersion.Size = New-Object System.Drawing.Size(645, 20)
    $panelInfo.Controls.Add($lblVersion)
    
    $script:UI.lblVersion = $lblVersion
    
    # TabControl
    $tabControl = New-Object System.Windows.Forms.TabControl
    $tabControl.Location = New-Object System.Drawing.Point(10, 95)
    $tabControl.Size = New-Object System.Drawing.Size(665, 260)
    $script:UI.Form.Controls.Add($tabControl)
    
    Initialize-BackupTab -TabControl $tabControl
    Initialize-RestoreTab -TabControl $tabControl
    
    # Log
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
    
    # Events
    $script:UI.Form.Add_Load({
        Write-Log "========================================" -Level Info
        Write-Log "PostgreSQL Backup & Restore Pro v$($script:Config.Version)" -Level Info
        Write-Log "VERSÃO PROFISSIONAL - Restore Robusto com Confirmações" -Level Info
        Write-Log "========================================" -Level Info
        Write-Log "Iniciando aplicação..." -Level Info
        
        if (Find-PostgreSQLBinaries) {
            Write-Log "Aplicação pronta para uso!" -Level Success
            if ($script:UI.lblVersion) {
                $script:UI.lblVersion.Text = "Versão $($script:Config.Version) PROFISSIONAL | PostgreSQL: ✓ Encontrado"
                $script:UI.lblVersion.ForeColor = [System.Drawing.Color]::Green
            }
        }
        else {
            Write-Log "ATENÇÃO: Configure o PostgreSQL para continuar" -Level Warning
            if ($script:UI.lblVersion) {
                $script:UI.lblVersion.Text = "Versão $($script:Config.Version) PROFISSIONAL | PostgreSQL: ✗ Não encontrado"
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
    
    # GroupBox Banco
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
    if ($script:UI.Form) {
        $script:UI.Form.Dispose()
    }
}
#endregion
