REM It is recommended to test the script on a local machine for its purpose and effects. 
REM ManageEngine Desktop Central will not be responsible for any 
REM damage/loss to the data/setup based on the behavior of the script.

REM Description - Batch file to disable the remote desktop and remote assistance in client machine
REM Parameters -
REM Remarks -
REM Configuration Type - COMPUTER
REM ==============================================================

reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v AllowTSConnections  /t REG_DWORD /d 0 /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fDenyTSConnections /t REG_DWORD /d 1 /f
reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Terminal Server" /v fAllowToGetHelp  /t REG_DWORD /d 0 /f