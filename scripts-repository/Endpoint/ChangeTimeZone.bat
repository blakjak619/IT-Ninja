::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Batch Script to set the timezone of the local machine
::  Parameters - "<Time Zone>" ex: "India Standard Time"
::  Remarks -
::  Configuration Type - USER
::  ==============================================================

tzutil /s "%*"