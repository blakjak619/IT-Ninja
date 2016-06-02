'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to change the message notification duration.
'Parameters - "<time interval in seconds>"
'Remarks - The settings take effect during users next logon
'Configuration Type - USER
'==============================================================
Set WshShell = CreateObject("WScript.Shell")
TimeInSeconds = WScript.Arguments.Item(0)
myKey = "HKCU\Control Panel\Accessibility\MessageDuration"
WshShell.RegWrite myKey,TimeInSeconds,"REG_DWORD"
Set WshShell = Nothing