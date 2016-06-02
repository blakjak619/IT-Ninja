'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to create and set the folder permissions
'Parameters - "<folder path>" "<F/R/W>"
'Remarks - F for full access, R for Read only and W for Read and Write
'Configuration Type - COMPUTER
'==============================================================

Dim strHomeFolder, strHome, strUser
Dim intRunError, objShell, objFSO

strHomeFolder = Wscript.Arguments(0)

Set objShell = CreateObject("Wscript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
If Not objFSO.FolderExists(strHomeFolder) Then
	objFSO.CreateFolder(strHomeFolder)
End If
If objFSO.FolderExists(strHomeFolder) Then
	intRunError = objShell.Run("%COMSPEC% /c Echo Y| cacls " _
	& strHomeFolder & " /t /c /g everyone:" & Wscript.Arguments(1), 2, True)
	
	If intRunError <> 0 Then
		Wscript.Echo "Error assigning permissions for user " _
		& strUser & " to home folder " & strHomeFolder
	End If
End If