'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to disable the agent tray icon
'Parameters -
'Remarks -
'Configuration Type - COMPUTER
'==============================================================
Dim objShell,strKeyPath,strValueName,objReg,strValue
Const HKLM=&H80000002
strComputer="."
Set objReg=GetObject("winmgmts:\\" & strComputer & "\root\default:StdRegProv")
Set objShell = CreateObject("wscript.shell")
strKeyPath = "SOFTWARE\AdventNet\DesktopCentral\DCAgent"
strValueName = "DCAgentInstallDir"
objReg.GetStringValue HKLM,strKeyPath,strValueName,strValue
Set objExec = objShell.exec(strValue & "bin\dcagenttrayicon.exe -s")