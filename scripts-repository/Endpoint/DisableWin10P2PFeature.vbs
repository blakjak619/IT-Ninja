'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Disable Windows 10 Peer to Peer Feature
'Parameters - "<value>"
'Remarks - The parameter value must be 1 to enable the feature and 2 to disable it.
'Configuration Type - COMPUTER
'==============================================================

Set WshShell = CreateObject("WScript.Shell")
myKey = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config\DODownloadMode"
WshShell.RegWrite myKey,Wscript.Arguments(0),"REG_DWORD"
Set WshShell = Nothing