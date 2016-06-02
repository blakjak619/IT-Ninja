::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - The batch file edits a given rules name, action, etc.
::  Parameters -
::  Remarks - The name, action must be hard coded in the batch file.
::  Configuration Type - COMPUTER
::  ==============================================================

netsh advfirewall firewall set rule name="old rule name" dir=in new name="new rule name" dir=in action=allow protocol=TCP localport=5555
netsh advfirewall firewall set rule name="old rule name" dir=out new name="new rule name" dir=out action=allow protocol=TCP localport=5555
exit /b %errorlevel%
