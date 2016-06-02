::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to schedule log off at a specific time daily.
::  Parameters - "<Time>"
::  Remarks - The time given as the parameter must be in 24 hour format
::  Configuration Type - USER
::  ==============================================================

schtasks /Create /sc DAILY /tn logoff /tr logoff /st %*