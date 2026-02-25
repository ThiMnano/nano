# ========================================
# PostgreSQL Backup & Restore Manager
# Versão 2.2 - Refatorada
# ========================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Configuração de encoding (segura)
$OutputEncoding = [System.Text.Encoding]::UTF8
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$ErrorActionPreference = 'Stop'

# ========================================
# VERIFICAÇÃO DE ADMINISTRADOR
# ========================================
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Este script precisa ser executado como Administrador.`n`nAbra o PowerShell como Administrador e execute novamente.",
        "Permissão Necessária",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    exit
}

# ========================================
# VERIFICAÇÃO DO WINGET (OPCIONAL)
# ========================================
$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if (!$winget) {
    $resp = [System.Windows.Forms.MessageBox]::Show(
        "Winget não encontrado.`n`nDeseja abrir o instalador?",
        "Winget",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question
    )
    if ($resp -eq "Yes") {
        Start-Process "ms-appinstaller:?source=https://aka.ms/getwinget"
    }
}

# ========================================
# CONFIGURAR ENVIRONMENT PARA POSTGRESQL
# ========================================
function Set-PgEnvironment {
    $env:PGCLIENTENCODING = "UTF8"
    $env:PAGER = ""
}

# ========================================
# LOCALIZAR BINÁRIOS DO POSTGRESQL
# ========================================
function Find-PgBin {
    $paths = @()

    # Registro oficial PostgreSQL
    $reg = "HKLM:\SOFTWARE\PostgreSQL\Installations"
    if (Test-Path $reg) {
        Get-ChildItem $reg -ErrorAction SilentlyContinue | ForEach-Object {
            $base = (Get-ItemProperty $_.PsPath).BaseDirectory
            if ($base) {
                $paths += (Join-Path $base "bin")
            }
        }
    }

    # Program Files
    $pf = "${env:ProgramFiles}\PostgreSQL"
    if (Test-Path $pf) {
        Get-ChildItem $pf -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $paths += (Join-Path $_.FullName "bin")
        }
    }

    # Program Files (x86)
    $pf86 = "${env:ProgramFiles(x86)}\PostgreSQL"
    if (Test-Path $pf86) {
        Get-ChildItem $pf86 -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $paths += (Join-Path $_.FullName "bin")
        }
    }

    # pgAdmin runtime
    $paths += "$env:LOCALAPPDATA\Programs\pgAdmin 4\runtime"

    foreach ($p in $paths) {
        if (Test-Path (Join-Path $p "pg_restore.exe")) {
            return $p
        }
    }
    return $null
}

$pgBin = Find-PgBin
if (!$pgBin) {
    [System.Windows.Forms.MessageBox]::Show(
        "Binários do PostgreSQL não encontrados.`n`nInstale o PostgreSQL ou pgAdmin 4.",
        "Erro",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit
}

$pg_restore = Join-Path $pgBin "pg_restore.exe"
$pg_dump    = Join-Path $pgBin "pg_dump.exe"
$psql       = Join-Path $pgBin "psql.exe"

Set-PgEnvironment

# ========================================
# VARIÁVEIS GLOBAIS DE CONTROLES
# ========================================
$script:txtLog = $null
$script:txtHost = $null
$script:txtPort = $null
$script:txtUser = $null
$script:txtPass = $null
$script:txtRestoreFile = $null
$script:txtRestoreDB = $null
$script:txtBackupDB = $null
$script:txtBackupFile = $null
$script:chkDropIfExists = $null
$script:cmbFormat = $null

# ========================================
# FUNÇÃO DE LOG
# ========================================
function Log {
    param([string]$msg, [string]$tipo = "INFO")
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $logMsg = "[$timestamp] [$tipo] $msg"
    
    $script:txtLog.AppendText("$logMsg`r`n")
    $script:txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

# ========================================
# FUNÇÕES AUXILIARES DE CRIAÇÃO
# ========================================
function New-Label {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [System.Windows.Forms.Control]$Parent
    )
    
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.AutoSize = $true
    $Parent.Controls.Add($label)
    return $label
}

function New-TextBox {
    param(
        [int]$X,
        [int]$Y,
        [int]$Width = 300,
        [bool]$Password = $false,
        [System.Windows.Forms.Control]$Parent
    )
    
    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Location = New-Object System.Drawing.Point($X, $Y)
    $textbox.Width = $Width
    if ($Password) { $textbox.UseSystemPasswordChar = $true }
    $Parent.Controls.Add($textbox)
    return $textbox
}

function New-Button {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [int]$Width = 100,
        [System.Windows.Forms.Control]$Parent
    )
    
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Location = New-Object System.Drawing.Point($X, $Y)
    $button.Width = $Width
    $Parent.Controls.Add($button)
    return $button
}

# ========================================
# CRIAR FORMULÁRIO PRINCIPAL
# ========================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "PostgreSQL Manager - Backup & Restore"
$form.Size = New-Object System.Drawing.Size(750, 700)
$form.StartPosition = "CenterScreen"
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# ========================================
# SEÇÃO: CONEXÃO (GroupBox)
# ========================================
$groupConn = New-Object System.Windows.Forms.GroupBox
$groupConn.Text = "Conexão PostgreSQL"
$groupConn.Location = New-Object System.Drawing.Point(20, 15)
$groupConn.Size = New-Object System.Drawing.Size(690, 140)
$form.Controls.Add($groupConn)

# Labels e TextBoxes dentro do GroupBox (coordenadas relativas)
$lblHost = New-Label -Text "Servidor:" -X 20 -Y 30 -Parent $groupConn
$script:txtHost = New-TextBox -X 120 -Y 28 -Width 200 -Parent $groupConn

$lblPort = New-Label -Text "Porta:" -X 340 -Y 30 -Parent $groupConn
$script:txtPort = New-TextBox -X 400 -Y 28 -Width 80 -Parent $groupConn

$lblUser = New-Label -Text "Usuário:" -X 20 -Y 65 -Parent $groupConn
$script:txtUser = New-TextBox -X 120 -Y 63 -Width 200 -Parent $groupConn

$lblPass = New-Label -Text "Senha:" -X 340 -Y 65 -Parent $groupConn
$script:txtPass = New-TextBox -X 400 -Y 63 -Width 250 -Password $true -Parent $groupConn

$btnTestar = New-Button -Text "Testar Conexão" -X 20 -Y 100 -Width 150 -Parent $groupConn

# ========================================
# SEÇÃO: TABS
# ========================================
$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(20, 165)
$tabControl.Size = New-Object System.Drawing.Size(690, 280)
$form.Controls.Add($tabControl)

# ========================================
# TAB 1: RESTAURAR BACKUP
# ========================================
$tabRestore = New-Object System.Windows.Forms.TabPage
$tabRestore.Text = "Restaurar Backup"
$tabControl.TabPages.Add($tabRestore)

$lblRestoreFile = New-Label -Text "Arquivo de Backup:" -X 20 -Y 20 -Parent $tabRestore
$script:txtRestoreFile = New-TextBox -X 20 -Y 45 -Width 550 -Parent $tabRestore
$btnBrowseRestore = New-Button -Text "Buscar..." -X 580 -Y 43 -Width 90 -Parent $tabRestore

$lblRestoreDB = New-Label -Text "Nome do Banco (detectado/editável):" -X 20 -Y 80 -Parent $tabRestore
$script:txtRestoreDB = New-TextBox -X 20 -Y 105 -Width 400 -Parent $tabRestore
$btnAnalisar = New-Button -Text "Analisar Backup" -X 430 -Y 103 -Width 140 -Parent $tabRestore

$script:chkDropIfExists = New-Object System.Windows.Forms.CheckBox
$script:chkDropIfExists.Text = "Recriar banco se já existir (DROP + CREATE)"
$script:chkDropIfExists.Location = New-Object System.Drawing.Point(20, 140)
$script:chkDropIfExists.Width = 400
$script:chkDropIfExists.Checked = $true
$tabRestore.Controls.Add($script:chkDropIfExists)

$btnRestore = New-Button -Text "Restaurar Agora" -X 20 -Y 180 -Width 150 -Parent $tabRestore
$btnRestore.Height = 35
$btnRestore.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

# ========================================
# TAB 2: CRIAR BACKUP
# ========================================
$tabBackup = New-Object System.Windows.Forms.TabPage
$tabBackup.Text = "Criar Backup"
$tabControl.TabPages.Add($tabBackup)

$lblBackupDB = New-Label -Text "Nome do Banco:" -X 20 -Y 20 -Parent $tabBackup
$script:txtBackupDB = New-TextBox -X 20 -Y 45 -Width 400 -Parent $tabBackup
$btnListarBancos = New-Button -Text "Listar Bancos" -X 430 -Y 43 -Width 140 -Parent $tabBackup

$lblBackupFile = New-Label -Text "Salvar Backup em:" -X 20 -Y 80 -Parent $tabBackup
$script:txtBackupFile = New-TextBox -X 20 -Y 105 -Width 550 -Parent $tabBackup
$btnBrowseBackup = New-Button -Text "Buscar..." -X 580 -Y 103 -Width 90 -Parent $tabBackup

$lblFormat = New-Label -Text "Formato:" -X 20 -Y 140 -Parent $tabBackup
$script:cmbFormat = New-Object System.Windows.Forms.ComboBox
$script:cmbFormat.Location = New-Object System.Drawing.Point(100, 138)
$script:cmbFormat.Width = 200
$script:cmbFormat.DropDownStyle = "DropDownList"
$script:cmbFormat.Items.AddRange(@("Custom (.backup)", "SQL Puro (.sql)"))
$script:cmbFormat.SelectedIndex = 0
$tabBackup.Controls.Add($script:cmbFormat)

$btnBackup = New-Button -Text "Criar Backup Agora" -X 20 -Y 180 -Width 150 -Parent $tabBackup
$btnBackup.Height = 35
$btnBackup.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)

# ========================================
# SEÇÃO: LOG
# ========================================
$lblLog = New-Label -Text "Log de Operações:" -X 20 -Y 455 -Parent $form
$script:txtLog = New-Object System.Windows.Forms.TextBox
$script:txtLog.Location = New-Object System.Drawing.Point(20, 480)
$script:txtLog.Size = New-Object System.Drawing.Size(690, 160)
$script:txtLog.Multiline = $true
$script:txtLog.ScrollBars = "Vertical"
$script:txtLog.ReadOnly = $true
$script:txtLog.Font = New-Object System.Drawing.Font("Consolas", 8)
$script:txtLog.BackColor = [System.Drawing.Color]::Black
$script:txtLog.ForeColor = [System.Drawing.Color]::Lime
$form.Controls.Add($script:txtLog)

# Mensagem inicial no log
Log "========================================" 
Log "Sistema iniciado com sucesso!" "INFO"
Log "Binários PostgreSQL: $pgBin" "INFO"
Log "Versão: 2.2 Refatorada" "INFO"
Log "========================================" 

# ========================================
# EVENTO: TESTAR CONEXÃO
# ========================================
$btnTestar.Add_Click({
    try {
        Log "Testando conexão..."
        
        if (!$script:txtHost.Text -or !$script:txtPort.Text -or !$script:txtUser.Text -or !$script:txtPass.Text) {
            Log "Preencha todos os campos de conexão!" "ERRO"
            [System.Windows.Forms.MessageBox]::Show(
                "Preencha todos os campos de conexão!",
                "Atenção",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        $env:PGPASSWORD = $script:txtPass.Text
        
        $result = & $psql -h $script:txtHost.Text -p $script:txtPort.Text -U $script:txtUser.Text `
            -d postgres -t -c "SELECT version();" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $versao = ($result | Select-Object -First 1).ToString().Trim()
            Log "Conexão bem-sucedida!" "SUCESSO"
            Log "Versão: $versao" "INFO"
            [System.Windows.Forms.MessageBox]::Show(
                "Conexão estabelecida com sucesso!`n`n$versao",
                "Sucesso",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        else {
            Log "Falha na conexão" "ERRO"
            [System.Windows.Forms.MessageBox]::Show(
                "Falha ao conectar ao servidor PostgreSQL.`n`nVerifique os dados de conexão.",
                "Erro de Conexão",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
    catch {
        Log "Erro ao testar conexão: $($_.Exception.Message)" "ERRO"
        [System.Windows.Forms.MessageBox]::Show(
            "Erro: $($_.Exception.Message)",
            "Erro",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# ========================================
# EVENTO: BUSCAR ARQUIVO DE RESTORE
# ========================================
$btnBrowseRestore.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "Arquivos PostgreSQL (*.backup;*.sql;*.dump)|*.backup;*.sql;*.dump|Todos (*.*)|*.*"
    $dlg.Title = "Selecione o arquivo de backup"
    
    if ($dlg.ShowDialog() -eq "OK") {
        $script:txtRestoreFile.Text = $dlg.FileName
        Log "Arquivo selecionado: $($dlg.FileName)"
    }
})

# ========================================
# EVENTO: ANALISAR BACKUP
# ========================================
$btnAnalisar.Add_Click({
    try {
        if (!$script:txtRestoreFile.Text -or !(Test-Path $script:txtRestoreFile.Text)) {
            Log "Selecione um arquivo válido!" "ERRO"
            [System.Windows.Forms.MessageBox]::Show(
                "Selecione um arquivo de backup válido primeiro!",
                "Atenção",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        Log "Analisando arquivo de backup..."
        $ext = [IO.Path]::GetExtension($script:txtRestoreFile.Text).ToLower()
        
        if ($ext -eq ".backup" -or $ext -eq ".dump") {
            Log "Formato: Custom/Dump"
            
            $output = & $pg_restore -l $script:txtRestoreFile.Text 2>&1 | Select-String "DATABASE"
            
            if ($output) {
                $dbName = ($output | Select-Object -First 1).ToString() -replace '.*DATABASE\s+(\S+).*', '$1'
                $script:txtRestoreDB.Text = $dbName
                Log "Banco detectado: $dbName" "SUCESSO"
                [System.Windows.Forms.MessageBox]::Show(
                    "Banco detectado: $dbName`n`nVocê pode editar o nome se necessário.",
                    "Análise Concluída",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Information
                )
            }
            else {
                Log "Não foi possível detectar o nome do banco" "AVISO"
                $script:txtRestoreDB.Text = ""
                [System.Windows.Forms.MessageBox]::Show(
                    "Não foi possível detectar o nome do banco automaticamente.`n`nPreencha manualmente.",
                    "Aviso",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
            }
        }
        else {
            Log "Formato: SQL - Especifique o banco manualmente" "AVISO"
            $script:txtRestoreDB.Text = ""
            [System.Windows.Forms.MessageBox]::Show(
                "Arquivo SQL detectado.`n`nEspecifique o nome do banco manualmente.",
                "Informação",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
    }
    catch {
        Log "Erro ao analisar: $($_.Exception.Message)" "ERRO"
        [System.Windows.Forms.MessageBox]::Show(
            "Erro ao analisar arquivo: $($_.Exception.Message)",
            "Erro",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# ========================================
# EVENTO: RESTAURAR
# ========================================
$btnRestore.Add_Click({
    try {
        # Validações
        if (!$script:txtHost.Text -or !$script:txtPort.Text -or !$script:txtUser.Text -or !$script:txtPass.Text) {
            Log "Preencha todos os campos de conexão!" "ERRO"
            [System.Windows.Forms.MessageBox]::Show(
                "Preencha todos os campos de conexão!",
                "Atenção",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        if (!$script:txtRestoreFile.Text -or !(Test-Path $script:txtRestoreFile.Text)) {
            Log "Arquivo de backup não encontrado!" "ERRO"
            [System.Windows.Forms.MessageBox]::Show(
                "Selecione um arquivo de backup válido!",
                "Atenção",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        if (!$script:txtRestoreDB.Text) {
            Log "Nome do banco não especificado!" "ERRO"
            [System.Windows.Forms.MessageBox]::Show(
                "Especifique o nome do banco de destino!",
                "Atenção",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        $dbName = $script:txtRestoreDB.Text
        $env:PGPASSWORD = $script:txtPass.Text
        
        # Verificar se banco existe
        Log "Verificando banco '$dbName'..."
        $exists = & $psql -h $script:txtHost.Text -p $script:txtPort.Text -U $script:txtUser.Text `
            -d postgres -t -c "SELECT 1 FROM pg_database WHERE datname='$dbName';" 2>&1
        
        if ($exists -match "1") {
            if ($script:chkDropIfExists.Checked) {
                $resp = [System.Windows.Forms.MessageBox]::Show(
                    "O banco '$dbName' já existe e será REMOVIDO e RECRIADO.`n`nTodos os dados atuais serão perdidos!`n`nDeseja continuar?",
                    "ATENÇÃO",
                    [System.Windows.Forms.MessageBoxButtons]::YesNo,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
                
                if ($resp -ne "Yes") {
                    Log "Operação cancelada pelo usuário" "AVISO"
                    return
                }
                
                Log "Encerrando conexões ativas..."
                & $psql -h $script:txtHost.Text -p $script:txtPort.Text -U $script:txtUser.Text -d postgres -c "
                    SELECT pg_terminate_backend(pid)
                    FROM pg_stat_activity
                    WHERE datname='$dbName' AND pid <> pg_backend_pid();
                " 2>&1 | Out-Null
            }
            else {
                Log "Banco já existe e opção de recriar está desmarcada" "ERRO"
                [System.Windows.Forms.MessageBox]::Show(
                    "O banco '$dbName' já existe.`n`nMarque a opção 'Recriar banco se já existir' ou altere o nome.",
                    "Banco Existente",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                )
                return
            }
        }
        
        $ext = [IO.Path]::GetExtension($script:txtRestoreFile.Text).ToLower()
        
        Log "========================================"
        Log "Iniciando restauração..." "INFO"
        Log "Banco: $dbName" "INFO"
        Log "Arquivo: $($script:txtRestoreFile.Text)" "INFO"
        Log "========================================"
        
        if ($ext -eq ".backup" -or $ext -eq ".dump") {
            Log "Executando pg_restore..."
            
            $proc = Start-Process $pg_restore -Wait -NoNewWindow -PassThru -ArgumentList @(
                "-h", $script:txtHost.Text,
                "-p", $script:txtPort.Text,
                "-U", $script:txtUser.Text,
                "-d", "postgres",
                "-C",
                "-c",
                "--if-exists",
                "--no-owner",
                "--no-privileges",
                "-v",
                $script:txtRestoreFile.Text
            )
        }
        else {
            Log "Executando psql para arquivo SQL..."
            
            $proc = Start-Process $psql -Wait -NoNewWindow -PassThru -ArgumentList @(
                "-h", $script:txtHost.Text,
                "-p", $script:txtPort.Text,
                "-U", $script:txtUser.Text,
                "-d", "postgres",
                "-f", $script:txtRestoreFile.Text
            )
        }
        
        Log "========================================"
        
        if ($proc.ExitCode -eq 0) {
            Log "Restauração concluída com SUCESSO!" "SUCESSO"
            [System.Windows.Forms.MessageBox]::Show(
                "Banco '$dbName' restaurado com sucesso!",
                "Sucesso",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        else {
            Log "ERRO na restauração (Código: $($proc.ExitCode))" "ERRO"
            [System.Windows.Forms.MessageBox]::Show(
                "Erro durante a restauração!`n`nCódigo: $($proc.ExitCode)`n`nVerifique o log.",
                "Erro",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
    catch {
        Log "Exceção: $($_.Exception.Message)" "ERRO"
        [System.Windows.Forms.MessageBox]::Show(
            "Erro: $($_.Exception.Message)",
            "Erro",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# ========================================
# EVENTO: LISTAR BANCOS
# ========================================
$btnListarBancos.Add_Click({
    try {
        Log "Listando bancos disponíveis..."
        
        if (!$script:txtHost.Text -or !$script:txtPort.Text -or !$script:txtUser.Text -or !$script:txtPass.Text) {
            Log "Preencha os campos de conexão primeiro!" "ERRO"
            [System.Windows.Forms.MessageBox]::Show(
                "Preencha os campos de conexão primeiro!",
                "Atenção",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        $env:PGPASSWORD = $script:txtPass.Text
        
        $bancos = & $psql -h $script:txtHost.Text -p $script:txtPort.Text -U $script:txtUser.Text `
            -d postgres -t -c "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;" 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $listaBancos = ($bancos | Where-Object { $_.Trim() -ne "" } | ForEach-Object { $_.Trim() }) -join "`n"
            Log "Bancos encontrados:" "SUCESSO"
            Log $listaBancos "INFO"
            
            [System.Windows.Forms.MessageBox]::Show(
                "Bancos disponíveis:`n`n$listaBancos",
                "Lista de Bancos",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
        else {
            Log "Erro ao listar bancos" "ERRO"
            [System.Windows.Forms.MessageBox]::Show(
                "Erro ao listar bancos.`n`nVerifique a conexão.",
                "Erro",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
    catch {
        Log "Erro: $($_.Exception.Message)" "ERRO"
        [System.Windows.Forms.MessageBox]::Show(
            "Erro: $($_.Exception.Message)",
            "Erro",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# ========================================
# EVENTO: BUSCAR LOCAL PARA SALVAR BACKUP
# ========================================
$btnBrowseBackup.Add_Click({
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter = "Backup Custom (*.backup)|*.backup|SQL Puro (*.sql)|*.sql"
    $dlg.Title = "Salvar backup como"
    $dlg.FileName = "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    
    if ($dlg.ShowDialog() -eq "OK") {
        $script:txtBackupFile.Text = $dlg.FileName
        Log "Destino: $($dlg.FileName)"
    }
})

# ========================================
# EVENTO: CRIAR BACKUP
# ========================================
$btnBackup.Add_Click({
    try {
        # Validações
        if (!$script:txtHost.Text -or !$script:txtPort.Text -or !$script:txtUser.Text -or !$script:txtPass.Text) {
            Log "Preencha todos os campos de conexão!" "ERRO"
            [System.Windows.Forms.MessageBox]::Show(
                "Preencha todos os campos de conexão!",
                "Atenção",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        if (!$script:txtBackupDB.Text) {
            Log "Nome do banco não especificado!" "ERRO"
            [System.Windows.Forms.MessageBox]::Show(
                "Especifique o nome do banco!",
                "Atenção",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        if (!$script:txtBackupFile.Text) {
            Log "Destino do backup não especificado!" "ERRO"
            [System.Windows.Forms.MessageBox]::Show(
                "Especifique onde salvar o backup!",
                "Atenção",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return
        }
        
        $dbName = $script:txtBackupDB.Text
        $env:PGPASSWORD = $script:txtPass.Text
        
        # Verificar se banco existe
        Log "Verificando banco '$dbName'..."
        $exists = & $psql -h $script:txtHost.Text -p $script:txtPort.Text -U $script:txtUser.Text `
            -d postgres -t -c "SELECT 1 FROM pg_database WHERE datname='$dbName';" 2>&1
        
        if ($exists -notmatch "1") {
            Log "Banco '$dbName' não existe!" "ERRO"
            [System.Windows.Forms.MessageBox]::Show(
                "O banco '$dbName' não foi encontrado!",
                "Erro",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return
        }
        
        Log "========================================"
        Log "Iniciando backup..." "INFO"
        Log "Banco: $dbName" "INFO"
        Log "Destino: $($script:txtBackupFile.Text)" "INFO"
        Log "========================================"
        
        if ($script:cmbFormat.SelectedIndex -eq 0) {
            # Formato Custom
            Log "Formato: Custom (.backup)"
            
            $proc = Start-Process $pg_dump -Wait -NoNewWindow -PassThru -ArgumentList @(
                "-h", $script:txtHost.Text,
                "-p", $script:txtPort.Text,
                "-U", $script:txtUser.Text,
                "-F", "c",
                "-b",
                "-v",
                "-f", $script:txtBackupFile.Text,
                $dbName
            )
        }
        else {
            # Formato SQL
            Log "Formato: SQL Puro (.sql)"
            
            $proc = Start-Process $pg_dump -Wait -NoNewWindow -PassThru -ArgumentList @(
                "-h", $script:txtHost.Text,
                "-p", $script:txtPort.Text,
                "-U", $script:txtUser.Text,
                "-f", $script:txtBackupFile.Text,
                $dbName
            )
        }
        
        Log "========================================"
        
        if ($proc.ExitCode -eq 0) {
            $fileInfo = Get-Item $script:txtBackupFile.Text
            $tamanho = "{0:N2} MB" -f ($fileInfo.Length / 1MB)
            
            Log "Backup concluído com SUCESSO!" "SUCESSO"
            Log "Tamanho: $tamanho" "INFO"
            
            $resposta = [System.Windows.Forms.MessageBox]::Show(
                "Backup criado com sucesso!`n`nArquivo: $($script:txtBackupFile.Text)`nTamanho: $tamanho`n`nDeseja abrir a pasta?",
                "Sucesso",
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
            
            if ($resposta -eq "Yes") {
                $pasta = Split-Path $script:txtBackupFile.Text
                Start-Process explorer.exe -ArgumentList $pasta
            }
        }
        else {
            Log "ERRO no backup (Código: $($proc.ExitCode))" "ERRO"
            [System.Windows.Forms.MessageBox]::Show(
                "Erro durante o backup!`n`nCódigo: $($proc.ExitCode)",
                "Erro",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }
    catch {
        Log "Exceção: $($_.Exception.Message)" "ERRO"
        [System.Windows.Forms.MessageBox]::Show(
            "Erro: $($_.Exception.Message)",
            "Erro",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
})

# ========================================
# EXEMPLOS NO LOG
# ========================================
Log "EXEMPLOS DE USO VIA LINHA DE COMANDO:" "INFO"
Log "Backup: `$env:PGPASSWORD='senha'; pg_dump -h host -U user -p 5432 -F c -f arquivo.backup banco"
Log "Restore: `$env:PGPASSWORD='senha'; pg_restore -h host -U user -p 5432 -C -d postgres arquivo.backup"
Log "========================================"

# ========================================
# EXIBIR FORMULÁRIO
# ========================================
[void]$form.ShowDialog()
