::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to schedule launch of IE with a landing page 
::  Parameters -
::  Remarks - The landing page and the time at which IE should be launched must be hardcoded.
::  Configuration Type - USER
::  ==============================================================

schtasks /Create /sc DAILY /tn LaunchIE /tr "C:\program files\internet explorer\iexplore.exe google.com" /st 13:47