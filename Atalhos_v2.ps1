Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

$ErrorActionPreference = 'SilentlyContinue'
$wshell = New-Object -ComObject Wscript.Shell
$Button = [System.Windows.MessageBoxButton]::YesNoCancel
$ErrorIco = [System.Windows.MessageBoxImage]::Error
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
	Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
	Exit
}

# GUI Specs
Write-Host "Checking winget..."

# Check if winget is installed
if (Test-Path ~\AppData\Local\Microsoft\WindowsApps\winget.exe){
    'Winget Already Installed'
}
else{
    # Installing winget from the Microsoft Store
	Write-Host "Winget not found, installing it now."
    $ResultText.text = "`r`n" +"`r`n" + "Installing Winget... Please Wait"
	Start-Process "ms-appinstaller:?source=https://aka.ms/getwinget"
	$nid = (Get-Process AppInstaller).Id
	Wait-Process -Id $nid
	Write-Host Winget Installed
    $ResultText.text = "`r`n" +"`r`n" + "Winget Installed - Ready for Next Task"
}

#region Generated Form Objects
$MainMenu                            = New-Object system.Windows.Forms.Form
$MainMenu.ClientSize                 = New-Object System.Drawing.Point(1050,1000)
$MainMenu.text                       = "Atalhos por Thiago Martins"
$MainMenu.StartPosition              = "CenterScreen"
$MainMenu.TopMost                    = $false
$MainMenu.BackColor                  = [System.Drawing.ColorTranslator]::FromHtml("#e9e9e9")
$MainMenu.AutoScaleDimensions        = '192, 192'
$MainMenu.AutoScaleMode              = "Dpi"
$MainMenu.AutoSize                   = $True
$MainMenu.AutoScroll                 = $True
$MainMenu.ClientSize                 = '1050, 1000'
$MainMenu.FormBorderStyle            = 'FixedSingle'

# GUI Icon
$iconBase64 = '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'
$iconBytes                           = [Convert]::FromBase64String($iconBase64)
$stream                              = New-Object IO.MemoryStream($iconBytes, 0, $iconBytes.Length)
$stream.Write($iconBytes, 0, $iconBytes.Length)
$MainMenu.Icon                       = [System.Drawing.Icon]::FromHandle((New-Object System.Drawing.Bitmap -Argument $stream).GetHIcon())
$MainMenu.Width                      = $objImage.Width
$MainMenu.Height                     = $objImage.Height

# ====Modulos import==== #
Import-Module BitsTransfer -Force

# ====Logo==== #
$PictureBox1                     = New-Object system.Windows.Forms.PictureBox
$PictureBox1.width               = 60
$PictureBox1.height              = 60
$PictureBox1.location            = New-Object System.Drawing.Point(25,125)
$PictureBox1.imageLocation       = "https://raw.githubusercontent.com/ThiMnano/nano/main/HelpDesk.png"
$PictureBox1.SizeMode            = [System.Windows.Forms.PictureBoxSizeMode]::zoom

$MainMenu.Controls.Add($PictureBox1)

#Panels
$Panel1 = New-Object System.Windows.Forms.Panel
$Panel2 = New-Object System.Windows.Forms.Panel
$Panel3 = New-Object System.Windows.Forms.Panel

# ==== Botoes 1º aba ==== #
$Programas = New-Object System.Windows.Forms.Button
$Firewall = New-Object System.Windows.Forms.Button
$gestor = New-Object System.Windows.Forms.Button
$Impressoras = New-Object System.Windows.Forms.Button
$pastas = New-Object System.Windows.Forms.Button
$internet = New-Object System.Windows.Forms.Button
$sistema = New-Object System.Windows.Forms.Button
$ncpa = New-Object System.Windows.Forms.Button
$oldcontrolpanel = New-Object System.Windows.Forms.Button
$oldpower = New-Object System.Windows.Forms.Button
$temp = New-Object System.Windows.Forms.Button
$clean = New-Object System.Windows.Forms.Button
# ==== Botoes 2º aba ==== #
$nano = New-Object System.Windows.Forms.Button
$NFE = New-Object System.Windows.Forms.Button
$NFSE = New-Object System.Windows.Forms.Button
$NFCE = New-Object System.Windows.Forms.Button
$Boleto = New-Object System.Windows.Forms.Button
$nanorar = New-Object System.Windows.Forms.Button
$setupnano = New-Object System.Windows.Forms.Button
$crytal = New-Object System.Windows.Forms.Button
$sql = New-Object System.Windows.Forms.Button
$winrar = New-Object System.Windows.Forms.Button
$Bartender64 = New-Object System.Windows.Forms.Button
$Bartender32 = New-Object System.Windows.Forms.Button
# ==== Botoes 3º aba ==== #
$DieBold = New-Object System.Windows.Forms.Button
$Bematech = New-Object System.Windows.Forms.Button
$Elgin = New-Object System.Windows.Forms.Button
$SATTanca = New-Object System.Windows.Forms.Button
$SatControlID = New-Object System.Windows.Forms.Button

#Tabs botoes
$GeralBotao = New-Object System.Windows.Forms.Button
$DownloadlBotao = New-Object System.Windows.Forms.Button
$DriveButton = New-Object System.Windows.Forms.Button
$TabControl = New-Object System.Windows.Forms.TabControl

#Tabs controle
$GeralAba = New-Object System.Windows.Forms.TabPage
$DownloadAba = New-Object System.Windows.Forms.TabPage
$DriveButtonTab = New-Object System.Windows.Forms.TabPage
$TabControl = New-object System.Windows.Forms.TabControl

#----------------------------------------------
#Generated Event Script Blocks
#----------------------------------------------
#Provide Custom Code for events specified in PrimalForms.
$handler_MainMenu_Load =
$OnLoadForm_StateCorrection= {$MainMenu.WindowState = $InitialFormWindowState}

#Botoes Click
$GeralBotao_OnClick = {$TabControl.SelectTab($GeralAba)}
$DownloadlBotao_OnClick = {$TabControl.SelectTab($DownloadAba)}
$DriveButton_Onclick = {$TabControl.SelectTab($DriveButtonTab)}

# == Tab Controle == #
$TabControl.Name = "TabControl"
$TabControl.TabIndex = 99
$TabControl.SelectedIndex = 0
$TabControl.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 105
$System_Drawing_Point.Y = -2
$TabControl.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 195
$System_Drawing_Size.Width = 212
$TabControl.Size = $System_Drawing_Size
$TabSizeMode = New-object System.Windows.Forms.TabSizeMode
$TabSizeMode = "Fixed"
$TabControl.SizeMode =$TabSizeMode
$TabControl.ItemSize = New-Object System.Drawing.Size(0, 1)
$TabAppearance = New-object System.Windows.Forms.TabAppearance
$TabAppearance = "Buttons"
$TabControl.Appearance = $TabAppearance

$MainMenu.Controls.Add($TabControl)

# == Tab Geral == #
$GeralAba.DataBindings.DefaultDataSourceUpdateMode = 0
$GeralAba.Name = "GeralAba"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 4
$System_Drawing_Point.Y = 22
$GeralAba.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 205
$System_Drawing_Size.Width = 445
$GeralAba.Size = $System_Drawing_Size
$GeralAba.TabIndex = 98
$GeralAba.Text = "Geral"
$GeralAba.UseVisualStyleBackColor = $True

$TabControl.Controls.Add($GeralAba)

# == Tab Download == #
$DownloadAba.DataBindings.DefaultDataSourceUpdateMode = 0
$DownloadAba.Name = "DownloadAba"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 4
$System_Drawing_Point.Y = 22
$DownloadAba.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 205
$System_Drawing_Size.Width = 445
$DownloadAba.Size = $System_Drawing_Size
$DownloadAba.TabIndex = 97
$DownloadAba.Text = "Download"
$DownloadAba.UseVisualStyleBackColor = $True

$TabControl.Controls.Add($DownloadAba)

# == Tab Drive == #
$DriveButtonTab.DataBindings.DefaultDataSourceUpdateMode = 0
$DriveButtonTab.Name = "DriveButtonTab"
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 4
$System_Drawing_Point.Y = 22
$DriveButtonTab.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 205
$System_Drawing_Size.Width = 445
$DriveButtonTab.Size = $System_Drawing_Size
$DriveButtonTab.TabIndex = 96
$DriveButtonTab.Text = "Drives"
$DriveButtonTab.UseVisualStyleBackColor = $True

$TabControl.Controls.Add($DriveButtonTab)

# == Panel 1 == #
$panel1.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 0
$System_Drawing_Point.Y = 0
$panel1.Location = $System_Drawing_Point
$panel1.Name = "panel1"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 374
$System_Drawing_Size.Width = 535
$panel1.Size = $System_Drawing_Size
$panel1.TabIndex = 95
$Panel1.BackColor = [System.Drawing.Color]::red

$GeralAba.Controls.Add($panel1)

# == Panel 2 == #
$panel2.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 0
$System_Drawing_Point.Y = 0
$panel2.Location = $System_Drawing_Point
$panel2.Name = "panel2"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 374
$System_Drawing_Size.Width = 535
$panel2.Size = $System_Drawing_Size
$panel2.TabIndex = 94
$Panel2.BackColor = [System.Drawing.Color]::Blue

$DownloadAba.Controls.Add($panel2)

# == Panel 3 == #
$panel3.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 0
$System_Drawing_Point.Y = 0
$panel3.Location = $System_Drawing_Point
$panel3.Name = "panel3"
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 374
$System_Drawing_Size.Width = 535
$panel3.Size = $System_Drawing_Size
$panel3.TabIndex = 94
$panel3.BackColor = [System.Drawing.Color]::green

$DriveButtonTab.Controls.Add($panel3)

# ======== Botoes ==== MENU ======== #

# == Botao Geral == #
$GeralBotao.Name = "GeralBotao"
$GeralBotao.Text = "Geral"
$GeralBotao.TabIndex = 1
$GeralBotao.UseVisualStyleBackColor = $True
$GeralBotao.add_Click($GeralBotao_OnClick)
$GeralBotao.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 2
$GeralBotao.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 35
$System_Drawing_Size.Width = 100
$GeralBotao.Size = $System_Drawing_Size
$GeralBotao.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$MainMenu.Controls.Add($GeralBotao)

# == Botao DownloadÂ´s == #
$DownloadlBotao.Name = "DownloadlBotao"
$DownloadlBotao.Text = "Download"
$DownloadlBotao.TabIndex = 2
$DownloadlBotao.UseVisualStyleBackColor = $True
$DownloadlBotao.add_Click($DownloadlBotao_OnClick)
$DownloadlBotao.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 37
$DownloadlBotao.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 35
$System_Drawing_Size.Width = 100
$DownloadlBotao.Size = $System_Drawing_Size
$DownloadlBotao.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$MainMenu.Controls.Add($DownloadlBotao)

# == Botao DriveÂ´s == #
$DriveButton.Name = "DriveButton"
$DriveButton.Text = "Drives"
$DriveButton.TabIndex = 3
$DriveButton.UseVisualStyleBackColor = $True
$DriveButton.add_Click($DriveButton_OnClick)
$DriveButton.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 72
$DriveButton.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 35
$System_Drawing_Size.Width = 100
$DriveButton.Size = $System_Drawing_Size
$DriveButton.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12,[System.Drawing.FontStyle]([System.Drawing.FontStyle]::Bold))
$MainMenu.Controls.Add($DriveButton)

# ======== Botoes dentro da aba Geral ======== #

# == Programas == #
$Programas.Name = "Programas"
$Programas.Text = "Programas"
$Programas.TabIndex = 4
$Programas.UseVisualStyleBackColor = $True
$Programas.Add_Click({cmd /c appwiz.cpl})
$Programas.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 2
$Programas.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$Programas.Size = $System_Drawing_Size
$Programas.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',10)
$Panel1.Controls.Add($Programas)

# == Firewall == #
$Firewall.Name = "Firewall"
$Firewall.Text = "Firewall"
$Firewall.TabIndex = 5
$Firewall.UseVisualStyleBackColor = $True
$Firewall.Add_Click({cmd /c firewall.cpl})
$Firewall.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 32
$Firewall.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$Firewall.Size = $System_Drawing_Size
$Firewall.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',10)
$Panel1.Controls.Add($Firewall)

# == gestor == #
$gestor.Name = "Gestor"
$gestor.Text = "Gerenciador de dispositivos"
$gestor.TabIndex = 6
$gestor.UseVisualStyleBackColor = $True
$gestor.Add_Click({cmd /c devmgmt.msc})
$gestor.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 62
$gestor.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$gestor.Size = $System_Drawing_Size
$gestor.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',7)
$Panel1.Controls.Add($gestor)

# == Impressoras == #
$Impressoras.Name = "Impressoras"
$Impressoras.Text = "Impressoras"
$Impressoras.TabIndex = 7
$Impressoras.UseVisualStyleBackColor = $True
$Impressoras.Add_Click({cmd /c control printers})
$Impressoras.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 92
$Impressoras.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$Impressoras.Size = $System_Drawing_Size
$Impressoras.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',10)
$Panel1.Controls.Add($Impressoras)

# == pastas == #
$pastas.Name = "pastas"
$pastas.Text = "Pastas"
$pastas.TabIndex = 8
$pastas.UseVisualStyleBackColor = $True
$pastas.Add_Click({cmd /c control folders})
$pastas.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 122
$pastas.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$pastas.Size = $System_Drawing_Size
$pastas.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',10)
$Panel1.Controls.Add($pastas)

# == internet == #
$internet.Name = "internet"
$internet.Text = "Internet"
$internet.TabIndex = 9
$internet.UseVisualStyleBackColor = $True
$internet.Add_Click({cmd /c inetcpl.cpl})
$internet.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 152
$internet.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$internet.Size = $System_Drawing_Size
$internet.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',10)
$Panel1.Controls.Add($internet)

# == sistema == #
$sistema.Name = "Sistema"
$sistema.Text = "Sistema"
$sistema.TabIndex = 10
$sistema.UseVisualStyleBackColor = $True
$sistema.Add_Click({cmd /c sysdm.cpl})
$sistema.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 102
$System_Drawing_Point.Y = 2
$sistema.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$sistema.Size = $System_Drawing_Size
$sistema.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',10)
$Panel1.Controls.Add($sistema)

# == Adaptador de Rede == #
$ncpa.Name = "Adaptador de Rede"
$ncpa.Text = "Adaptador de Rede"
$ncpa.TabIndex = 11
$ncpa.UseVisualStyleBackColor = $True
$ncpa.Add_Click({cmd /c ncpa.cpl})
$ncpa.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 102
$System_Drawing_Point.Y = 32
$ncpa.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$ncpa.Size = $System_Drawing_Size
$ncpa.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',7)
$Panel1.Controls.Add($ncpa)

# == oldcontrolpanel == #
$oldcontrolpanel.Name = "Painel de Controle"
$oldcontrolpanel.Text = "Painel de Controle"
$oldcontrolpanel.TabIndex = 12
$oldcontrolpanel.UseVisualStyleBackColor = $True
$oldcontrolpanel.Add_Click({cmd /c control})
$oldcontrolpanel.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 102
$System_Drawing_Point.Y = 62
$oldcontrolpanel.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$oldcontrolpanel.Size = $System_Drawing_Size
$oldcontrolpanel.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',7)
$Panel1.Controls.Add($oldcontrolpanel)

# == oldpower == #
$oldpower.Name = "Opcoes de Energia"
$oldpower.Text = "Opcoes de Energia"
$oldpower.TabIndex = 13
$oldpower.UseVisualStyleBackColor = $True
$oldpower.Add_Click({cmd /c powercfg.cpl})
$oldpower.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 102
$System_Drawing_Point.Y = 92
$oldpower.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$oldpower.Size = $System_Drawing_Size
$oldpower.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',7)
$Panel1.Controls.Add($oldpower)

# == temp == #
$temp.Name = "Limpeza Temp"
$temp.Text = "Limpeza Temp"
$temp.TabIndex = 14
$temp.UseVisualStyleBackColor = $True
$temp.Add_Click({Write-Host "Realizando Download"
                 Start-BitsTransfer -Source https://raw.githubusercontent.com/ThiMnano/nano/main/limpeza_temps.bat -Destination C:\Nano\limpeza_temps.bat
                 Start-Process "cmd.exe"  "/c C:\Nano\limpeza_temps.bat"
                 Write-Host "Limpando Arquivos temporarios"
                })
$temp.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 102
$System_Drawing_Point.Y = 122
$temp.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$temp.Size = $System_Drawing_Size
$temp.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',8)
$Panel1.Controls.Add($temp)

# == clean == #
$clean.Name = "Limpeza Disco"
$clean.Text = "Limpeza Disco"
$clean.TabIndex = 15
$clean.UseVisualStyleBackColor = $True
$clean.Add_Click({cmd /c cleanmgr.exe})
$clean.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 102
$System_Drawing_Point.Y = 152
$clean.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$clean.Size = $System_Drawing_Size
$clean.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',8)
$Panel1.Controls.Add($clean)

# ======== Botoes dentro da aba Download ======== #

# == nano == #
$nano.Name = "nano"
$nano.Text = "Nano"
$nano.TabIndex = 16
$nano.UseVisualStyleBackColor = $True
$nano.Add_Click({Start-Process "https://www.dropbox.com/s/1yqtnsagjzx16sk/Debug.rar?dl=1"})
$nano.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 2
$nano.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$nano.Size = $System_Drawing_Size
$nano.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12)
$Panel2.Controls.Add($nano)

# == NFE == #
$NFE.Name = "NF-E"
$NFE.Text = "NF-E"
$NFE.TabIndex = 17
$NFE.UseVisualStyleBackColor = $True
$NFE.Add_Click({Start-Process "https://www.dropbox.com/s/ntqx107lqxrc3fl/NANONFe.rar?dl=1"})
$NFE.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 32
$NFE.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$NFE.Size = $System_Drawing_Size
$NFE.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12)
$Panel2.Controls.Add($NFE)

# == NFSE == #
$NFSE.Name = "NFS-E"
$NFSE.Text = "NFS-E"
$NFSE.TabIndex = 18
$NFSE.UseVisualStyleBackColor = $True
$NFSE.Add_Click({Start-Process "https://www.dropbox.com/s/tv96cbx4s5f2z69/NANONFSe.zip?dl=1"})
$NFSE.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 62
$NFSE.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$NFSE.Size = $System_Drawing_Size
$NFSE.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12)
$Panel2.Controls.Add($NFSE)

# == NFCE == #
$NFCE.Name = "NFC-E"
$NFCE.Text = "NFC-E"
$NFCE.TabIndex = 19
$NFCE.UseVisualStyleBackColor = $True
$NFCE.Add_Click({Start-Process "https://www.dropbox.com/s/hx9o0emp7c4dk5j/NANONFCe.rar?dl=1"})
$NFCE.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 92
$NFCE.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$NFCE.Size = $System_Drawing_Size
$NFCE.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12)
$Panel2.Controls.Add($NFCE)

# == Boleto == #
$Boleto.Name = "Boleto"
$Boleto.Text = "Boleto"
$Boleto.TabIndex = 20
$Boleto.UseVisualStyleBackColor = $True
$Boleto.Add_Click({Start-Process "https://www.dropbox.com/s/7xq58imdofkepx2/NANOBoleto.rar?dl=1"})
$Boleto.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 122
$Boleto.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$Boleto.Size = $System_Drawing_Size
$Boleto.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12)
$Panel2.Controls.Add($Boleto)

# == nanorar == #
$nanorar.Name = "Nano.rar"
$nanorar.Text = "Nano.rar"
$nanorar.TabIndex = 21
$nanorar.UseVisualStyleBackColor = $True
$nanorar.Add_Click({Start-Process "https://www.dropbox.com/s/y122n3n2ot5qw8y/NANO.rar?dl=1"})
$nanorar.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 152
$nanorar.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$nanorar.Size = $System_Drawing_Size
$nanorar.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12)
$Panel2.Controls.Add($nanorar)

# == setupnano == #
$setupnano.Name = "Nano Instalador"
$setupnano.Text = "Nano Instalador"
$setupnano.TabIndex = 22
$setupnano.UseVisualStyleBackColor = $True
$setupnano.Add_Click({Start-Process "https://www.dropbox.com/s/63fzce1uxysm99l/Nano%20Instalador.exe?dl=1"})
$setupnano.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 102
$System_Drawing_Point.Y = 2
$setupnano.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$setupnano.Size = $System_Drawing_Size
$setupnano.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',9)
$Panel2.Controls.Add($setupnano)

# == crytal == #
$crytal.Name = "Crystal"
$crytal.Text = "Crystal"
$crytal.TabIndex = 23
$crytal.UseVisualStyleBackColor = $True
$crytal.Add_Click({Start-Process "https://www.dropbox.com/s/f0iq5hsk6thyrtz/CRRuntime_32bit_13_0_18.msi?dl=1"})
$crytal.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 102
$System_Drawing_Point.Y = 32
$crytal.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$crytal.Size = $System_Drawing_Size
$crytal.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12)
$Panel2.Controls.Add($crytal)

# == sql == #
$sql.Name = "SQL"
$sql.Text = "SQL"
$sql.TabIndex = 24
$sql.UseVisualStyleBackColor = $True
$sql.Add_Click({Start-Process "https://www.dropbox.com/s/ty5ji3b5rl5o1ns/Programas.rar?dl=1"})
$sql.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 102
$System_Drawing_Point.Y = 62
$sql.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$sql.Size = $System_Drawing_Size
$sql.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12)
$Panel2.Controls.Add($sql)

# == Winrar == #
$winrar.Name = "Winrar"
$winrar.Text = "Winrar"
$winrar.TabIndex = 25
$winrar.UseVisualStyleBackColor = $True
$winrar.Add_Click({Start-Process "https://www.win-rar.com/download.html?&L=9"})
$winrar.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 102
$System_Drawing_Point.Y = 92
$winrar.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$winrar.Size = $System_Drawing_Size
$winrar.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12)
$Panel2.Controls.Add($winrar)

# == Bartender64 == #
$Bartender64.Name = "Bartender64"
$Bartender64.Text = "Bartender64"
$Bartender64.TabIndex = 26
$Bartender64.UseVisualStyleBackColor = $True
$Bartender64.Add_Click({Start-Process "https://www.dropbox.com/s/hvhqp6qulk412ke/Bartender.rar?dl=1"})
$Bartender64.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 102
$System_Drawing_Point.Y = 122
$Bartender64.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$Bartender64.Size = $System_Drawing_Size
$Bartender64.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',11)
$Panel2.Controls.Add($Bartender64)

# == Bartender64 == #
$Bartender32.Name = "Bartender32"
$Bartender32.Text = "Bartender32"
$Bartender32.TabIndex = 27
$Bartender32.UseVisualStyleBackColor = $True
$Bartender32.Add_Click({Start-Process "https://www.dropbox.com/s/hvhqp6qulk412ke/Bartender.rar?dl=1"})
$Bartender32.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 102
$System_Drawing_Point.Y = 152
$Bartender32.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$Bartender32.Size = $System_Drawing_Size
$Bartender32.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',11)
$Panel2.Controls.Add($Bartender32)

# == DieBold == #
$DieBold.Name = "DieBold"
$DieBold.Text = "DieBold"
$DieBold.TabIndex = 28
$DieBold.UseVisualStyleBackColor = $True
$DieBold.Add_Click({Start-Process "https://dieboldnixdorf.com.br/suporte-dn/material-para-downloads/"})
$DieBold.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 2
$DieBold.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$DieBold.Size = $System_Drawing_Size
$DieBold.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12)
$Panel3.Controls.Add($DieBold)

# == Bematech == #
$Bematech.Name = "Bematech"
$Bematech.Text = "Bematech"
$Bematech.TabIndex = 29
$Bematech.UseVisualStyleBackColor = $True
$Bematech.Add_Click({Start-Process "https://g2sistema.com.br/downloads/"})
$Bematech.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 32
$Bematech.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$Bematech.Size = $System_Drawing_Size
$Bematech.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12)
$Panel3.Controls.Add($Bematech)

# == Elgin == #
$Elgin.Name = "Elgin"
$Elgin.Text = "Elgin"
$Elgin.TabIndex = 30
$Elgin.UseVisualStyleBackColor = $True
$Elgin.Add_Click({Start-Process "https://www.bztech.com.br/downloads/driver-elgin-i7-i8-e-i9-windows-e-linux"})
$Elgin.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 62
$Elgin.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$Elgin.Size = $System_Drawing_Size
$Elgin.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12)
$Panel3.Controls.Add($Elgin)
 
# == SAT Tanca == #
$SATTanca.Name = "SAT Tanca"
$SATTanca.Text = "SAT Tanca"
$SATTanca.TabIndex = 31
$SATTanca.UseVisualStyleBackColor = $True
$SATTanca.Add_Click({Start-Process "https://www.tanca.com.br/drivers.php?cat=24&sub=43"})
$SATTanca.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 92
$SATTanca.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$SATTanca.Size = $System_Drawing_Size
$SATTanca.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',12)
$Panel3.Controls.Add($SATTanca)

# == SAT Tanca == #
$SatControlID.Name = "Sat Control ID"
$SatControlID.Text = "Sat Control ID"
$SatControlID.TabIndex = 32
$SatControlID.UseVisualStyleBackColor = $True
$SatControlID.Add_Click({Start-Process "https://www.controlid.com.br/contato-suporte/"})
$SatControlID.DataBindings.DefaultDataSourceUpdateMode = 0
$System_Drawing_Point = New-Object System.Drawing.Point
$System_Drawing_Point.X = 2
$System_Drawing_Point.Y = 122
$SatControlID.Location = $System_Drawing_Point
$System_Drawing_Size = New-Object System.Drawing.Size
$System_Drawing_Size.Height = 30
$System_Drawing_Size.Width = 100
$SatControlID.Size = $System_Drawing_Size
$SatControlID.Font = New-Object System.Drawing.Font('Microsoft Sans Serif',9)
$Panel3.Controls.Add($SatControlID)

[void]$MainMenu.ShowDialog()
