::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to disable picture passwords in Windows 8
::  Parameters - 
::  Remarks -
::  Configuration Type - Computer
::  ==============================================================

reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\System" /v BlockDomainPicturePassword /t REG_DWORD /d 1 /f