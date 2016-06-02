::  It is recommended to test the script on a local machine for its purpose and effects. 
::  ManageEngine Desktop Central will not be responsible for any 
::  damage/loss to the data/setup based on the behavior of the script.

::  Description - Script to delete files inside a folder with size greater than a specified size.
::  Parameters -
::  Remarks - The size in bytes and the folder path must be hard coded.
::  Configuration Type - COMPUTER/USER
::  ==============================================================
:: BATCH SCRIPT START
@ECHO OFF

:: Set following variable for file size in Bytes (1024 Bytes=1KB, 1024KB=1MB, 1024MB=1GB)
SET /A FileSize=1000

:: Set following variable for file extensions to check (*.* = all files)
SET Filter=*.*

:: Set following variable with path to check inside for files
SET Folder=d:\hello

FOR /R "%Folder%" %%F IN (%Filter%) DO (
IF %%~zF GTR %FileSize% (
ECHO Deleting "%%F"
DEL /F "%%F"))
EXIT /B /0
:: BATCH SCRIPT END