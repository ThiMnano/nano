Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$ErrorActionPreference = 'Stop'
# Verificação de Administrador (compatível com iwr | iex)
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    [System.Windows.Forms.MessageBox]::Show(
        "Este script precisa ser executado como Administrador.`nAbra o PowerShell como Administrador.",
        "Permissão",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )
    return
}
Write-Host "Verificando winget..."
$winget = Get-Command winget.exe -ErrorAction SilentlyContinue
if ($winget) {
    Write-Host "Winget já instalado"
}
else {
    Write-Host "Winget não encontrado. Abrindo instalador..."
    Start-Process "ms-appinstaller:?source=https://aka.ms/getwinget"
    [System.Windows.Forms.MessageBox]::Show(
        "Winget não encontrado.`nInstalador aberto.",
        "Winget",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}
# =========================
# LOG
# =========================
function Log($msg){
    $txtLog.AppendText("[$(Get-Date -Format HH:mm:ss)] $msg`r`n")
    $txtLog.ScrollToCaret()
}

# =========================
# LOCALIZAR BIN POSTGRESQL
# =========================
function Find-PgBin {
    $paths = @()

    # Registro oficial PostgreSQL
    $reg = "HKLM:\SOFTWARE\PostgreSQL\Installations"
    if (Test-Path $reg) {
        Get-ChildItem $reg | ForEach-Object {
            $base = (Get-ItemProperty $_.PsPath).BaseDirectory
            if ($base) {
                $paths += (Join-Path $base "bin")
            }
        }
    }

    # Program Files (padrão)
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

    # pgAdmin runtime (fallback)
    $paths += "$env:LOCALAPPDATA\Programs\pgAdmin 4\runtime"

    foreach ($p in $paths) {
        if (Test-Path (Join-Path $p "pg_restore.exe")) {
            return $p
        }
    }
    return $null
}

$pgBin = Find-PgBin
if(!$pgBin){
    [System.Windows.Forms.MessageBox]::Show(
        "pg_restore.exe não encontrado.`nInstale o PostgreSQL.",
        "Erro",0,16
    )
    exit
}

$pg_restore = Join-Path $pgBin "pg_restore.exe"
$psql       = Join-Path $pgBin "psql.exe"

# =========================
# FORM
# =========================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Restore PostgreSQL (.backup / .sql)"
$form.Size = New-Object System.Drawing.Size(700,550)
$form.StartPosition = "CenterScreen"

function Add-Label($t,$x,$y){
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $t
    $l.Location = New-Object System.Drawing.Point($x,$y)
    $l.AutoSize = $true
    $form.Controls.Add($l)
}

function Add-TextBox($x,$y,$w=300,$pwd=$false){
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($x,$y)
    $t.Width = $w
    if($pwd){ $t.UseSystemPasswordChar = $true }
    $form.Controls.Add($t)
    return $t
}

Add-Label "Servidor:" 20 20
$txtHost = Add-TextBox 140 18
$txtHost.Text = "localhost"

Add-Label "Porta:" 20 55
$txtPort = Add-TextBox 140 53 80
$txtPort.Text = "5432"

Add-Label "Usuário:" 20 90
$txtUser = Add-TextBox 140 88

Add-Label "Senha:" 20 125
$txtPass = Add-TextBox 140 123 300 $true

Add-Label "Arquivo Backup:" 20 160
$txtFile = Add-TextBox 140 158 420

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Buscar"
$btnBrowse.Location = New-Object System.Drawing.Point(580,156)
$form.Controls.Add($btnBrowse)

Add-Label "Log:" 20 195
$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20,220)
$txtLog.Size = New-Object System.Drawing.Size(640,220)
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.ReadOnly = $true
$form.Controls.Add($txtLog)

$btnRestore = New-Object System.Windows.Forms.Button
$btnRestore.Text = "Restaurar"
$btnRestore.Location = New-Object System.Drawing.Point(290,460)
$btnRestore.Width = 120
$form.Controls.Add($btnRestore)

# =========================
# BROWSE
# =========================
$btnBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "Backup PostgreSQL (*.backup;*.sql)|*.backup;*.sql"
    if($dlg.ShowDialog() -eq "OK"){
        $txtFile.Text = $dlg.FileName
    }
})

# =========================
# RESTORE
# =========================
$btnRestore.Add_Click({

    if(!$txtHost.Text -or !$txtPort.Text -or !$txtUser.Text -or !$txtPass.Text -or !$txtFile.Text){
        Log "Erro: campos obrigatórios não preenchidos"
        return
    }

    if(!(Test-Path $txtFile.Text)){
        Log "Erro: arquivo não encontrado"
        return
    }

    $env:PGPASSWORD = $txtPass.Text
    Log "Bin PostgreSQL: $pgBin"

    $ext = [IO.Path]::GetExtension($txtFile.Text).ToLower()

    if($ext -eq ".backup"){
        Log "Detectado backup CUSTOM (.backup)"

        $dbName = (& $pg_restore -l "`"$($txtFile.Text)`"" |
                  Select-String "DATABASE" |
                  Select-Object -First 1).ToString().Split(" ")[-1]

        if(!$dbName){
            Log "Erro ao detectar banco"
            return
        }

        Log "Banco detectado: $dbName"

        $exists = & $psql -h $txtHost.Text -p $txtPort.Text -U $txtUser.Text `
            -d postgres -t -c "SELECT 1 FROM pg_database WHERE datname='$dbName';"

        if($exists.Trim() -eq "1"){
            $resp = [System.Windows.Forms.MessageBox]::Show(
                "Banco '$dbName' já existe. Substituir?",
                "Confirmação",4,32
            )
            if($resp -ne "Yes"){ return }

            Log "Finalizando conexões..."
            & $psql -h $txtHost.Text -p $txtPort.Text -U $txtUser.Text -d postgres -c "
                SELECT pg_terminate_backend(pid)
                FROM pg_stat_activity
                WHERE datname='$dbName';
            "
        }

        Log "Iniciando pg_restore..."
        $proc = Start-Process $pg_restore -Wait -NoNewWindow -PassThru `
            -ArgumentList @(
                "-h",$txtHost.Text,
                "-p",$txtPort.Text,
                "-U",$txtUser.Text,
                "-C","-c","--if-exists",
                "-d","postgres",
                "--no-owner",
                "`"$($txtFile.Text)`""
            )
    }
    else {
        Log "Detectado backup SQL (.sql)"
        Log "Executando psql..."

        $proc = Start-Process $psql -Wait -NoNewWindow -PassThru `
            -ArgumentList @(
                "-h",$txtHost.Text,
                "-p",$txtPort.Text,
                "-U",$txtUser.Text,
                "-f","`"$($txtFile.Text)`""
            )
    }

    if($proc.ExitCode -ne 0){
        Log "ERRO no restore (ExitCode=$($proc.ExitCode))"
        [System.Windows.Forms.MessageBox]::Show("Erro ao restaurar.","Erro",0,16)
    }
    else {
        Log "Restore concluído com sucesso"
        [System.Windows.Forms.MessageBox]::Show("Banco restaurado com sucesso!","Sucesso",0,64)
        $form.Close()
    }
})

$form.ShowDialog()
