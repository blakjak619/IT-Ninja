param([Switch]$Help)

$Usage = @"
#-------------------------------------------------------------------------
# Solution: uD-RestartuDeployService.ps1
# Author: Todd Pluciennik
# Updated: 1/22/2015
# Version: 1.1
#
<# 
# Description:

# Usage: 
		- uD-RestartuDeployService.ps1 : restart the udeploy-server service with retries
		- uD-RestartuDeployService.ps1 -Help : Show this help text.
		
# Detailed description:
  Process works as follows:
    notify email; event log
    disable scheduled tasks
    stop udeploy
    start udeploy
    ( wait 5 mins after successful restart )
    force agent remediate 
    enable scheduled tasks
    notify email; event log
#> 
# Revision History
# Version 1.0 - Initial Commit 
# Version 1.1 - Added force remediate/restart agents
#-------------------------------------------------------------------------

"@
if ($Help) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	throw "Showing Help."
}


#############
# Variables #
#############

$SleepTime = 300 # sleep before restart and enabling scheduled tasks (seconds) 
$ScheduledTasks = ("udeploy-agent-monitor","udeploy-certwatch","udeploy-service-monitor")
$uDService = "udeploy-server"
$uDLogPath = "C:\udeploy-server\var\log\"
$URL = "https://udapp01:8443" 
# mail
$mailFrom = "udeploy@bridgepoint.local"
[string[]]$mailTo = "scm@bpiedu.com","ECC@ashford.edu"
$Smtpserver="mail-tools.bridgepoint.local"


########
# MAIN #
########

# source includes
$ScriptPath = "C:\udeploy-agent\var\work\Powershell_Scripts"
$IncludesF = "$ScriptPath\Includes"
if (! (Test-path -Path $IncludesF -PathType Container)) {
    Throw "Cannot find script library, path: $IncludesF"
}
. $IncludesF\LIB-Includes.ps1 -DefaultLibraryPath $ScriptPath -Intentional


#region Logging header
LLInitializeLogging -EventLogSource "uDRestart" -LogFileNameSeed "uDRestart" -LogLevel $LLWARN 
Write-Host "Logging enabled. Logging to `'$LLLogFilePath`'"

# this creates a variable: $LLLogFilePath
#endregion

#region: notify
# Log - capture request user
$u = "System"
if ($env:USERNAME) { $u = whoami }
LLToLog -Text "Restart uDeploy requested by: $u"

$msgBody= @"
Restart uDeploy requested by: $u`n
Log file: $LLLogFilePath`n
"@
Send-MailMessage -SmtpServer $Smtpserver -To $mailTo -From $mailFrom -Subject "uDeploy Restart: Start" -Body $msgBody 
#endregion

#region: disable scheduled tasks
Write-Host "Disabling scheduled tasks"
foreach ($schTask in $ScheduledTasks) {
    Disable-ScheduledTask -TaskName $schTask
    LLToLog -Text "Disabled $schTask"
}
#endregion

#region: restart
# LIB-Process stop service
Write-Host "Stopping service: $uDService"
StopService -ServiceName $uDService  -Force

# LIB-Process start service, try 5 times
Write-Host "Starting service: $uDService"
StartService -ServiceName $uDService -Tenacity 5
#endregion

#region: url check
# need to loop until ud service responds
[int]$scount = 3	# max sleep iterations to retry 
[int]$stime = 60	# seconds to sleep b/t retries
start-sleep $stime	
$uconnect = $false
# LIB-URL
$uconnect = GetUrl $URL 10000		# 10 second response 
if (! $uconnect ){
	do {
	     StartService -ServiceName $uDService -Tenacity 5
         # add a bit more time each time
         $stime = $stime + 30
         Write-Warning "Could not load uDeploy URL ($URL). Waiting $stime seconds to try again"
         Start-Sleep $stime
		 $scount--
		 $uconnect = GetUrl $URL 10000
		  if ($uconnect) { break }
		} until ($scount -eq 0)
}

# last check       
$uconnect = GetUrl $URL 10000
if ( ! $uconnect ) { 
    
    LLToLog -Text "Failed $URL"
    $msgBody= @"
Restart FAILED on udapp01`n
LogFile ($LLLogFilePath) attached
IMPORTANT: Please enable scheduled tasks ($ScheduledTasks) manually once issue resolved!
"@
    Send-MailMessage -SmtpServer $Smtpserver -To $mailTo -From $mailFrom -Subject "uDeploy Restart: FAILURE" -Body $msgBody -Attachments $LLLogFilePath
    throw "[ERROR] $uDService is not runnning properly, check log: $LLLogFilePath" 
}		
#endregion


Write-Warning "[INFO] Waiting $SleepTime seconds to restart agents and enable scheduled tasks"
Start-Sleep $SleepTime


#region: force restart of agents
$restartScript = "C:\udeploy-agent\var\work\Powershell_Scripts\uDMonitor\uDAgentStatus.ps1" 
$command = "$restartScript -Remediate"
Write-Warning "[INFO] Restarting OFFLINE agents with command: $command"
$results = Invoke-Expression $command # toss to a dummy variable so we continue on..
#endregion

sleep 10
#region: re-enable scheduled tasks
Write-Host "Enabling scheduled tasks"
foreach ($schTask in $ScheduledTasks) {
    Enable-ScheduledTask -TaskName $schTask
    LLToLog -Text "Enabled $schTask"
}
#endregion

#region: notify
# attach log file
$msgBody= @"
Restart Finished on udapp01`n
LogFile ($LLLogFilePath) attached
"@
Send-MailMessage -SmtpServer $Smtpserver -To $mailTo -From $mailFrom -Subject "uDeploy Restart: Finished" -Body $msgBody -Attachments $LLLogFilePath
#endregion

exit 0