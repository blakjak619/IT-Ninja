::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to remove logon programs
::  Parameters - "<name of the program>"
::  Remarks - Script executed without arguments will remove all Logon programs
::  Configuration Type - USER
::  ==============================================================

reg delete HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run /v %* /f