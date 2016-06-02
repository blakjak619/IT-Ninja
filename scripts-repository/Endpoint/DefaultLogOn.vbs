'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to set the default Log on Domain
'Parameters - "<Domain Netbios name>"
'Remarks -
'Configuration Type - COMPUTER
'==============================================================

Set WshShell = CreateObject("WScript.Shell")
myKey = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\DefaultLogonDomain"
WshShell.RegWrite myKey,WScript.Arguments(0),"REG_SZ"
Set WshShell = Nothing