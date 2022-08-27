Param(
	[String]$CodeName="",
	[String]$Folder=".\output",
	[String]$Certificate="",
	[String]$Password="",
	[Switch]$Force
)

Add-Type -Assembly System.Windows.Forms
Set-StrictMode -Version 2.0
$ErrorActionPreference="Stop"

[System.Windows.Forms.Form]$Global:MainWindow=$Null
[System.Windows.Forms.RichTextBox]$Global:LogTextBox=$Null
[System.Collections.ArrayList]$Global:Items=[System.Collections.ArrayList]::new()
[String]$Global:Base=Split-Path -Parent $MyInvocation.MyCommand.Definition
[PSCustomObject]$Global:I18NString=$Null

[PSCustomObject[]]$Global:I18NStrings=@(
	[PSCustomObject]@{
		Locale="zh-CN"
		OutExists="输出文件夹{0}已存在"
		RemoveOldDrivers="正在清理旧的驱动..."
		CleanUpFailed="清理失败: {0}"
		CopyDrivers="正在复制驱动..."
		CopyDriversFailed="复制驱动失败: {0}"
		RenameDrivers="正在重命名驱动..."
		RenamedDrivers="已重命名{0}个驱动"
		RenameDriversFailed="重命名驱动失败: {0}"
		SignDriversWith="正在使用证书{0}签名驱动..."
		CertNotFound="证书未找到"
		SignedDrivers="已签名{0}个驱动"
		SignDriversFailed="签名驱动失败: {0}"
		DefNotFound="你的设备没有驱动定义文件，请检查"
		ConfigOn="目标设备配置: {0}"
		DestOn="目标文件夹: {0}"
		Done="完成"
		ExtractDriversFailed="驱动释放失败: {0}"
		DeviceListItem="{0} ({1})"
		WindowTitle="WOA-Drivers驱动释放器"
		LabelTitle="选择设备:"
		LabelCodeName="设备代号:"
		LabelDeviceName="设备名称:"
		LabelDestination="目标目录: "
		LabelCertificate="证书路径: "
		LabelPassword="证书密码: "
		CheckSign="签名所有驱动"
		CheckForce="覆盖目标文件夹"
		ButtonReload="刷新"
		ButtonCancel="取消"
		ButtonStart="开始"
		ButtonStartExtracting="正在释放..."
		DialogDestination="选择输出文件夹"
		DialogCertificate="选择用于签名驱动的证书"
		DialogCertificateFilter="PFX证书 (*.pfx)|*.pfx|全部文件 (*.*)|*.*"
		ExtractFailed="驱动释放失败"
	},[PSCustomObject]@{
		Locale=""
		OutExists="output folder {0} exists"
		RemoveOldDrivers="removing old drivers..."
		CleanUpFailed="cleanup failed: {0}"
		CopyDrivers="copying drivers..."
		CopyDriversFailed="copy drivers failed: {0}"
		RenameDrivers="rename drivers..."
		RenamedDrivers="{0} drivers renamed"
		RenameDriversFailed="rename drivers failed: {0}"
		SignDriversWith="signing drivers with {0}..."
		WindowTitle="WOA-Driver Extractor"
		CertNotFound="certificate not found"
		SignedDrivers="{0} drivers signed"
		SignDriversFailed="sign drivers failed: {0}"
		DefNotFound="your model has no definition file, please check"
		ConfigOn="target device config: {0}"
		DestOn="destination: {0}"
		Done="done"
		ExtractDriversFailed="extract drivers failed: {0}"
		DeviceListItem="{0} ({1})"
		LabelDevice="Device:"
		LabelCodeName="Code Name:"
		LabelDeviceName="Device Name:"
		LabelDestination="Destination: "
		LabelCertificate="Certificate: "
		LabelPassword="Cert Password: "
		CheckSign="Sign all drivers"
		CheckForce="Overwrite destination folder"
		ButtonReload="Reload"
		ButtonCancel="Cancel"
		ButtonStart="Start"
		ButtonStartExtracting="Extracting..."
		DialogDestination="Select output folder"
		DialogCertificate="Select certificate to sign drivers"
		DialogCertificateFilter="PFX Certificate (*.pfx)|*.pfx|All files (*.*)|*.*"
		ExtractFailed="driver extract failed"
	}
)
Function InitializeI18N(){
	$Locale=(Get-WinSystemLocale).Name
	ForEach($Strings in $Global:I18NStrings){
		If( `
			$Strings.Locale -eq "" -or `
			$Strings.Locale -eq $Locale `
		){
			$Global:I18NString=$Strings
			Break
		}
	}
	If(-Not $Global:I18NString){
		Write-Error "unexpect locale error"
		Exit 1
	}
}

Function PrintColorLine($Color,$Message){
	If($Message -eq ""){
		Return
	}
	Write-Host -ForegroundColor $Color -Object $Message
	If($Global:LogTextBox){
		$Global:LogTextBox.SelectionColor=$Color
		$Global:LogTextBox.AppendText($Message+"`n")
		$Global:LogTextBox.SelectionStart=$Global:LogTextBox.TextLength
		$Global:LogTextBox.ScrollToCaret()
		$Global:MainWindow.Update()
	}
}
Function PrintLog($Level="INFO",$Message){
	Switch($Level){
		"DEBUG"{$Color="Gray"}
		"INFO"{$Color="Green"}
		"WARN"{$Color="Yellow"}
		"ERROR"{$Color="Red"}
		Default{$Color="White"}
	}
	If($Message.GetType().BaseType.Name -eq "Array"){
		ForEach($Line in $Message){
			PrintColorLine $Color $Line
		}
	}Else{
		PrintColorLine $Color $Message
	}
}

Function CleanUP(
	[String]$Destination,
	[Boolean]$Force=$False
){
	If(-not (Test-Path -Path $Destination)){
		Return $True
	}
	If($Folder -ne ".\output" -and $Force -eq $False){
		PrintLog "ERROR" ($Global:I18NString.OutExists -f $Destination)
		Return $False
	}
	Try{
		PrintLog "INFO" $Global:I18NString.RemoveOldDrivers
		Remove-Item `
			-Recurse `
			-Force `
			-Path $Destination
	}Catch{
		PrintLog "ERROR" ($Global:I18NString.CleanUpFailed -f $_.Exception)
		Return $False
	}
	Return $True
}

Function CopyDrivers(
	[String]$Config,
	[String]$Destination
){
	Try{
		PrintLog "INFO" $Global:I18NString.CopyDrivers
		Get-Content `
			-Path $Config | `
		Copy-Item `
			-Force `
			-Recurse `
			-Path { Join-Path -Path $Global:Base -ChildPath $_ } `
			-Destination $Destination
		Copy-Item `
			-Force `
			-Recurse `
			-Path (Join-Path -Path $Global:Base -ChildPath "root-ca.crt") `
			-Destination $Destination
	}Catch{
		PrintLog "ERROR" ($Global:I18NString.CopyDriversFailed -f $_.Exception)
		Return $False
	}
	Return $True
}


Function RenameDrivers(
	[String]$Destination
){
	Try{
		PrintLog "INFO" $Global:I18NString.RenameDrivers
		$drivers=Get-ChildItem `
			-Recurse `
			-Path $Destination `
			-Filter *.inf_
		$drivers|Rename-Item -NewName { `
			$_.FullName `
			-Replace '\.inf_','.inf' `
		}
		PrintLog "INFO" ($Global:I18NString.RenamedDrivers -f $drivers.Count)
	}Catch{
		PrintLog "ERROR" ($Global:I18NString.RenameDriversFailed -f $_.Exception)
		Return $False
	}
	Return $True
}

Function SignDrivers(
	[String]$Certificate,
	[String]$Password="",
	[String]$Destination
){
	If($Certificate -eq ""){
		Return $True
	}
	Try{
		PrintLog "INFO" ($Global:I18NString.SignDriversWith -f $Certificate)
		If(-not (Test-Path -Path $Certificate)){
			PrintLog "ERROR" $Global:I18NString.CertNotFound
			Return $False
		}
		$cmd=@()
		$exe=(Resolve-Path -Path ".\tools\signtool.exe").Path
		$cmd+="sign"
		$cmd+="/fd";
		$cmd+="SHA256"
		$cmd+="/f";
		$cmd+=$Certificate
		If($Password -ne ""){
			$cmd+="/p";
			$cmd+=$Password
		}
		$drivers=Get-ChildItem `
			-Recurse `
			-Path $Destination `
			-Filter '*.sys'
		$i=0
		ForEach($driver in $drivers){
			$i++
			$out=&$exe $cmd $driver.FullName 2>&1
			PrintLog "DEBUG" $out
			PrintLog "INFO" ("{0}/{1}" -f $i,$drivers.Count)
		}
		PrintLog "INFO" ($Global:I18NString.SignedDrivers -f $drivers.Count)
	}Catch{
		PrintLog "ERROR" ($Global:I18NString.SignDriversFailed -f $_)
		Return $False
	}
	Return $True
}

Function ExtractDrivers(
	[String]$CodeName,
	[String]$Folder="output",
	[String]$Certificate="",
	[String]$Password="",
	[Boolean]$Force=$False
){
	$Configs=Join-Path `
		-Path $Global:Base `
		-ChildPath "definitions"
	$Config=Join-Path `
		-Path $Configs `
		-ChildPath (-Join ($CodeName,".txt"))
	If(-not (Test-Path -Path $Config)){
		PrintLog "ERROR" $Global:I18NString.DefNotFound
		Return $False
	}
	Try{
		If(-not (CleanUP `
			-Force $Force `
			-Destination $Folder `
		)){
			Return $False
		}
		If(-not (Test-Path `
			-Path $Folder `
		)){
			New-Item `
				-ItemType Directory `
				-Path $Folder >$Null
		}
		$Destination=(Resolve-Path -Path $Folder).Path
		PrintLog "INFO" ($Global:I18NString.ConfigOn -f $Config)
		PrintLog "INFO" ($Global:I18NString.DestOn -f $Destination)
		If(-not (CopyDrivers `
			-Config $Config `
			-Destination $Destination `
		)){
			Return $False
		}
		If(-not (RenameDrivers `
			-Destination $Destination `
		)){
			Return $False
		}
		If($Certificate -ne ""){
			If(-not (SignDrivers `
				-Certificate $Certificate `
				-Password $Password `
				-Destination $Destination `
			)){
				Return $False
			}
		}
		PrintLog "INFO" $Global:I18NString.Done
		If($Global:MainWindow){
			&explorer.exe "/select,$Destination"
		}
	}Catch{
		PrintLog "ERROR" ($Global:I18NString.ExtractDriversFailed -f $_.Exception)
		Return $False
	}
	Return $True
}

Function ReloadList([System.Windows.Forms.ListBox]$ListBox){
	$ListBox.BeginUpdate()
	$ListBox.Items.Clear()
	$Configs=Join-Path `
		-Path $Global:Base `
		-ChildPath "definitions"
	$List=Join-Path `
		-Path $Configs `
		-ChildPath "devices.lst"
	$Devices=(Import-Csv -Path $List)
	ForEach($Device in (Get-ChildItem `
		-Path $Configs `
		-Filter '*.txt'`
	)){
		[String]$Code=$Device.Name -Replace '\.txt',''
		[String]$Name=$Code
		[String]$Title=$Code
		ForEach($Line in $Devices){
			If($Line.Code -eq $Code){
				$Name=$Line.Name
				$Title=($Global:I18NString.DeviceListItem -f $Name,$Code)
				Break
			}
		}
		$Index=$ListBox.Items.Add($Title)
		[VOID]$Global:Items.Add([PSCustomObject]@{
			Index=$Index
			Code=$Code
			Name=$Name
			Title=$Title
		})
	}
	$ListBox.EndUpdate()
}

Function DrawGUI(){
	$Window=[System.Windows.Forms.Form]::new()
	$Window.Text=$Global:I18NString.WindowTitle
	$Window.Width=700
	$Window.Height=500
	$Window.MinimumSize=[System.Drawing.Size]::new(600,400)
	$Window.MaximizeBox=$False
	$Global:MainWindow=$Window

	$Table=[System.Windows.Forms.TableLayoutPanel]::new()
	$Table.Top=10
	$Table.Left=10
	$Table.Width=$Window.ClientRectangle.Width-15
	$Table.Height=$Window.ClientRectangle.Height-15
	$Table.RowCount=9
	$Table.ColumnCount=4
	$Table.AutoSize=$True
	[VOID]$Table.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Absolute,250))
	[VOID]$Table.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
	[VOID]$Table.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
	[VOID]$Table.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
	[VOID]$Table.RowStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
	[VOID]$Table.RowStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
	[VOID]$Table.RowStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
	[VOID]$Table.RowStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
	[VOID]$Table.RowStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
	[VOID]$Table.RowStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
	[VOID]$Table.RowStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))
	[VOID]$Table.RowStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,100))
	[VOID]$Table.RowStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::AutoSize))

	$LabelTitle=[System.Windows.Forms.Label]::new()
	$LabelTitle.Text=$Global:I18NString.LabelTitle
	$LabelTitle.Anchor="Left,Top,Bottom"
	$LabelTitle.TextAlign=[System.Drawing.ContentAlignment]::MiddleLeft
	$LabelTitle.AutoSize=$True
	$Table.Controls.Add($LabelTitle,0,0)

	$ListBox=[System.Windows.Forms.ListBox]::new()
	$ListBox.Dock=[System.Windows.Forms.DockStyle]::Fill
	$ListBox.Anchor="Top,Bottom,Left,Right"
	$ListBox.ScrollAlwaysVisible=$True
	ReloadList -ListBox $ListBox
	$Table.Controls.Add($ListBox,0,1)
	$Table.SetRowSpan($ListBox,8)

	$LabelCodeName=[System.Windows.Forms.Label]::new()
	$LabelCodeName.Text=$Global:I18NString.LabelCodeName
	$LabelCodeName.Anchor="Left,Top,Bottom"
	$LabelCodeName.TextAlign=[System.Drawing.ContentAlignment]::MiddleLeft
	$LabelCodeName.AutoSize=$True
	$Table.Controls.Add($LabelCodeName,1,0)

	$CodeName=[System.Windows.Forms.Label]::new()
	$CodeName.Text="-"
	$CodeName.Anchor="Left,Top,Bottom"
	$CodeName.TextAlign=[System.Drawing.ContentAlignment]::MiddleLeft
	$CodeName.AutoSize=$True
	$Table.Controls.Add($CodeName,2,0)
	$Table.SetColumnSpan($CodeName,2)

	$LabelDeviceName=[System.Windows.Forms.Label]::new()
	$LabelDeviceName.Text=$Global:I18NString.LabelDeviceName
	$LabelDeviceName.Anchor="Left,Top,Bottom"
	$LabelDeviceName.TextAlign=[System.Drawing.ContentAlignment]::MiddleLeft
	$LabelDeviceName.AutoSize=$True
	$Table.Controls.Add($LabelDeviceName,1,1)
	$DeviceName=[System.Windows.Forms.Label]::new()
	$DeviceName.Text="-"
	$DeviceName.Anchor="Left,Top,Bottom"
	$DeviceName.TextAlign=[System.Drawing.ContentAlignment]::MiddleLeft
	$DeviceName.AutoSize=$True
	$Table.Controls.Add($DeviceName,2,1)
	$Table.SetColumnSpan($DeviceName,2)

	$LabelDestination=[System.Windows.Forms.Label]::new()
	$LabelDestination.Text=$Global:I18NString.LabelDestination
	$LabelDestination.Anchor="Left,Top,Bottom"
	$LabelDestination.TextAlign=[System.Drawing.ContentAlignment]::MiddleLeft
	$LabelDestination.AutoSize=$True
	$Table.Controls.Add($LabelDestination,1,2)
	$Destination=[System.Windows.Forms.TextBox]::new()
	$Destination.Dock=[System.Windows.Forms.DockStyle]::Fill
	$Destination.Text=".\output"
	$Destination.Anchor="Top,Bottom,Left,Right"
	$Destination.AutoSize=$True
	$Table.Controls.Add($Destination,2,2)
	$ButtonDestination=[System.Windows.Forms.Button]::new()
	$ButtonDestination.Text="..."
	$ButtonDestination.AutoSize=$True
	$ButtonDestination.Anchor="Top,Bottom"
	$Table.Controls.Add($ButtonDestination,3,2)

	$LabelCertificate=[System.Windows.Forms.Label]::new()
	$LabelCertificate.Text=$Global:I18NString.LabelCertificate
	$LabelCertificate.Anchor="Left,Top,Bottom"
	$LabelCertificate.TextAlign=[System.Drawing.ContentAlignment]::MiddleLeft
	$LabelCertificate.Enabled=$False
	$LabelCertificate.AutoSize=$True
	$Table.Controls.Add($LabelCertificate,1,3)
	$Certificate=[System.Windows.Forms.TextBox]::new()
	$Certificate.Dock=[System.Windows.Forms.DockStyle]::Fill
	$Certificate.Anchor="Top,Bottom,Left,Right"
	$Certificate.Enabled=$False
	$Certificate.AutoSize=$True
	$Table.Controls.Add($Certificate,2,3)
	$ButtonCertificate=[System.Windows.Forms.Button]::new()
	$ButtonCertificate.Text="..."
	$ButtonCertificate.Anchor="Top,Bottom"
	$ButtonCertificate.Enabled=$False
	$ButtonCertificate.AutoSize=$True
	$Table.Controls.Add($ButtonCertificate,3,3)

	$LabelPassword=[System.Windows.Forms.Label]::new()
	$LabelPassword.Text=$Global:I18NString.LabelPassword
	$LabelPassword.Anchor="Left,Top,Bottom"
	$LabelPassword.TextAlign=[System.Drawing.ContentAlignment]::MiddleLeft
	$LabelPassword.Enabled=$False
	$LabelPassword.AutoSize=$True
	$Table.Controls.Add($LabelPassword,1,4)
	$Password=[System.Windows.Forms.MaskedTextBox]::new()
	$Password.Dock=[System.Windows.Forms.DockStyle]::Fill
	$Password.PasswordChar="*"
	$Password.Anchor="Top,Bottom,Left,Right"
	$Password.Enabled=$False
	$Password.AutoSize=$True
	$Table.Controls.Add($Password,2,4)
	$Table.SetColumnSpan($Password,2)

	$CheckSign=[System.Windows.Forms.CheckBox]::new()
	$CheckSign.Anchor="Top,Bottom,Left"
	$CheckSign.AutoSize=$True
	$CheckSign.Text=$Global:I18NString.CheckSign
	$Table.Controls.Add($CheckSign,1,5)
	$Table.SetColumnSpan($CheckSign,3)

	$CheckForce=[System.Windows.Forms.CheckBox]::new()
	$CheckForce.Anchor="Top,Bottom,Left"
	$CheckForce.AutoSize=$True
	$CheckForce.Text=$Global:I18NString.CheckForce
	$Table.Controls.Add($CheckForce,1,5)
	$Table.SetColumnSpan($CheckForce,3)

	$LogBox=[System.Windows.Forms.RichTextBox]::new()
	$LogBox.Dock=[System.Windows.Forms.DockStyle]::Fill
	$LogBox.Anchor="Top,Bottom,Left,Right"
	$LogBox.AutoSize=$True
	$LogBox.ReadOnly=$True
	$LogBox.BackColor=[System.Drawing.Color]::Black
	$LogBox.ScrollBars=[System.Windows.Forms.ScrollBars]::Vertical
	$Global:LogTextBox=$LogBox
	$Table.Controls.Add($LogBox,1,7)
	$Table.SetColumnSpan($LogBox,3)

	$ButtonTable=[System.Windows.Forms.TableLayoutPanel]::new()
	$ButtonTable.RowCount=1
	$ButtonTable.ColumnCount=3
	$ButtonTable.AutoSize=$True
	$ButtonTable.Dock=[System.Windows.Forms.DockStyle]::Fill
	[VOID]$ButtonTable.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,33))
	[VOID]$ButtonTable.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,33))
	[VOID]$ButtonTable.ColumnStyles.Add([System.Windows.Forms.ColumnStyle]::new([System.Windows.Forms.SizeType]::Percent,33))

	$ButtonReload=[System.Windows.Forms.Button]::new()
	$ButtonReload.Text=$Global:I18NString.ButtonReload
	$ButtonReload.Anchor="Top,Bottom"
	$ButtonTable.Controls.Add($ButtonReload,0,0)

	$ButtonStart=[System.Windows.Forms.Button]::new()
	$ButtonStart.Text=$Global:I18NString.ButtonStart
	$ButtonStart.Enabled=$False
	$ButtonStart.Anchor="Top,Bottom"
	$ButtonTable.Controls.Add($ButtonStart,1,0)

	$ButtonCancel=[System.Windows.Forms.Button]::new()
	$ButtonCancel.Text=$Global:I18NString.ButtonCancel
	$ButtonCancel.Anchor="Top,Bottom"
	$ButtonTable.Controls.Add($ButtonCancel,2,0)
	$Window.CancelButton=$ButtonCancel

	$Table.Controls.Add($ButtonTable,1,8)
	$Table.SetColumnSpan($ButtonTable,3)

	$Window.Controls.Add($Table)

	Function UpdateButton(){
		$ButtonStart.Enabled=(`
			$CodeName.Text -ne "" -and `
			$CodeName.Text -ne "-" -and `
			$Destination.Text -ne "" -and `
			-not ($CheckSign.Checked -and $Certificate.Text -eq "")`
		)
	}
	$Window.Add_Resize({	
		$Table.Width=$Window.ClientRectangle.Width-15
		$Table.Height=$Window.ClientRectangle.Height-15
	})
	$Certificate.Add_TextChanged({
		UpdateButton
	})
	$ListBox.Add_SelectedValueChanged({
		If($ListBox.SelectedIndex -eq -1){
			Return
		}
		ForEach($Device in $Global:Items){
			If($Device.Index -ne $ListBox.SelectedIndex){
				Continue
			}
			$DeviceName.Text=$Device.Name
			$CodeName.Text=$Device.Code
			UpdateButton
		}
	})
	$LogBox.Add_SelectionChanged({
		If($LogBox.SelectionStart -ne $LogBox.TextLength){
			$LogBox.SelectionStart=$LogBox.TextLength
		}
	})
	$CheckSign.Add_CheckedChanged({
		If($CheckSign.Checked){
			$LabelCertificate.Enabled=$True
			$Certificate.Enabled=$True
			$ButtonCertificate.Enabled=$True
			$LabelPassword.Enabled=$True
			$Password.Enabled=$True
		}Else{
			$LabelCertificate.Enabled=$False
			$Certificate.Enabled=$False
			$ButtonCertificate.Enabled=$False
			$LabelPassword.Enabled=$False
			$Password.Enabled=$False
		}
		UpdateButton
	})
	$ButtonDestination.Add_Click({
		$Dialog=[System.Windows.Forms.FolderBrowserDialog]::new()
		$Dialog.Description=$Global:I18NString.DialogDestination
		Try{
			If(`
				$Destination.Text -ne "" `
				-and (Test-Path -Path $Destination.Text)`
			){
				$Dialog.SelectedPath=(Resolve-Path -Path $Destination.Text)
			}Else{
				$Dialog.SelectedPath=$Global:Base
			}
		}Catch{$Dialog.SelectedPath=$Global:Base}
		If($Dialog.ShowDialog()){
			$Destination.Text=$Dialog.SelectedPath
		}
	})
	$ButtonCertificate.Add_Click({
		$Dialog=[System.Windows.Forms.OpenFileDialog]::new()
		$Dialog.Title=$Global:I18NString.DialogCertificate
		$Dialog.Filter=$Global:I18NString.DialogCertificateFilter
		Try{
			If(`
				$Certificate.Text -ne "" -and `
				(Test-Path -Path $Certificate.Text)`
			){
				$Dialog.FileName=(Resolve-Path -Path $Certificate.Text)
			}Else{
				$Dialog.InitialDirectory=$Global:Base
			}
		}Catch{$Dialog.InitialDirectory=$Global:Base}
		If($Dialog.ShowDialog()){
			$Certificate.Text=$Dialog.FileName
		}
	})
	$ButtonStart.Add_Click({
		If($CodeName.Text -eq "" -or $CodeName.Text -eq "-"){
			Return
		}
		If($Destination.Text -eq "-"){
			Return
		}
		If($CheckSign.Checked -and $Certificate.Text -eq ""){
			Return
		}
		$ButtonStart.Text=$Global:I18NString.ButtonStartExtracting
		$ButtonStart.Enabled=$False
		$Window.Cursor=[System.Windows.Forms.Cursors]::WaitCursor
		$Window.Update()
		If($CheckSign.Checked){
			ExtractDrivers `
				-CodeName $CodeName.Text `
				-Folder $Destination.Text `
				-Certificate $Certificate.Text `
				-Password $Password.Text `
				-Force $CheckForce.Checked
		}Else{
			ExtractDrivers `
				-CodeName $CodeName.Text `
				-Folder $Destination.Text `
				-Force $CheckForce.Checked
		}
		$ButtonStart.Text=$Global:I18NString.ButtonStart
		$ButtonStart.Enabled=$True
		$Window.Cursor=[System.Windows.Forms.Cursors]::Arrow
		$Window.Update()
	})
	$ButtonReload.Add_Click({
		ReloadList -ListBox $ListBox
	})
	$ButtonCancel.Add_Click({
		$Window.Close()
	})
	[VOID]$Window.ShowDialog()
}

InitializeI18N
If($CodeName -eq ""){
	DrawGUI
}Else{
	If(-not (ExtractDrivers `
		-CodeName $CodeName `
		-Folder $Folder `
		-Certificate $Certificate `
		-Password $Password `
		-Force $Force `
	)){
		PrintLog "ERROR" $Global:I18NString.ExtractFailed
		Exit 1
	}
}
