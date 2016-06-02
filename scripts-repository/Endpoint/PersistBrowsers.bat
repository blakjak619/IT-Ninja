::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to restore windows explorer at logon
::  Parameters -
::  Remarks -
::  Configuration Type - USER
::  ==============================================================

REG add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v PersistBrowsers /t REG_DWORD /d 1 /f