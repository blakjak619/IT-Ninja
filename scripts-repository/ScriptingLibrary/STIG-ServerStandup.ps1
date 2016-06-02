param([switch]$Help, 
	[String]$XMLFile,
	[String]$LogFile )
$SUCCESS = 0
$FAILURE = 1
$INFO = 2
$ERR = 3
$WARNING = 5

#region Usage
$Usage = @"
#-------------------------------------------------------------------------
# Solution: STIG-ServerStandup.ps1
# Author: Sly Stewart
# Updated: 9/26/2013
# Version: 1.30
<#
# Description:
- Configures a server based on an XML file as input.
	Script is completely driven by the defined XML file (-XMLFile <String>)

#
# Usage: 
		- STIG-ServerStandup.ps1 -XMLFile <String> : Configure the local server as defined in the "-XMLFile <String>" file.
		- STIG-ServerStandup.ps1 -Help : Show this help text.
		


#>

"@
if ($Help) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	throw "Showing Help."
}
#endregion
#region XML file management
function XMLFileManagement{
	if ($XMLFile -match ".*\*.*") { #Filename contains a wildcard: '*' 
		#Then we are going to process multiple xml files
		#Get then next xml file in the folder that hasn't been processed yet
		$MultiXMLs = $true
		$XMLFolder = Split-Path $XMLFile -Parent
		$SequencerPath = Join-Path $XMLFolder "Sequencer.txt"
		$FinishedXMLs = $null
		if(Test-Path $SequencerPath) {
			$FinishedXMLs = Get-Content $SequencerPath
		}
		$UnfinishedXMLs = @(Get-ChildItem $XMLFile | Where-Object { -not ($FinishedXMLs -contains [IO.Path]::GetFileName($_)) })
		if( $UnfinishedXMLs ) {
			$XMLFile = $UnfinishedXMLs[0]
		} else {
			throw "-XMLFile $XMLFile ; unable to get wildcard XML files"
		}
	}

	if ($XMLFile) {
		if (!(Test-Path $XMLFile)) {
			throw "-XMLFile <String> parameter is absolutely needed, and path valid."
		} elseif ((gi $XMLFile).PSIsContainer) {
			throw "-XMLFile <String> parameter needs to point to a valid .XML file."
		} elseif (((gi $XMLFile).Extension) -ne ".xml") {
			throw "-XMLFile <String> parameter needs to point to a valid .XML file."
		}
	} else {
		throw "-XMLFile <String> parameter is absolutely needed, and path valid."
	}

	$NoOp = $false
	$ExitCodeStr = 0
	$script:ScriptPath = ($PWD).path
	$OSString = (Get-WmiObject -class Win32_OperatingSystem).Caption + " (" + (Get-WmiObject -class Win32_OperatingSystem).OSArchitecture + ")"
	try {
		[xml]$script:XMLParams = gc $XMLFile
	} catch [Exception] {
		$NoOp = $true
		Write-Host "Error reading XML file."
		$ExitCodeStr = 1
	}

	if (!$script:XMLParams) {
		$NoOp = $true
		Write-Host "Empty XML file"
		$ExitCodeStr = 1
	}
}
#endregion
#region Logging Setup
function LoggingSetup {
param([string]$InitialLogFile)
	$LoggingCheck = ($script:XMLParams.params.Logging | ? {$_.State -eq "Enabled"}) -or !$script:XMLParams.params.Logging
	if ($LoggingCheck) {

		$START_TIMESTAMP = Get-Date
		$LTS = Get-Date -UFormat "%Y%m%d%H%M%S"
		[String]$LFBase = $LoggingCheck.Name
		if (-not $LFBase) {
			[String]$LFBase = "STIG-Standup[TimeStamp].log"
		}
		$LFName = Join-Path $script:ScriptPath ($LFBase.Replace("[TimeStamp]", $LTS))
		if (Test-Path $LFName) {
			$Quiet = Remove-Item $LFName -Force
		}
		Write-Host "Logging enabled. Logging to `'$LFName`'"

		[string]$TextLogLevel = $script:XMLParams.params.Logging.LogLevel
		switch ($TextLogLevel) {
			"ERROR"   { $BinLogLevel = $LLERROR }
			"FATAL"   { $BinLogLevel = $LLFATAL }
			"WARN"    { $BinLogLevel = $LLWARN }
			"INFO"    { $BinLogLevel = $LLINFO }
			"DEBUG"  { $BinLogLevel = $LLDEBUG }
			"TRACE"   { $BinLogLevel = $LLTRACE }
			"VERBOSE" { $BinLogLevel = $LLVERBOSE }
            "CUSTOM"  { $BinLogLevel = $LLCUSTOM }
			Default { 
				Write-Host "No logging level specified or an unrecognized value ($LogLevel) provided. Defaulting to LogLevel = `"WARN`" "
				$BinLogLevel = $LLWARN 
			}
		}

		$ELSource = $LoggingCheck.Source
		if(-not $ELSource){
			$ELSource = "Standup"
		}
		
        $ELName = $LoggingCheck.Log
        if(-not $ELName){
            $ELName = "Standup"
        }

		LLInitializeLogging -EventLogName $ELName -EventLogSource $ELSource -LogFileNameSeed "STIG-Standup" -LogLevel $BinLogLevel 
		$BinLogLevel = $null
		$TextLogLevel = $null

		if($InitialLogFile){
			$InitialLogFile > $LLLogFilePath
			Remove-Item $InitialLogFile
		}
		$LFName = $LLLogFilePath

		foreach($LogSetup in $script:XMLParams.params.Logging.EventLog){
			$ELSource = $LogSetup.Provider
			$ELName = $LogSetup.Name
			if($ELName -and $ELSource){
				SetupELogs -LogName $ELName -LogSource $ELSource
			}
		}
	}
}
#endregion

XMLFileManagement

if (!$NoOp) {
#region Source Library Files
	$IncludesF = join-path "$script:ScriptPath"  $script:XMLParams.params.Folders.Includes
	. $IncludesF\LIB-Includes.ps1 -DefaultLibraryPath $script:ScriptPath -Intentional
	$BinServer = ($script:XMLParams.params.Bindependency.ServerBinRoot).Name

#endregion

	LoggingSetup
	
    #Depending on if the ProcessingOrder tag is set to XML or Script (or null) process the XML tags in the order that they appear in the XML, or in order that script says (do all tag A's first, then all tag B's, etc.)
    if( $script:XMLParams.params.ProcessingOrder -eq "XML" ){
        DoXMLOrder -XMLParams $script:XMLParams
    } else {
        DoXMLScriptOrder -XMLParams $script:XMLParams
    }

#region Final Tasks
####
## final checks based on dependencies
####

	if ($MultiXMLs) { #We made it through the script. If we are doing wildard xmls, mark this one as done
		Add-Content $SequencerPath (Split-Path $XMLFile -Leaf)
	}

	if ($script:XMLParams.params.LastXML) { #If this is the last xml file in a series, then we are done and delete the Sequencer file that keeps track of which xmls we have finished.
		Remove-Item $SequencerPath
	}
	
	if ($LoggingCheck) {
		$END_TIMESTAMP = Get-Date
		$TotalTimeSeconds = [Math]::Round((New-TimeSpan -Start $START_TIMESTAMP -End $END_TIMESTAMP).TotalSeconds, 2)
		ToLog -LogFile $LFName -Text "Completed script in $TotalTimeSeconds second(s)."
	}
	
	$RestartOS = $script:XMLParams.params.RestartOS
	if ($RestartOS) {
		if ($LoggingCheck) {ToLog -LogFile $LFName-Text "Server restart requested. Rebooting."}
		Restart-Computer -Force
	}
	
	$PurgeFiles = $script:XMLParams.params.Purge.Spec
	if ($PurgeFiles) {
		foreach ($Spec in $PurgeFiles) {
			$PurgePath = $Spec.Path
			$PurgeFilter = $Spec.Filter
			Get-ChildItem -Path $PurgePath -Filter $PurgeFilter | foreach {
                LLToLog -EventID $LLINFO -Text "Deleting path/file $($_.Fullname)"
                Remove-Item $_.FullName -Confirm:$false
            }
		}
	}

	#Lastly, go back to the starting location.
	Set-Location $script:ScriptPath
#endregion
} # end !NoOp
#region Cleanup
Write-host "Final Log check (location: `"$LFName`")"
if ($LoggingCheck) {
    $LogText = gc  -Path $LFName
    $LogText

	$LogTextFailures = ($LogText | Select-String "FAILURE:: ")
	if ($LogTextFailures) {
		Write-Host "There were failures found in the logs. `n`n $LogTextFailures"
    	$ExitCodeStr = 1
	} 

}
#  
#endregion
Write-host "Finished. Exit code: $ExitCodeStr "
exit $ExitCodeStr