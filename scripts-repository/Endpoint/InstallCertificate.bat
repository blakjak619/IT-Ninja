::  It is recommended to test the script on a local machine for its purpose and effects.
::  ManageEngine Desktop Central will not be responsible for any
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Batch script to install a certificate in Trusted Root CA
::  Parameters - "<certificate path>"
::  Remarks -
::  Configuration Type - COMPUTER
::  ==============================================================

certutil -addstore "Root" "%*"