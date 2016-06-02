'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to check the version of a file
'Parameters - "<filepath>"
'Remarks - 
'Configuration Type - USER/COMPUTER
'==============================================================
Set objFSO = CreateObject("Scripting.FileSystemObject")
Wscript.Echo objFSO.GetFileVersion(Wscript.Arguments(0))