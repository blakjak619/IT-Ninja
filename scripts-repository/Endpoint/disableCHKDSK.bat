::  It is recommended to test the script on a local machine for its purpose and effects.
::  ManageEngine Desktop Central will not be responsible for any
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to disable the disk checking during startup.
::  The parameters are the drive names which avoids disk checking during startup
::  Parameters - <Drive Name> ex: "c:"
::  Remarks -
::  Configuration Type - COMPUTER
::  ==============================================================

chkntfs /x %*