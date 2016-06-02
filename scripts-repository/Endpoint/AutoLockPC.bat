::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to auto lock PC based on the specified time interval
::  Parameters - <Time interval in seconds>
::  Remarks -
::  Configuration Type - USER
::  ==============================================================

reg add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v ScreenSaverIsSecure /t REG_SZ /d 1 /f
reg add "HKCU\Software\Policies\Microsoft\Windows\Control Panel\Desktop" /v ScreenSaveTimeout /t REG_SZ /d %* /f
