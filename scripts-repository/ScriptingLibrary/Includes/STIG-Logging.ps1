
function ToLog {
param(
	[parameter(Mandatory=$true)]$LogFile, 
	[parameter(Mandatory=$true)]$Text,
	[parameter()]$Source,
	[parameter()] [ValidateRange(0,32768)] $EventID 
	)
$Usage = @"
#-------------------------------------------------------------------------
# Solution: ToLog
# Author: Sly Stewart 
# Updated: 3/21/2013
# Version: 1.0
	Writes to a log file. Will create the log file if it does not currently exist.
	
# Revision History
# Version 1.0 - Initial Commit -SS 3/21/2013
"@

	If ($LLLogFilePath){ #Use the LIB-Logging logfile path if it exists.
		$LogFile = $LLLogFilePath
	}
	
	$Now = Get-Date -UFormat "[%T] "
	if (!(test-path $LogFile)) {
		$SHHH = New-Item -ItemType "file" $LogFile -Force
	}
	$LFOutString = "$Now$Text"
	Add-Content $LogFile -Value $LFOutString
	
	if(!$Source) { 
		$Source = "ServerBuild"
	}

	if($EventID -eq $null) { #guess the event type for legacy apps
		$failpattern = [regex]'failure|failed|issue|error|abort'
		if ($failpattern.match($Text).Success -eq "True") {
			$EventID = 1
		} else {
			$EventID = 2 # Success but not 'final' success of 0
		}
	}
	
	try {
		Write-EventLog -LogName Application -Source $Source -EventId $EventID -Message $Text -ErrorAction Stop
	} catch {
        $NeedSrcPattern = [regex]'source name.*does not exist'
		if (($NeedSrcPattern.match($_.Exception)).Success -eq "True" ) {
			try {
				New-EventLog -LogName Application -Source $Source -ErrorAction Stop
				Write-EventLog -LogName Application -Source $Source -EventId $EventID -Message $Text -ErrorAction Stop
			} catch {
				Write-Output "FAILURE::Unable to write to event log. Unable to create new source $source. Error: $_.Exception"
			}
		}
	}
		
}
