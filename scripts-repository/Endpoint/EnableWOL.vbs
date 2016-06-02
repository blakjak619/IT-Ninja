'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Enable showing the icon in your system tray for connected NICs
'Enable Power Management for Connected NICs
'Parameters -
'Remarks - 
'Configuration Type - COMPUTER
'==============================================================

'Let's setup our variables
Const HKLM = &H80000002		'HKEY_LOCAL_MACHINE info for registry writes
Dim objReg			'Registry Object
Dim objWMIService		'WMI Service Object
Dim arrayNetCards		'Array of all connected NICs
Dim objNetCard			'A specific NIC
Dim strNICguid			'
Dim strShowNicKeyName		'Key Specific to the Network Adapters in CurrentControlSet
Dim strShowNicKeyName001	'Key Specific to the Network Adapters in CurrentControlSet001
Dim strPnPCapabilitesKeyName	'Key Specific to the Network Adapters in CurrentControlSet
Dim strPnPCapabilitesKeyName001	'Key Specific to the Network Adapters in CurrentControlSet001
Dim strComputer			'Name of computer to modify


strComputer = "." 		'Period = local computer

strShowNicKeyName = "SYSTEM\CurrentControlSet\Control\Network\{4D36E972-E325-11CE-BFC1-08002BE10318}\"
strShowNicKeyName001 = "SYSTEM\CurrentControlSet001\Control\Network\{4D36E972-E325-11CE-BFC1-08002BE10318}\"
strPnPCapabilitiesKeyName = "SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}\"
strPnPCapabilitiesKeyName001 = "SYSTEM\CurrentControlSet001\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}\"

ShowNicdwValue = 1 		'1 for ON, 0 for OFF

PnPdwValue = 56			'56 to disable "Allow the computer to turn off this device to save power."

				'48 to enable "Allow the computer to turn off this device to save power."

				'32 to enable "Allow the computer to turn off this device to save power."
				'  and enable "Allow this device to bring the computer out of standby."

				'288 to enable "Allow the computer to turn off this device to save power."
				'  and enable "Allow this device to bring the computer out of standby."
				'  and enable "Only allow management stations to bring the computer out of standby."


On Error Resume Next
Set objReg = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strComputer & "\root\default:StdRegProv")
Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")

'Look for the NICs that have IP enabled
Set arrayNetCards = objWMIService.ExecQuery ("Select * From Win32_NetworkAdapterConfiguration Where IPEnabled = True")

'Make changes on the NICs that have IP enabled
For Each objNetCard in arrayNetCards 
	strNICguid = objNetCard.SettingID		'Get the GUID of the NIC
	strDeviceID = Mid(objNetCard.Caption,6,4)	'Get the DeviceID of the NIC

	'Change the "Show icon in notification area when connected value"
	objReg.SetDWORDValue HKLM, strShowNicKeyName & strNICguid & "\Connection", "ShowIcon", ShowNicdwValue
	objReg.SetDWORDValue HKLM, strShowNicKeyName001 & strNICguid & "\Connection", "ShowIcon", ShowNicdwValue

	'Change the Power Management Values
	objReg.SetDWORDValue HKLM, strPnPCapabilitiesKeyName & strDeviceID & "\","PnPCapabilities",PnPdwValue
	objReg.SetDWORDValue HKLM, strPnPCapabilitiesKeyName001 & strDeviceID & "\","PnPCapabilities",PnPdwValue
Next

Set objReg = Nothing
Set objWMIService = Nothing