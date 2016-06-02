'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to read the value of a registry
'Parameters - 
'Remarks - The registry value you want to read must be hardcoded
'Configuration Type - USER/COMPUTER
'==============================================================

Dim objShell,RegistryValue

'Type in the registry value below
RegistryValue = "HKEY_CURRENT_USER\SOFTWARE\Policies\Microsoft\Windows\Control Panel\Desktop\ScreenSaveTimeOut"

Set objShell = WScript.CreateObject("WScript.Shell")

WScript.Echo "Value Data: " & objShell.RegRead(RegistryValue)