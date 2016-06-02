REM It is recommended to test the script on a local machine for its purpose and effects. 
REM ManageEngine Desktop Central will not be responsible for any 
REM damage/loss to the data/setup based on the behavior of the script.

REM Description - The batch file is used to Enable .Net 3.5 feature for Windows 8
REM Parameters -
REM Remarks -
REM Configuration Type - COMPUTER
REM ==============================================================

DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:installationMediaDrive:\sources\sxs