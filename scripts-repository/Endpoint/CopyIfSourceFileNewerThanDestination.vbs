'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to copy a file, if source file is newer than the destination file
'Parameters - "<source file path>" "<dest file path>"
'Remarks - 
'Configuration Type - COMPUTER/USER
'==============================================================

Option Explicit 
Dim WshShell 
Dim fso 
Dim USERPROFILE 
Dim srcPath 
Dim tgtPath 
On Error Resume Next 
Set WshShell = WScript.CreateObject("Wscript.Shell") 
Set fso = WScript.CreateObject("Scripting.FilesystemObject") 
'USERPROFILE = WshShell.ExpandEnvironmentStrings("%USERPROFILE%") 
srcPath = Wscript.Arguments(0) 
tgtPath = Wscript.Arguments(1)  
If Not fso.FileExists(tgtPath) Then 
fso.CopyFile srcPath, tgtPath, True 
ElseIf fso.FileExists(srcPath) Then 
ReplaceIfNewer srcPath, tgtPath 
End If 

Sub ReplaceIfNewer(strSourceFile, strTargetFile) 
Const OVERWRITE_EXISTING = True 
Dim objFso 
Dim objTargetFile 
Dim dtmTargetDate 
Dim objSourceFile 
Dim dtmSourceDate 
Set objFso = WScript.CreateObject("Scripting.FileSystemObject") 
Set objTargetFile = objFso.GetFile(strTargetFile) 
dtmTargetDate = objTargetFile.DateLastModified 
Set objSourceFile = objFso.GetFile(strSourceFile) 
dtmSourceDate = objSourceFile.DateLastModified 
If (dtmTargetDate < dtmSourceDate) Then 
objFso.CopyFile objSourceFile.Path, objTargetFile.Path,OVERWRITE_EXISTING 
End If 
Set objFso = Nothing 
End Sub 