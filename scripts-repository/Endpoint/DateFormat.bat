::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to set the date format for a particular user
::  Parameters - "<date format>" ex: "dd-MM-yyyy"
::  Remarks -
::  Configuration Type - USER
::  ==============================================================

reg add "HKCU\Control Panel\International" /v sShortDate /t REG_SZ /d %* /f
