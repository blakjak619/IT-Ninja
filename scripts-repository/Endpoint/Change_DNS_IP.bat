::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to Change DNS Primary and Secondary IP Address
::  Parameters - "<Connection Name>" "<Primary IP Address>" "<Secondary IP Address>"
::  Remarks - Connection Name is case sensitive
::  Configuration Type - COMPUTER
::  ==============================================================

@ECHO OFF

set dnsip1=%2
set dnsip2=%3


ECHO Setting Primary DNS
netsh int ip set dns name = %1 source = static addr = %dnsip1%

ECHO Setting Secondary DNS
netsh int ip add dns name = %1 addr = %dnsip2%

ipconfig /flushdns

exit