::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to disable Auto Update of Adobe Flash Player
::  Parameters -
::  Remarks -
::  Configuration Type - COMPUTER
::  ==============================================================

@echo off
schtasks /change /tn "Adobe Flash Player Updater" /DISABLE

if ERRORLEVEL 1 SET ERRORLEVEL=0