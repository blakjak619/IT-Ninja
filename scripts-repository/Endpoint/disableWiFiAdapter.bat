::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - The batch file is used to Disable the specified WiFi Adapter.
::  Parameters -
::  Remarks - To Enable WiFi Adapter need to modify the batch file appropriately.
::  Configuration Type - COMPUTER
::  ==============================================================

netsh interface set interface "Wireless Network Connection" disabled