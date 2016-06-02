'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to detect Bitness of office installed and the OS
'Parameters -
'Remarks - If the OS and the office have same bitness, the script returns a success code, else fails
'Configuration Type - COMPUTER
'==============================================================

on error resume next

Set WshShell = WScript.CreateObject("WScript.Shell")

'Get the Agent Installed directory from the Registry location details
'====================================================================
Err.Clear
checkOSArch = WshShell.RegRead("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\PROCESSOR_ARCHITECTURE")
returnValue = 2
'Wscript.Echo checkOSArch 

if Err Then
	Err.Clear
else
	if checkOSArch = "x86" Then
		'Wscript.Echo "The OS Architecture is 32 bit"
		checkOfficeArch = WshShell.RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Office\14.0\")
		If Err.Number = 0 then
		  ' Wscript.echo "32 bit office installed on 32 bit machine"
		   returnValue = 0
		end if
	else
		'Wscript.Echo "The OS Architecture is 64 bit"
		checkOfficeArch = WshShell.RegRead("HKEY_LOCAL_MACHINE\Software\WOW6432Node\Microsoft\Office\14.0\")
		If Err.Number = 0 then
		   'Wscript.echo "32 bit office installed on 64 bit machine"
		   returnValue = 0
		 else 
		    checkOffice64Arch = WshShell.RegRead("HKEY_LOCAL_MACHINE\Software\Microsoft\Office\14.0\")
			If Err.Number = 0 then
				'Wscript.echo "64 bit office installed on 64 bit machine"
				returnValue = 1
			end if
		end if
	End IF
End If

'wscript.echo returnValue
wscript.quit returnValue