#region Global Variables
<# 
.SYNOPSIS
	LIB-Logging.ps1 is the container for all logging related functions for the BPI Scripting Library
.DESCRIPTION
	This file contains all of the logging related functions for the BPI Scripting Library. It also has a main section (not a function) that when
	the script is executed from the command-line the main will run and test the functions and report pass/fail status for all tests.
	When this file is sourced into another script then the main section will detect that this file was source and not run the test code.
.NOTES  
	Author        : Dan Meier  
	Assumptions   :
		Must be run as administrator.
.OUTPUTS
    Returns a string containing 14 [0-9] characters.
#>
if( $LLFATAL -eq $null ) { Set-Variable -Name LLFATAL -Value 0 –option Constant }
if( $LLERROR -eq $null) { Set-Variable -Name LLERROR -Value 3 -option Constant }
if( $LLWARN -eq $null) { Set-Variable -Name LLWARN  -Value 7 -option Constant }
if( $LLSUCCESS -eq $null) { Set-Variable -Name LLSUCCESS -Value 1 -option Constant }
if( $LLINFO -eq $null) { Set-Variable -Name LLINFO -Value 7 -option Constant }
if( $LLAUDIT -eq $null) { Set-Variable -Name LLAUDIT -Value 15 -option Constant }
if( $LLDEBUG -eq $null) { Set-Variable -Name LLDEBUG -Value 31 -option Constant }
if( $LLTRACE -eq $null) { Set-Variable -Name LLTRACE -Value 63 -option Constant }
if( $LLVERBOSE -eq $null) { Set-Variable -Name LLVERBOSE -Value 127 -option Constant }
if( $LLCUSTOM -eq $null) { Set-Variable -Name LLCUSTOM -Value 32767 -option Constant }
#endregion
#region LLDateTimeStamp
<# 
.SYNOPSIS
	LLDateTimeStamp returns current date time in the format of 20140723133100
.DESCRIPTION
	LLDateTimeStamp returns the current date and time with no spaces or punctuation in least significant to most significant order.
.NOTES  
	Author        : Dan Meier  
	Assumptions   :
		This is a core library function that doesn't rely on any other functions
		It must be run as administrator to access the event logs for the purpose of getting and setting the event log source.
.OUTPUTS
    Returns a string containing 14 [0-9] characters.
#>
function LLDateTimeStamp {
	return (Get-Date -UFormat "%Y%m%d%H%M%S")
}
#endregion
#region LLTraceMsg
<# 
.SYNOPSIS
	LLTraceMsg checks if tracing is on and then records a trace message on behalf of the calling function
.DESCRIPTION
	LLTraceMsg checks if tracing is on and then records a trace message on behalf of the calling function
.NOTES  
	Author        : Dan Meier  
	Assumptions   :
#>
function LLTraceMsg {
param(
	[System.Management.automation.InvocationInfo]$InvocationInfo
)
	 if(($LLLogLevel -band $LLTRACE) -eQ $LLTRACE) { 
	 	$msg = "$($InvocationInfo.MyCommand) called with "
        $InvocationInfo.BoundParameters.GetEnumerator() | foreach-object {
            $Type = ($_.Value).GetType()
            if($Type.Name -eq "Hashtable"){
                $thash = $_.Value
                $msg += "@{ "
                $thash.GetEnumerator() | foreach-object{
                    if([string]::IsNullOrEmpty($_.Value)){
                        $msg += "$($_.key) = null;"
                    } else {
                        $msg += "$($_.key) = $($_.value);"
                    }
                }
                $msg += " }"
            } else {
 			    $msg += "$_ "
           }
		}
		LLToLog -EventID $LLTRACE -Text $msg 
	}
}
#endregion
#region GetListOfSources
function GetListOfSources {
    $MasterLogList = Get-WinEvent -ListLog *

    $LogSourceHash = @{}

    foreach($LogFile in $MasterLogList){
        $ProviderList = @()

        if(Test-Path -Path HKLM:\SYSTEM\CurrentControlSet\services\eventlog\$($LogFile.LogName) ){
            PushD -Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\eventlog\$($LogFile.LogName)
            $ProviderList = @(ls)
			PopD

            foreach($Provider in $ProviderList){
                try{
                    $LogSourceHash.Add($Provider.PSChildName,$LogFile.LogName)
                } catch {
                    #Oh?! There can only be one source registered to any log file. I'm guessing that some sources might show up in other logs' registry's
                    try{
                        Write-EventLog -Source $Provider.PSChildName -LogName $LogFile.LogName -EventID 12321 -Message "Validating $($Provider.PSChildName) logname." -ErrorAction Stop
                        #This one worked so it's the one we'll document.
                        $LogSourceHash.Set_Item($Provider.PSChildName,$LogFile.LogName)
                    } catch {
                        #Do nothing
                    }
                }
            }
        }
    }

    return $LogSourceHash
}
#endregion
#region FindSource
function FindSource {
param( [string]$Source )

    $LogSources = GetListOfSources

    if($LogSources.ContainsKey($Source)){
        $retval = $LogSources[$Source]
    } else {
        $retval = $null
    }

    return $retval
}
#endregion
#region RegisterELSource
function RegisterELSource {
param( 
    [string]$EventLog,
    [string]$EventSource 
)

    #See if the source is already registered
    $CurrLogName = [System.Diagnostics.EventLog]::SourceExists($EventSource)

    #If it isn't registered to the log we want, unregister it
    if($CurrLogName -and $CurrLogName -ne $EventLog){
        Remove-EventLog -LogName $CurrLogName -Source $EventSource
    }

    #Check again if the source is already registered
    $CurrLogName = FindSource -Source $EventSource

    if($CurrLogName){
        LLToLog -EventID $LLWARN -Text "Unable to unregister source $EventSource from $CurrLogName."
        return $false
    }

    #Otherwise we're clear to register our source
    try{
        New-EventLog -LogName $EventLog -Source $EventSource
    } catch {
        LLToLog -EventID $LLWARN -Text "Failed to register source $EventSource in $EventLog. Reason: $_.Exception"
        return $false
    }
}
#endregion
#region LLInitializeLogging
<# 
.SYNOPSIS
	LLInitializeLogging sets up the logging parameters for subsequent functions to use
.DESCRIPTION
	LLInitializeLogging sets up the Application Event log source and sets up a log file name/path and ensures the file exists.
.NOTES  
	Author        : Dan Meier  
	Assumptions   :
.EXAMPLE
    . C:\Scripts\BridgepointScriptingLibrary\LIB-Logging.ps1
	$ELName = "Application"
	$ELSource = "myScripts"
	$BinLogLevel = $LLCUSTOM
	LLInitializeLogging -EventLogName $ELName -EventLogSource $ELSource -LogFileNameSeed $ELSource -LogLevel $BinLogLevel
	LLToLog -EventID 12321 -Text "You must provide both a user and a group when specifying AddToGroup." 

	Will initialize a new source in the Windows Event Application log called myScripts and will write the LLToLog -Text to both the Windows Event Log and to a logfile.
#>
function LLInitializeLogging {
param(
	[string]$EventLogSource = "BPI",
	[string]$LogFileNameSeed = "BPI",
    [string]$EventLogName = "BPI",
	[string]$LogPath = "C:\temp",
	[ValidateSet(3,7,15,31,63,127,32767)] [int]$LogLevel ,
	[string]$PrePend
)
	Set-Variable LLLogLevel $LogLevel -Option ReadOnly -visibility public -scope global -force

	Set-Variable LLEventLogSource $EventLogSource -Option ReadOnly -visibility public -scope global -force

	Set-Variable LLLogPrepend $PrePend -Option ReadOnly -visibility public -scope global -force
	
	#Create text Log file
	$LogFileName = "$LogFileNameSeed$(LLDateTimeStamp).log"
	Set-Variable LLLogFilePath (Join-Path $LogPath $LogFileName) -option ReadOnly -visibility public -scope global -force
	if (!(test-path $LLLogFilePath)) {
		$SHHH = New-Item -ItemType "file" $LLLogFilePath -Force
	}

    #Add Event Log if not already added
    $CheckEL = @(Get-EventLog -List | Where-Object {$_.Log -eq $EventLogName})

    if($CheckEL.Count -eq 0){
        if ([System.Diagnostics.EventLog]::SourceExists($EventLogSource)){
		    try{
				[System.Diagnostics.EventLog]::DeleteEventSource($EventLogSource)
			} catch {
				Add-Content $LLLogFilePath -Value "$Now Unable to deleted log source $EventLogSource. Reason: $_.Exception"
			}
        }
		try{
			New-EventLog -LogName $EventLogName -Source $EventLogSource -ErrorAction Stop
			Limit-EventLog -LogName $EventLogName -OverflowAction OverWriteAsNeeded -MaximumSize 64KB
		} catch {
			Add-Content $LLLogFilePath -Value "$Now New-EventLog -LogName $EventLogName -Source $EventLogSource -ErrorAction Stop : failed. Reason $_.Exception"
		}
    }
    $CheckEL = Get-EventLog -List | Where-Object {$_.Log -eq $EventLogName}
    if(-not $CheckEL){
        $Now = Get-Date -UFormat "[%T] "

	    Add-Content $LLLogFilePath -Value "$Now $Text"

        $EventLogName = "Application"
    }

    Set-Variable LLEventLogName $EventLogName -Option ReadOnly -visibility public -scope global -force

	#Add Event Log Source if not already added
    try {
	    if(-not ([System.Diagnostics.EventLog]::SourceExists($EventLogSource))) {
		    New-EventLog -LogName Application -Source $EventLogSource -ErrorAction Stop
	    }
    } catch {
        New-EventLog -LogName Application -Source $EventLogSource -ErrorAction Stop
    }

	LLTraceMsg -InvocationInfo $MyInvocation
}
#endregion
#region LLToLog
<# 
.SYNOPSIS
	LLToLog writes a text message to the Windows Application event log and to a log file
.DESCRIPTION
	LLToLog takes a string and an optional source and optional eventID and writes the string to the Windows Application event log and to a log file
.NOTES  
	Author        : Dan Meier  
	Assumptions   :
		LLInitializeLogging has been called
.OUTPUTS
    Returns a string containing 14 [0-9] characters.
#>
function LLToLog {
param(
	[parameter(Mandatory=$true)]$Text,
	[parameter()]$Source = $LLEventLogSource,
	[parameter()] [ValidateRange(0,32768)] $EventID 
)
	if($EventID){ #If null EventID (ie: caller doesn't provide one), then we can't filter on EventID so ignore filter.
		if(($EventID -band $LLLogLevel) -ne $EventID){
			return
		}
	}

	if(-not $LLEventLogSource) {
		$errmsg = "Logging was called before logging was configured. Call LLInitializeLogging before trying to call LLTolog."
		throw $errmsg
	}

	$Text = $LLLogPrePend + $Text

	$Now = Get-Date -UFormat "[%T] "

	Add-Content $LLLogFilePath -Value "$Now $Text"

	if($EventID -eq $null) { #guess the event type for legacy apps
		$failpattern = [regex]'failure|failed|issue|error|abort'
		if ($failpattern.match($Text).Success -eq "True") {
			$EventID = $LLERROR
		} else {
			$EventID = $LLINFO # Success but not 'final' success of 1
		}
	}
	switch ($EventID) {
		$LLFATAL {$EntryType = "Error" }
		$LLERROR {$EntryType = "Error" }
		$LLWARN {$EntryType = "Warning" }
		$LLSUCCESS {$EntryType = "Information" }
		$LLINFO {$EntryType = "Information" }
		$LLDEBUG {$EntryType = "Information" }
		$LLTRACE {$EntryType = "Information" }
		$LLVERBOSE {$EntryType = "Information" }
		Default {$EntryType = "Information" }
	}
	
	Write-EventLog -LogName $LLEventLogName -Source $Source -EntryType $EntryType -EventId $EventID -Message $Text -ErrorAction Continue
}
#endregion
#region SetupELogs
function SetupELogs {
param(
    [string]$LogName,
    [string]$LogSource
)
    #Validate Inputs
    if($LogName.Length -lt 1){
        LLToLog -EventID $LLWARN -Text "You must provide a Event Log Name to Setup Event Logs."
    }

    if($LogSource.Length -lt 1){
        LLToLog -EventID $LLWARN -Text "You must provide a Event Log Source to Setup Event Logs."
    }
    
    RegisterELSource -EventLog $LogName -EventSource $LogSource
}
#endregion
#region Unit Test
if ($MyInvocation.Line -match "\. ") {
} else {

# Test #1 - Calling ToLog without calling InitalizeLogging first
    Write-Host "Test #1 - Calling ToLog without calling InitalizeLogging first"
    $TestStatus = "Fail"
    try {
        LLToLog -EventID $LLINFO -Text "Test 1 message"
    } catch {
        if($_.Exception.Message -eq "Logging was called before logging was configured. Call LLInitializeLogging before trying to call LLTolog.") {
            Write-Host "Test #1 - Successfully detected calling ToLog before InitializeLogging"
            $TestStatus = "Pass"
        } else {
            Write-Error "Test #1 - $_.Exception"
            $TestStatus = "Fail"
        }
    }
    Write-Host "Test 1 - $TestStatus"

# Test #2 - Successful call sequence
    Write-Host "`n`nTest #2 - Correct call sequence"
    Write-Host "Get-EventLog should display a message from Test 2."
    Write-Host "Text logfile should display a message from Test 2."
	$StartTime = Get-Date
    Start-Sleep -Seconds 5
	LLInitializeLogging -LogLevel $LLTRACE
    $MsgTime = Get-Date
    $TestMessage = "Test 2 message sent at $MsgTime"
    LLToLog -EventID $LLINFO -Text $TestMessage
    Start-Sleep -Seconds 5

    $TestStatusA = "Fail"
	$EventLogs = Get-EventLog -LogName "application" -After $StartTime
    foreach($Event in $EventLogs) {
        if($Event.Message -eq $TestMessage) {$TestStatusA = "Pass"}
    }

    if(Get-Content $LLLogFilePath | Select-String $TestMessage) {
        $TestStatusB = "Pass"
    } else {
        $TestStatusB = "Fail"
    }
    if($TestStatusA -eq "Pass" -and $TestStatusB -eq "Pass") {
        Write-Host "Test #2 - Pass"
    } else {
        Write-Host "Test #2 - Fail"
        Write-Host "Event Log results:"
        $EventLogs
        Write-Host "`nText Log File results:"
        Get-Content $LLLogFilePath
    }

# Test #3 - Successful call sequence null event id
	$StartTime = Get-Date
	$TestMessage = "Message without event ID" 
	LLToLog -Text $TestMessage

	$TestStatusC = "Fail"
	$EventLogs = Get-EventLog -LogName "application" -After $StartTime
    foreach($Event in $EventLogs) {
        if($Event.Message -eq $TestMessage) {$TestStatusC = "Pass"}
    }

	Write-Host "Test 3 $TestStatusC"

# Test #4 - Register source
	$StartTime = Get-Date

    SetupELogs -LogName "Testing1" -LogSource "Test4"

    $TestLog = FindSource -Source "Test4"
	if($TestLog){
        Write-Host "Created Source Test4 in $TestLog"
    }

    SetupELogs -LogName "Testing2" -LogSource "Test4"

    $TestLog = FindSource -Source "Test4"
	if($TestLog){
        Write-Host "Created Source Test4 in $TestLog"
    }

    Remove-EventLog -LogName "Testing1"
    if(Get-WinEvent -ListLog "Testing2"){
        Remove-EventLog -LogName "Testing2"
    }
}
#endregion