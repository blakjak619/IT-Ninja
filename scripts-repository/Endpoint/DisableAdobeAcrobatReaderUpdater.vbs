'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to disable auto update of Adobe Acrobat Reader
'Parameters - "<version of acrobat reader>"
'Remarks -
'Configuration Type - COMPUTER
'==============================================================

Const HKEY_LOCAL_MACHINE = &H80000002
strComputer = "."

Set WshShell = WScript.CreateObject("WScript.Shell")
Set objReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & _
 strComputer & "\root\default:StdRegProv")

WshShell.Run "reg add ""HKLM\SOFTWARE\Policies\Adobe\Acrobat Reader\"&Wscript.Arguments(0)&"\FeatureLockdown"" /v bUpdater /t REG_DWORD /d 0 /f",true
