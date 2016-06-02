::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to disable Auto Update of Google Chrome
::  Parameters -
::  Remarks -
::  Configuration Type - COMPUTER
::  ==============================================================

@echo off
schtasks /change /tn "GoogleUpdateTaskMachineCore" /DISABLE
schtasks /change /tn "GoogleUpdateTaskMachineUA" /DISABLE

if ERRORLEVEL 1 SET ERRORLEVEL=0