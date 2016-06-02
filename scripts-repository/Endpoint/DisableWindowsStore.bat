::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to 'Turn off the store application'
::  Remarks - Not applicable to Windows 10 pro (Windows Behaviour)
::  Configuration Type - COMPUTER
::  ==============================================================


REG ADD HKLM\SOFTWARE\Policies\Microsoft\WindowsStore /v RemoveWindowsStore /t REG_DWORD /d 1 /f