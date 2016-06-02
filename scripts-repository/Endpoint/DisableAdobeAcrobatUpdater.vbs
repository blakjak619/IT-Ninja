'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to disable auto update of Adobe Acrobat
'Parameters - "<version of adobe acrobat>" "10.0"
'Remarks -
'Configuration Type - COMPUTER
'==============================================================

Const HKEY_LOCAL_MACHINE = &H80000002
strComputer = "."

Set WshShell = WScript.CreateObject("WScript.Shell")
Set objReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & _
 strComputer & "\root\default:StdRegProv")
 
WshShell.Run "reg add ""HKLM\SOFTWARE\Policies\Adobe\Adobe Acrobat\"& Wscript.Arguments(0) &"\FeatureLockDown"" /v bUpdater /t REG_DWORD /d 0 /f",true
