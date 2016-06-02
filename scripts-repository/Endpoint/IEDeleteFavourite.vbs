'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Deletes the favourites in IE with a specified name.
'Parameters -
'Remarks - The name of the favourite to be deleted must be hard coded
'Configuration Type - USER
'==============================================================

Set objFSO= CreateObject("Scripting.FileSystemObject")
Set WshShell=CreateObject("Wscript.Shell")
favPath=WshShell.ExpandEnvironmentStrings("%USERPROFILE%")&"\Favorites\"
favName="google.url" 'set the name of the favourite you want to delete

linkDeleted=False

For each objFile in objFSO.GetFolder(favPath).Files
If Trim(Ucase(objFile.Name))=Trim(Ucase(favName)) Then
objFSO.DeleteFile(objFile)
linkDeleted=True
End If
Next