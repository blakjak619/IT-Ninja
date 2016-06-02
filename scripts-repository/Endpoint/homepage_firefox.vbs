'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Sets the homepage for Firefox.
'Parameters -
'Remarks - The homepage url must be hard coded in the script
'Configuration Type - USER
'==============================================================

On Error Resume Next

Dim homepage, fileCtsTxt, fileCtsArr

Const ForReading = 1
Const ForWriting = 2

Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objShell = CreateObject("WScript.Shell")
strAppData=objShell.ExpandEnvironmentStrings("%APPDATA%")
strFolder = strAppData & "\Mozilla\Firefox\Profiles"

Set mozProfsPath = objFSO.GetFolder(strFolder)

Set mozProfs = mozProfsPath.SubFolders

For Each profPath In mozProfs

	prefsFile = profPath.Path & "\prefs.js"
	fileCtsTxt = GetFile(prefsFile)
	fileCtsTxt = SetHome(fileCtsTxt,"http://www.twitter.com")   'Fill in your required url
	WriteFile prefsFile,fileCtsTxt

Next

Function SetHome(fileTxt,homepage)
	Dim ctsArr, newCts, found
	found = False
	ctsArr = Split(fileTxt,vbCrLf)
	' Go through the contents of the file one line at a time
	' When we find the browser settings line, we replace it
	' with the one we want to set
	For i = 0 To UBound(ctsArr)
		ctsline = ctsArr(i)
		If(InStr(ctsline,"user_pref(""browser.startup.homepage") And Not InStr(ctsline,"user_pref(""browser.startup.homepage_override")) Then
			ctsArr(i) = "user_pref(""browser.startup.homepage"", """ & homepage & """);"
			found = True
		End If
		newCts = newCts & ctsArr(i) & vbCrLf
	Next
	If Not found Then ' When FF is first run, the home page directive in prefs.js isn't there, so we just add it
		newCts = newCts & "user_pref(""browser.startup.homepage"", """ & homepage & """);" & vbCrLf
	End If
	SetHome = newCts
End Function

'Read text file
function GetFile(FileName)
  If FileName<>"" Then
    Dim FS, FileStream
    Set FS = CreateObject("Scripting.FileSystemObject")
      on error resume Next
      Set FileStream = FS.OpenTextFile(FileName)
      GetFile = FileStream.ReadAll
  End If
End Function

'Write string As a text file.
function WriteFile(FileName, Contents)
  Dim OutStream, FS

  on error resume Next
  Set FS = CreateObject("Scripting.FileSystemObject")
    Set OutStream = FS.OpenTextFile(FileName, 2, True)
    OutStream.Write Contents
End Function