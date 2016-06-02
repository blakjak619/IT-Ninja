::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - The batch file blocks a specified port by adding a rule.
::  Parameters -
::  Remarks -  Ports has to be hard coded by modifying the batch file.
::  Configuration Type - COMPUTER
::  ==============================================================

netsh advfirewall firewall add rule name="old rule name" dir=in action=block protocol=TCP localport=5555
netsh advfirewall firewall add rule name="old rule name" dir=out action=block protocol=TCP localport=5555
exit /b %errorlevel%
