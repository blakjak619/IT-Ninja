'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to delete a file placed anywhere in the computer
'Parameters - "<file name>"
'Remarks - The script will take some time to execute
'and post the status as it has to scan through the whole computer to search for the file and delete it.
'Configuration Type - COMPUTER/USER
'==============================================================

Option Explicit

Const DeleteReadOnly = True 
Dim oFSO, oDrive, sFileName

Set oFSO   = CreateObject("Scripting.FileSystemObject") 
sFileName  = Wscript.Arguments(0)

For Each oDrive In oFSO.Drives 
  Recurse oDrive.RootFolder
Next 

Sub Recurse(oFolder)
  Dim oSubFolder, oFile

  If IsAccessible(oFolder) Then
    For Each oSubFolder In oFolder.SubFolders
     Recurse oSubFolder
    Next 

    For Each oFile In oFolder.Files
      If oFile.Name = sFileName Then
         oFile.Delete
      End If
    Next 
  End If
End Sub

Function IsAccessible(oFolder)
  On Error Resume Next
  IsAccessible = oFolder.SubFolders.Count >= 0
End Function