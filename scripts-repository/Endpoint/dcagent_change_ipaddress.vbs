'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to change the ip address to which the agent points to.
'i.e change the server to which the agent is attached.
'Parameters -
'Remarks - The ip address must be hardcoded.
'Configuration Type - COMPUTER
'==============================================================

On Error Resume Next

Set WshShell = WScript.CreateObject("WScript.Shell")

checkOSArch = WshShell.RegRead("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\PROCESSOR_ARCHITECTURE")

'Wscript.Echo checkOSArch 

if Err Then
	Err.Clear
	'WScript.Echo "The OS Architecture is unable to find ,so it was assumed to be 32 bit"
	regkey = "HKEY_LOCAL_MACHINE\SOFTWARE\AdventNet\DesktopCentral\DCAgent\ServerInfo\"
else
	if checkOSArch = "x86" Then
		'Wscript.Echo "The OS Architecture is 32 bit"
		regkey = "HKEY_LOCAL_MACHINE\SOFTWARE\AdventNet\DesktopCentral\DCAgent\"
	else
		'Wscript.Echo "The OS Architecture is 64 bit"
		regkey = "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\AdventNet\DesktopCentral\DCAgent\"
	End IF
End If

'Write the IP address here

   WshShell.RegWrite "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\AdventNet\DesktopCentral\DCAgent\ServerInfo\DCServerIPAddress", "192.168.27.60", "REG_SZ"
   WshShell.RegWrite "HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\AdventNet\DesktopCentral\DCAgent\ServerInfo\DCServerName", "192.168.27.60", "REG_SZ"

'******************************************************************************************************
