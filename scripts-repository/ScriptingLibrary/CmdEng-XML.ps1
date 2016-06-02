<# 
.SYNOPSIS
	CmdEng-XML is a general XML processing engine, similar in function to STIG-ServerStandup.ps1.
.DESCRIPTION
	CmdEng-XML is a general XML processing engine, similar in function to STIG-ServerStandup.ps1; the difference being that CmdEng-XML processes XML elements in
	the order that they appear in the XML file whereas STIG-ServerStandup processes XML elements in the order they are looked for in the script itself.
	This script allows the XML to specify what task AND what order they will be performed in.
	As of the initial check-in of the script CmdEng-XML does not process any of the XML elements that STIG-ServerStandup does, but it is expected they will be
	added as needed.
.NOTES  
	Author        : Dan Meier  
	Assumptions   :
#>
[CmdletBinding(SupportsShouldProcess=$True)]
param(
	[string]$XMLFile
)
$ScriptBasePath = "c:\scripts\BridgepointScriptingLibrary"
. c:\scripts\BridgepointScriptingLibrary\Includes\LIB-Includes.ps1 -DefaultLibraryPath $ScriptBasePath -Intentional

LLInitializeLogging -LogLevel $LLTRACE 

if(-not $XMLFile -or -not (Test-Path $XMLFile)) {
	LLToLog -EventId $LLFATAL -Text "No XML file was specified or the specified file ($XMLFile) could not be found."
	return $false
}

$XMLDoc = [xml](Get-Content $XMLFile)
if(-not $XMLDoc) {
	LLToLog -EventID $LLERROR -Text "Unable to parse XML in file $XMLFile. Program terminating."
	return $false
}
#endregion

#region process XML
[System.Xml.XmlElement]$rootNode = $xmlDoc.get_documentElement()
foreach($Activity in $rootNode.ChildNodes) {
	switch(($Activity.Name).ToLower()) {
		"archive" { $result = RotateLogs -ArchivePath $Activity.dstPath -ArchivePattern $Activity.dstPattern -FileFilter $Activity.File -LogPath $Activity.srcPath }
		"purge" { $result = PurgeFiles -ArchivePath $Activity.Path -DaysToKeep $Activity.Days -FileFilter $Activity.File }
		"taskscheduler" { $result = TSScheduleTask -TaskNode $Activity }
        "removefile" { $result = ProcessRemoveFileDateXML $XMLDoc.CmdEngXML.RemoveFile }
		Default { LLToLog -EventID $LLWARN -Text "Unknown activity name $($Activity.Name). No action taken." }
	}
}
#endregion
return $true