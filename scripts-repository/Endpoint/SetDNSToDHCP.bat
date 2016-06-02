::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Batch script to change DNS setting from "obtain manually" to "obtain automatically"
::  Parameters -
::  Remarks -
::  Configuration Type - COMPUTER
::  ==============================================================

netsh interface ip set dns name="Local Area Connection" dhcp