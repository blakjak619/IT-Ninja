'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to disable system restore
'Parameters -
'Remarks -
'Configuration Type - COMPUTER
'==============================================================

strComputer = "."

Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\default")

Set objItem = objWMIService.Get("SystemRestore")
errResults = objItem.Disable("")