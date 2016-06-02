::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to remove personal folder from start menu
::  Parameters -
::  Remarks -
::  Configuration Type - USER
::  ==============================================================

REG add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v Start_ShowUser /t REG_DWORD /d 0 /f