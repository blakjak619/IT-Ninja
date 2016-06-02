'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to disable Windows automatic updates
'Parameters -
'Remarks -
'Configuration Type - COMPUTER
'==============================================================

Const HKEY_LOCAL_MACHINE = &H80000002
strComputer = "."

Set WshShell = WScript.CreateObject("WScript.Shell")
Set objReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & _
 strComputer & "\root\default:StdRegProv")

 checkOSArch = WshShell.RegRead("HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment\PROCESSOR_ARCHITECTURE")
 if checkOSArch = "x86" Then
WshShell.Run "reg add ""HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"" /v NoAutoUpdate /t REG_DWORD /d 1 /f",true
else
WshShell.Run """%programfiles%\DesktopCentral_Agent\bin\dctask64.exe"" invokeexe ""reg add """"HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate\AU"""" /v NoAutoUpdate /t REG_DWORD /d 1 /f""",true
end if