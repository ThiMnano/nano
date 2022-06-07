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
$iconBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAFEAAAAcCAYAAAAZSVOEAAAABGdBTUEAALGPC/xhBQAAAAlwSFlzAAAOxAAADsQBlSsOGwAAAAZiS0dEAP8A/wD/oL2nkwAAAAd0SU1FB+YGBg4THa6V+AIAAAepSURBVGhD7ZlZbE1dFMdXVc1zY55iiCLUrGaJMTGEiAdJCQ/VeGiQhkgkSBBCPEhEJISYQmgNNc9SNVepKlLUPM8zreH7vt9ytp6e3nvuua18+tB/cnJv9z1777X/a94N+ec/SAmKhFLWZwmKgBIS/wD+ujsHu31ISIj1zT9Yk8f+rpd5TjhlM2s61yoUiZ8+fZIrV67Ijx8/pHXr1lKtWrWghfz586c8ffpUsrKyJDc3V+d7EaVMmTLSrFkzqVevnpQuXdoazQMyPXv2TF69eiUvX778vXaNGjWkefPmUrVqVU+yfvjwQa5duybv3r1TucqXLy/Vq1eX8PBwqV27toSGhlpvFsKdv3//LseOHZNOnTpJVFSUrF27VnJycqxfvYPDnTlzRhWCwK9fv9aDm8Pfu3dPyXCOX79+XcaPH++XcMYPHjwoI0aMkAMHDsjDhw/l/v37snr1aklISLDeCoyTJ08qUSj58ePHes7hw4fLypUr8xEIgrbE27dv62FatWolFy5ckPnz58u6deukQYMG1hveAPEcjM/4+HhrNA+zZs2SvXv3ysWLF60RkYoVK8rEiRPl8OHDune5cuWsX/LAcd6/f6/zxo0bp2QyD+s7f/687NixQz3HDW/fvpU9e/boWpcvX9YnIyNDtm7dKl26dNF9S5XKs7+gLRE37tq1q5r1kSNHZODAgbJr1y7r1+BQtmxZOXv2rPTu3Vst5vnz52qBKAb3w51SUlLUIrGGqVOnypMnT9SN/bkk47hs3759Zd68edKwYUMJCwuTypUrq8IyMzOtN/3jxo0b6rLIUqlSJfn69avExsbqmhUqVMhHIAiKxDdv3mhsyM7Olm/fvulY9+7dZd++far9YICWsZDjx4/LzJkzpX79+lKzZk2NdSbGImydOnWkVq1aUrduXRk7dqySSFwM5EDmoBB46tQpVTThB68hbvoD4QoXRsFz587VcGJk8YegSExLS5NBgwbJtGnTZNKkSWrWBF6040XDdmBNxMWPHz9Kr169rNFfCcdOkP1748aNpW3btvL582clJxCYS/x68OCB/l2lShW5dOmSJjR/wOJJIFu2bFFDadKkia7jpjTPJGLSxAqwc+dOmTx5skRERCixuLTZ1CvQLGGB2IXWDdwE5r0ZM2bI+vXrrRFvwLpIhCQY3PTQoUOqLF/AGPCGNWvWSHR0tLqzm+UCzyQSJzg02YmyhjID90CrjRo1kqtXr7pq2AlIbNmypT5erAowhxjXsWPHAhnSDRhAjx491DU5w6ZNm7QqcIKQRMgiFjNnyJAhavWB4IlENAlJkEUmxZ2JS2gVF7t165ZERkZqbCyOwJKQFRlfvHihxJBtnbh586aeZ/HixRIXF6exOZAVAk8kEsyJDWQrNDhs2DAdJyb26dNHM3bnzp21LvOl4b8NwgOyDh48WJMiZG7btk2NwwCyMAa8gvMQ8/n+x0gk7nXr1k2LXOouYh+uwUOpQ7FMjCFJoM3iBkgkw7Zp00atiyogOTlZrdKAMgrSNmzYoCS3aNFCx90SikFAEsm+LM4nFoiGqOfIeDxYHqZPS0W9R0C2a7g4gezcv39/VTTNwf79+61fftW/hKvly5fL9OnTPcdpEJBEsicum5qaqu587tw5SUpKUndITEzU72RrKnySDcJAcnEDFkVigkTkwyq3b9+uCeTLly/qVSRPMHToUP30YoXAlUQ2oGel2h81apScPn1aA3J6erqSRTlAwkGzq1atUsukKKa39irA/wUjD+WLqTWpJoiDtLKML1myRD2Njge4Fdh2uL5FEKacoFcl7u3evVutj4dmnsd8p0FHk3QwjBW3BGNIpNakroU4kiFyYxB0TxTiMTExv8krsiWSKFi8adOmsnDhQhk9erSWCQRoajQ6Dh425O/27durWxBLKMppnQoL9jCwfw8WdhLsVgV5/Ib10Q5ilSieSxWeYOGXRC4ECLS4Kv0tycOtwCXjYYXceHTo0EE2btzoWZN2MMdYMW0hT2FBecJ6fNo7FC43BgwYoJ5GbKSoXrRokcyZMyffzZCvub5QgEQmENu49qHKP3r0qMY5tEWM9EUMY8ROShyuirgwQEDaK8KArzlOsLaZg6WQSSmnuOXhDhEr97IO77AWcRuZKMFoT7m7xDsoz/AWbmQePXokPXv21A4G9OvXTy2WvfBC9oZkzn/nzh01KF+VR4H7xLt372rcYCKZmEQCmQhz4sQJGTlypHYrdlCMYz2UOSQfiKeEoEBn4zFjxmhy8gcTOmi3OCT7cpdIgEcpXHAQVqZMmRLQvZkP6XQekLV06VINO/TO/E1tyBkgmvVwaWpDLlZWrFih41Qh3B6hSMZoBdu1a6dnYH3IZk2DAiRyizFhwgR9GYEhDPbREBayYMEC68084HI061zWMgclmGUhAk27hQLexXI2b96sVsCexq1Ym70JFVhmIBJZi8teLkSYy9UdczgDB0cpXHEBlDV79mzda9myZRq+ABfCWCH3j8xnf9yaTwyCpsMuRwESTZvDpk6BEYIx53igOQAB3GDEcIjzG7729QcTx5xrMR857LKYeMcYvzOHMXMmA8Z5B2NwylKof1SVID/czaMEnlBCYpEh8i+N1beEZCh5NwAAAABJRU5ErkJggg=='
$iconBytes                           = [Convert]::FromBase64String($iconBase64)
$stream                              = New-Object IO.MemoryStream($iconBytes, 0, $iconBytes.Length)
$stream.Write($iconBytes, 0, $iconBytes.Length)
$MainMenu.Icon                       = [System.Drawing.Icon]::FromHandle((New-Object System.Drawing.Bitmap -Argument $stream).GetHIcon())
$MainMenu.Width                      = $objImage.Width
$MainMenu.Height                     = $objImage.Height

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

#Botoes
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
$DriveButtonTab.Text = "Drive´s"
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

#$Panel1.controls.AddRange(@($Programas,$Firewall,$gestor,$Impressoras,$pastas,$internet,$sistema,$ncpa,$oldcontrolpanel,$oldpower,$temp,$clean))
#$Panel2.controls.Addrange(@($nano,$NFE,$NFSE,$NFCE,$Boleto,$nanorar,$setupnano,$crytal,$sql,$winrar))

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

# == Botao Download´s == #
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

# == Botao Drive´s == #
$DriveButton.Name = "DriveButton"
$DriveButton.Text = "Drive´s"
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
$internet.Text = "internet"
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
$oldpower.Name = "Opções de Energia"
$oldpower.Text = "Opções de Energia"
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
$temp.Add_Click({
    Write-Host "Limpando Arquivos temporarios" 
    Import-Module BitsTransfer 
    Start-BitsTransfer -Source https://raw.githubusercontent.com/ThiMnano/nano/main/limpeza_temps.bat -Destination C:\Users\%USERNAME%\AppData\Local\limpeza_temps.bat 
    Start-Process "cmd.exe"  "/c C:\Users\%USERNAME%\AppData\Local\Limpeza\limpeza_temps.bat"
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

# == sql == #
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

[void]$MainMenu.ShowDialog()