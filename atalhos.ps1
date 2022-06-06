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

$Form                            = New-Object system.Windows.Forms.Form
$Form.ClientSize                 = New-Object System.Drawing.Point(1050,1000)
$Form.text                       = "Atalhos por Thiago Martins"
$Form.StartPosition              = "CenterScreen"
$Form.TopMost                    = $false
$Form.BackColor                  = [System.Drawing.ColorTranslator]::FromHtml("#e9e9e9")
$Form.AutoScaleDimensions        = '192, 192'
$Form.AutoScaleMode              = "Dpi"
$Form.AutoSize                   = $True
$Form.AutoScroll                 = $True
$Form.ClientSize                 = '1050, 1000'
$Form.FormBorderStyle            = 'FixedSingle'

# GUI Icon
$iconBase64                      = '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'
$iconBytes                       = [Convert]::FromBase64String($iconBase64)
$stream                          = New-Object IO.MemoryStream($iconBytes, 0, $iconBytes.Length)
$stream.Write($iconBytes, 0, $iconBytes.Length)
$Form.Icon                       = [System.Drawing.Icon]::FromHandle((New-Object System.Drawing.Bitmap -Argument $stream).GetHIcon())

$Form.Width                      = $objImage.Width
$Form.Height                     = $objImage.Height

$Panel1                          = New-Object system.Windows.Forms.Panel
$Panel1.height                   = 178
$Panel1.width                    = 463
$Panel1.location                 = New-Object System.Drawing.Point(2,2)

$Programas                       = New-Object system.Windows.Forms.Button
$Programas.text                  = "Remover Programas"
$Programas.width                 = 212
$Programas.height                = 30
$Programas.location              = New-Object System.Drawing.Point(2,2)
$Programas.Font                  = New-Object System.Drawing.Font('Microsoft Sans Serif',12)

$Firewall                        = New-Object system.Windows.Forms.Button
$Firewall.text                   = "Firewall do Windows"
$Firewall.width                  = 212
$Firewall.height                 = 30
$Firewall.location               = New-Object System.Drawing.Point(2,37)
$Firewall.Font                   = New-Object System.Drawing.Font('Microsoft Sans Serif',12)

$gestor                          = New-Object system.Windows.Forms.Button
$gestor.text                     = "Gestor de dispositivos"
$gestor.width                    = 211
$gestor.height                   = 30
$gestor.location                 = New-Object System.Drawing.Point(2,72)
$gestor.Font                     = New-Object System.Drawing.Font('Microsoft Sans Serif',12)

$Impressoras                     = New-Object system.Windows.Forms.Button
$Impressoras.text                = "Impressoras"
$Impressoras.width               = 212
$Impressoras.height              = 30
$Impressoras.location            = New-Object System.Drawing.Point(2,107)
$Impressoras.Font                = New-Object System.Drawing.Font('Microsoft Sans Serif',12)

$pastas             		 = New-Object system.Windows.Forms.Button
$pastas.text          		 = "Opcoes de pastas"
$pastas.width       	         = 212
$pastas.height     		 = 30
$pastas.location    	         = New-Object System.Drawing.Point(2,142)
$pastas.Font        	         = New-Object System.Drawing.Font('Microsoft Sans Serif',12)

$internet                        = New-Object system.Windows.Forms.Button
$internet.text                   = "Propriedades da internet"
$internet.width                  = 212
$internet.height                 = 30
$internet.location               = New-Object System.Drawing.Point(2,177)
$internet.Font                   = New-Object System.Drawing.Font('Microsoft Sans Serif',12)

$sistema                         = New-Object system.Windows.Forms.Button
$sistema.text                    = "Propriedades do sistema"
$sistema.width                   = 212
$sistema.height                  = 30
$sistema.location                = New-Object System.Drawing.Point(247,2)
$sistema.Font                    = New-Object System.Drawing.Font('Microsoft Sans Serif',12)

$ncpa                            = New-Object system.Windows.Forms.Button
$ncpa.text                       = "Adaptadores de Rede"
$ncpa.width                      = 211
$ncpa.height                     = 30
$ncpa.location                   = New-Object System.Drawing.Point(247,37)
$ncpa.Font                       = New-Object System.Drawing.Font('Microsoft Sans Serif',12)

$oldcontrolpanel                 = New-Object system.Windows.Forms.Button
$oldcontrolpanel.text            = "Painel de Controle"
$oldcontrolpanel.width           = 211
$oldcontrolpanel.height          = 30
$oldcontrolpanel.location        = New-Object System.Drawing.Point(247,72)
$oldcontrolpanel.Font            = New-Object System.Drawing.Font('Microsoft Sans Serif',12)

$temp      			 = New-Object system.Windows.Forms.Button
$temp.text    			 = "Limpeza de Temp's"
$temp.width		         = 211
$temp.height   			 = 30
$temp.location   		 = New-Object System.Drawing.Point(247,107)
$temp.Font         		 = New-Object System.Drawing.Font('Microsoft Sans Serif',12)

$oldpower                        = New-Object system.Windows.Forms.Button
$oldpower.text                   = "Plano de Energia"
$oldpower.width                  = 211
$oldpower.height                 = 30
$oldpower.location               = New-Object System.Drawing.Point(4,142)
$oldpower.Font                   = New-Object System.Drawing.Font('Microsoft Sans Serif',12)

$clean                           = New-Object system.Windows.Forms.Button
$clean.text                      = "Limpeza de Disco"
$clean.width                     = 211
$clean.height                    = 30
$clean.location                  = New-Object System.Drawing.Point(247,142)
$clean.Font                      = New-Object System.Drawing.Font('Microsoft Sans Serif',12)


$Form.controls.AddRange(@($Panel1))
$Panel1.controls.AddRange(@($Programas,$Firewall,$gestor,$Impressoras,$pastas,$internet,$sistema,$ncpa,$oldcontrolpanel,$temp,$oldpower,$clean))

$Programas.Add_Click({
	cmd /c appwiz.cpl
})

$Firewall.Add_Click({
	cmd /c firewall.cpl
})

$gestor.Add_Click({
	cmd /c devmgmt.msc
})

$Impressoras.Add_Click({
	cmd /c control printers
})

$pastas.Add_Click({
	cmd /c control folders
})

$internet.Add_Click({
	cmd /c inetcpl.cpl
})

$sistema.Add_Click({
	cmd /c sysdm.cpl
})

$ncpa.Add_Click({
    cmd /c ncpa.cpl
})

$oldcontrolpanel.Add_Click({
    cmd /c control
})

$oldpower.Add_Click({
    cmd /c powercfg.cpl
})

$temp.Add_Click({
    Write-Host "Limpando Arquivos temporarios"
    Import-Module BitsTransfer
    Start-BitsTransfer -Source https://raw.githubusercontent.com/ThiMnano/nano/main/limpeza_temps.bat -Destination C:\Windows\Temp\limpeza_temps.bat
    Start-Process "cmd.exe"  "/c C:\Windows\Temp\limpeza_temps.bat"
})

$clean.Add_Click({
    cmd /c cleanmgr.exe
})

[void]$Form.ShowDialog()
