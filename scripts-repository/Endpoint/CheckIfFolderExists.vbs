'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to check if the Folder exists in the machine
'Parameters - "<Folder path>"
'Remarks -
'Configuration Type - COMPUTER/USER
path = Wscript.Arguments(0)
Set fso = CreateObject("Scripting.FileSystemObject")
If (fso.FolderExists(path)) Then
   msg = path & " exists."
Else
   msg = path & " doesn't exist."
End If
Wscript.Echo msg