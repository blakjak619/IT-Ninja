::  It is recommended to test the script on a local machine for its purpose and effects.
::  ManageEngine Desktop Central will not be responsible for any
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to disable NetBIOS over TCP/IP
::  Parameters -
::  Remarks -
::  Configuration Type - COMPUTER
::  ==============================================================

wmic /interactive:off nicconfig where TcpipNetbiosOptions=0 call SetTcpipNetbios 2
wmic /interactive:off nicconfig where TcpipNetbiosOptions=1 call SetTcpipNetbios 2