::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Batch script to set multiple home pages for Firefox browser
::  Parameters -
::  Remarks - The url of the homepages must be hard coded
::  Configuration Type - USER
::  ==============================================================

/*
ManageEngine Desktop Central Agent

'==============================================================
*/
:Mulitiplehomepages
set str=%appdata%
for /f "useback tokens=*" %%a in ('%str%') do set str=%%~a

for /F "tokens=1 delims= " %%a in ('dir "%str%\Mozilla\Firefox\Profiles" /b') do call :MulitiplehomepagesSub %%a "%str%"
goto :MulitiplehomepagesEnd

:MulitiplehomepagesSub

set str1=%2
for /f "useback tokens=*" %%a in ('%str1%') do set str1=%%~a
::  Enter the url of multiple homepages you want to set below with a "|" separation
echo user_pref("browser.startup.homepage", "https://www.facebook.com/ | http://www.gamespot.com");>>"%str1%\Mozilla\Firefox\Profiles\%1\prefs.js"
exit /b %errorlevel%

:MulitiplehomepagesEnd