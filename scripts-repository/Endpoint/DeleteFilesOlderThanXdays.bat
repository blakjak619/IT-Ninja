::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to Delete Files older than X days
::  Parameters - "<Folder Path>" "<Days in Number>"
::  Remarks - 
::  Configuration Type - USER/COMPUTER
::  ==============================================================


FORFILES /p %1 /s /c "cmd /c Del /F /Q @path" /d  -%2 

if %errorlevel% == 1 set errorlevel = 0


