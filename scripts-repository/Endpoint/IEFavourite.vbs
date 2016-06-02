'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Creates a favourite in IE with a specified target link.
'Parameters -
'Remarks - Name of the favourite and target link must be hard coded.
'Configuration Type - USER
'==============================================================

Const ADMINISTRATIVE_TOOLS = 6 
 
Set objShell = CreateObject("Shell.Application") 
Set objFolder = objShell.Namespace(ADMINISTRATIVE_TOOLS)  
Set objFolderItem = objFolder.Self      
 
Set objShell = WScript.CreateObject("WScript.Shell") 
strDesktopFld = objShell.SpecialFolders("favorites")

'set the name of your favourite here
Set objURLShortcut = objShell.CreateShortcut(strDesktopFld & "\google.url") 

'set the target url here
objURLShortcut.TargetPath = "http://www.google.com" 
objURLShortcut.Save 