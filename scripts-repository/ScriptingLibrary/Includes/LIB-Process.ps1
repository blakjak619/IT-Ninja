$LPMAXRETRIES = 30
#region KillProcess
function KillProcess {
param(
	[string]$ServiceName
)
	LLTraceMsg -InvocationInfo $MyInvocation

    $filter = 'name="' + $ServiceName + '"'
	$pid2kill = (get-wmiobject Win32_Service -filter $filter).ProcessID
	LLToLog -EventID $LLINFO -Text "Preparing to kill process $ServiceName : $pid2kill"
	if($pid2kill -ne 0){
		Stop-Process -Id $pid2kill -Force
	} else {
		LLToLog -EventID $LLWARN -Text "Tried to kill process 0 for Service $ServiceName"
	}
}
#endregion
#region GetService
function GetService {
param(
	[string]$ServiceName
)
	LLTraceMsg -InvocationInfo $MyInvocation
	
	$status = (Get-Service -Name $ServiceName).Status
	
	return $status
}
#endregion
#region StopService
function StopService {
param(
	[string]$ServiceName,
	[switch]$Force,
	[int]$Tenacity = 3
)
    LLTraceMsg -InvocationInfo $MyInvocation
	
	$retval = 1

	if($Tenacity -lt 1) {
		$Tenacity = 3
	}
	$TenacityMod = 1

	$args = @{}
	$args.Add("-Name","$ServiceName")
	if($Force) {
		$args.Add("-Force",$true)
	}
	$args.Add("-ErrorAction","Stop")

    $sb = [scriptblock]::Create("Stop-Service $ServiceName")

	$status = ""
	$RetriesRemaining = $Tenacity
	while( $status -ne "Stopped" -and $RetriesRemaining ) {
		$RetriesRemaining--

		# Get it's initial status, if the service even exists. If it doesn't exist return an error.
		$status = GetService -ServiceName $ServiceName
		
		switch( $status ) {
			"Stopped"	{
				LLToLog -EventID $LLINFO -Text "$ServiceName service was stopped"
			}
			"Running"	{
				$TenacityMod = 1
				$jobid = Start-Job $sb  | Wait-Job -Timeout ($Tenacity * $TenacityMod)
			}
			"Paused"	{
				$TenacityMod = 5
				$jobid = Start-Job $sb  | Wait-Job -Timeout ($Tenacity * $TenacityMod)
			}
			"StartPending" {
				$TenacityMod = 5
				$jobid = Start-Job $sb  | Wait-Job -Timeout ($Tenacity * $TenacityMod)
			}
			"PausePending" {
				$TenacityMod = 5
				$jobid = Start-Job $sb  | Wait-Job -Timeout ($Tenacity * $TenacityMod)
			}
			"ContinuePending" {
				$TenacityMod = 5
				$jobid = Start-Job $sb  | Wait-Job -Timeout ($Tenacity * $TenacityMod)
			}
			"StopPending"	{
				$TenacityMod = 5
			}
			Default		{$Status = "Stopped"}
		}
		
		LLToLog -EventID $LLVERBOSE -Text "Stop-Service: $ServiceName is in $status state; Retries remaining = $RetriesRemaining"
		
		#Now wait to see if it stops
		if($status -ne "Stopped") {
			Start-Sleep -Seconds ($Tenacity * $TenacityMod)
			
			$status = GetService -ServiceName $ServiceName
			LLToLog -EventID $LLINFO -Text "$ServiceName service is in $status state."
		}
	}
	
	if($RetriesRemaining -eq 0) {
		LLToLog -EventID $LLINFO -Text "$ServiceName service would not stop, killing the process id."
		KillProcess -ServiceName $ServiceName
		Start-Sleep -Seconds 5
	}
	
	if((GetService -ServiceName $ServiceName) -ne "Stopped") {
		LLToLog -EventID $LLERROR -Text "Could not stop service $ServiceName."
		$retval = 0
	}
	
	return $retval
}
#endregion
#region StartService
function StartService {
param(
	[string]$ServiceName,
	[int]$Tenacity = 3
)
	LLTraceMsg -InvocationInfo $MyInvocation
	
	$params = @{}
	$params.Add("-ErrorAction","Stop")
	
    $RetriesRemaining = $Tenacity
    $status = GetService -ServiceName $ServiceName
	while( $status -ne "Running" -and $RetriesRemaining ) {
		switch( $status ) {
			"Stopped"	{
                try {
                    Start-Service $ServiceName @params
                } catch {
                    LLToLog -EventID $LLERROR -Text "Service $ServiceName failed to start: $($_.Exception)"
                }
			}
			"Running"	{
                LLToLog -EventID $LLINFO -Text "Service $ServiceName was already running when trying to Start-Service."
			}
			"Paused"	{
                LLToLog -EventID $LLWARN -Text "Service $ServiceName is paused when trying to Start-Service."
                Start-Service $ServiceName @params
                Start-Sleep -Seconds $Tenacity
			}
			"StartPending" {
                LLToLog -EventID $LLWARN -Text "Service $ServiceName is Start_Pending when trying to Start-Service."
                Start-Sleep -Seconds $Tenacity
			}
			"PausePending" {
				LLToLog -EventID $LLINFO -Text "Service $ServiceName is Pause_Pending when trying to Start-Service."
                Start-Sleep -Seconds $Tenacity
			}
			"ContinuePending" {
				LLToLog -EventID $LLINFO -Text "Service $ServiceName is Continue_Pending when trying to Start-Service."
                Start-Sleep -Seconds $Tenacity
			}
			"StopPending"	{
				LLToLog -EventID $LLINFO -Text "Service $ServiceName is Stop_Pending when trying to Start-Service."
                Start-Sleep -Seconds $Tenacity
			}
			Default		{
                LLToLog -EventID $LLERROR -Text "Service $ServiceName is in UNKNOWN state when trying to Start-Service."
                Start-Sleep -Seconds $Tenacity
            }
		}
        $status = GetService -ServiceName $ServiceName
        $RetriesRemaining--
    }
	
	if($status -ne "Running") {
		LLToLog -EventID $LLERROR -Text "Failed to start service $ServiceName."
	}
}
#endregion
#region RestartService
function RestartService {
param(
	[string]$ServiceName,
	[switch]$Force,
	[int]$Tenacity = 3
)
    LLTraceMsg -InvocationInfo $MyInvocation
	
	# Set the parameter hash, since Force is optional and may not be present
	$Stopparams = @{}
    $Startparams = @{}
	$Stopparams.Add("-ServiceName","$ServiceName")
    $Startparams.Add("-ServiceName","$ServiceName")
	if($Force) {
		$Stopparams.Add("Force",$true)
	}
	$Stopparams.Add("-Tenacity",$Tenacity)
    $Startparams.Add("-Tenacity",$Tenacity)
	
	StopService @Stopparams
	StartService @Startparams
}
#endregion
#region Unit Tests
#------------------------------------------- Main / Unit Test -------------------------------------------
if (($MyInvocation.Line -eq $null) -or ($MyInvocation.Line -notmatch "\. ")) {

	$LIBPATH = $env:ScriptLibraryPath
	. $LIBPATH\Includes\LIB-Includes.ps1 -DefaultLibraryPath $LIBPATH -Intentional

	LLInitializeLogging -LogLevel $LLTRACE
	if((Get-Service StrongBad).Status -eq "Stopped") {
        Write-Host "StrongBad service wasn't running, starting it."
		StartService -ServiceName "StrongBad"
	}

	# StrongBad takes 3 minutes to stop. With default -Tenacity 3 the stop service should retry stopping 3 times with 3 seconds between each try.
	# Therefore the StopService function should return while the service is still in running state.
    Write-Host "Stopping StrongBad with default tenacity. Stop the burninating!"
	$result = StopService -ServiceName "StrongBad" -Force
	if($result) {
		LLToLog -EventID $LLINFO -Text "StopService claims to have stopped the StrongBad service."
		#Then either the service stopped when it should have, or the function is falsly returning a success value.
		if((Get-Service StrongBad).Status -ne "Stopped") {
			LLToLog -EventID $LLWARN -Text "StrongBad Service did not successfully stop."
           Write-Host "StrongBad is not stopped."
		} else {
			LLToLog -EventID $LLINFO -Text "StrongBad Service successfully stopped."
           Write-Host "StrongBad is stopped."
    	}
	}
	# Wait for the service to actually stop
	while((Get-Service StrongBad).Status -ne "Stopped") {
		Write-Host "Sleeping while waiting for StrongBad to stop ((Get-Service StrongBad).Status)"
		Start-Sleep -Seconds 60
	}

    Write-Host "Restart testing."
	StartService -ServiceName "StrongBad"
	RestartService -ServiceName "StrongBad" -Force
	StopService -ServiceName "StrongBad" -Force
	
    Write-Host "Testing with tenacity."
	StartService -ServiceName "StrongBad"
	StopService -ServiceName "StrongBad" -Force -Tenacity 10
	StartService -ServiceName "StrongBad" -Tenacity 10
	RestartService -ServiceName "StrongBad" -Tenacity 10
	StopService -ServiceName "StrongBad" -Force -Tenacity 10
}
#endregion