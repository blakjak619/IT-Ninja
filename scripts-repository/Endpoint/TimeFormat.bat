::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to set the time format from 24 hours to 12 hours
::  Parameters -
::  Remarks -
::  Configuration Type - USER
::  ==============================================================

reg add "HKCU\Control Panel\International" /v sTimeFormat /t REG_SZ /d "h:mm:ss tt" /f
reg add "HKCU\Control Panel\International" /v sShortTime /t REG_SZ /d "h:mm tt" /f
