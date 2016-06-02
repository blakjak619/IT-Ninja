###
# README
###

This README is intended to accompany the uD-WebDeployWrapper.ps1 file in TFS ($/Enterprise/Enterprise/Systems/Scripts/Powershell/uDWrappers). 

Example XML files are included for reference purposes only. There is no guarantee past this version that they will be up-to-date with all required properties, etc.

Manifest: 
SetParameters.xml 	: The "main" XML file that is used for all environments
DEV.SetParameters.xml 	: The "DEV" environment specific XML file that's specific to DEV

Upon execution of the script, the files will be combined to a single XML file to be passed as the "-setParamFile" argument to msdeploy.exe.

Notables:
* .xml files created from the "EmployeeAccess.CFG" TFS build definition, build version 20140408.1
* Files are intended for tokenization via uDeploy (for the @@@ properties)
