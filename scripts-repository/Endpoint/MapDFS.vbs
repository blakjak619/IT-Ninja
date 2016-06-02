'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Mapping network location instead of drive mapping.
'Parameters - "<shortcutPath>" "<shortcutName>"
'Remarks -
'Configuration Type - USER
'==============================================================

Const NETHOOD = &H13&

Set objWSHShell = CreateObject("Wscript.Shell")
Set objShell = CreateObject("Shell.Application")

Set objFolder = objShell.Namespace(NETHOOD)
Set objFolderItem = objFolder.Self
strNetHood = objFolderItem.Path

strShortcutPath = WScript.Arguments.Item(0)
strShortcutName = WScript.Arguments.Item(1)


Set objShortcut = objWSHShell.CreateShortcut _
(strNetHood & "\" & strShortcutName & ".lnk")
objShortcut.TargetPath = strShortcutPath
objShortcut.Save