::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to uninstall all versions of Java from 5 to 8
::  Parameters -
::  Remarks -
::  Configuration Type - COMPUTER
::  ==============================================================

@ECHO OFF
cls
TITLE Uninstalling Java 5-7 and Java fx. . .

wmic product where "name like 'Java 8%%'" call uninstall /nointeractive
wmic product where "name like 'Java 7%%'" call uninstall /nointeractive
wmic product where "name like 'JavaFX%%'" call uninstall /nointeractive
wmic product where "name like 'Java(TM) 7%%'" call uninstall /nointeractive
wmic product where "name like 'Java(tm) 6%%'" call uninstall /nointeractive
wmic product where "name like 'J2SE Runtime Environment%%'" call uninstall /nointeractive
goto END

:END
exit