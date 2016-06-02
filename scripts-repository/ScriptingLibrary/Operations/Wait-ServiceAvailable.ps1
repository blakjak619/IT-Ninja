param (
    [Parameter(Mandatory=$true)] [string]$ComputerName,
    [Parameter(Mandatory=$true)] [string]$ServiceName,
    [Parameter()] [ValidateRange(0,241920)] [int]$timeoutMinutes = (24 * 60 * 60), #7 days maximum chosen arbitarily mainly to force non-negative numbers (again arbitarily since only values > 0 will result in timeout; negs will be treated as 0)
    [Parameter()] [System.Management.Automation.PSCredential] $Credential,
    [Parameter()] [switch]$Quiet
)
<#
.SYNOPSIS
	Test-TimeoutExceeded compares a start date with a timeout value and returns 0 ($True) if the timeout is exceeded and a positive number ($False) representing the number of minutes left before timeout
.DESCRIPTION
    Test-TimeoutExceeded compares a start date with a timeout value and returns 0 ($True) if the timeout is exceeded and a positive number ($False) representing the number of minutes left before timeout.
.NOTES  
    File Name  : Test-ServiceAvailable.ps1  
	Author  : Dan Meier
    Date	: 4/21/2014
.EXAMPLE
	Test-TimeoutExceeded -startTime $startDate -timeoutMinutes 10
.PARAMETER TransactionTimeout
	integer value 0 to 241920. Time in minutes to wait for timeout. A value of zero means to wait forever (no timeout). Maximum time is seven days.
#>
function Test-TimeRemaining {
param (
    [Parameter(Mandatory=$true)] [System.DateTime]$startTime,
    [Parameter()] [ValidateRange(0,241920)] [double]$timeoutMinutes #7 days maximum chosen arbitarily mainly to force non-negative numbers (again arbitarily since only values > 0 will result in timeout; negs will be treated as 0)
)
    if ($timeoutMinutes -gt 0) {
        [double]$deltaTime = $timeoutMinutes - ($(Get-Date) - $StartTime).TotalMinutes
        if ( $deltaTime -gt $timeoutMinutes) {
            return 0
        } else {
            return [int]$deltaTime # Return minutes remaining before timeout - any non-zero value will return a false.
        }
    }
    return 1 #infinite timeout
}

<#
.SYNOPSIS
	Test-ServiceAvailable waits until a service on a server is available.
.DESCRIPTION
    Test-ServiceAvailable waits until a service on a server is available or until a maximum wait time is exceeded
.NOTES  
    File Name  : Test-ServiceAvailable.ps1  
	Author  : Dan Meier
    Date	: 4/21/2014
.EXAMPLE
	Test-ServiceAvailable -ComputerName "dsbxdansql01" -startTime $startDate -timeoutMinutes 10
.PARAMETER TransactionTimeout
	integer value 0 to 241920. Time in minutes to wait for timeout. A value of zero means to wait forever (no timeout). Maximum time is seven days.
#>

# Start the timeout timer
$StartTime = Get-Date

while (!(Test-Connection $ComputerName -Quiet)) { 
    if (!$Quiet) { Write-Host "Waiting for $ComputerName to come on the network" }
    $timeRemaining = Test-TimeRemaining -startTime $StartTime -timeoutMinutes $timeoutMinutes
    if ( $timeRemaining) {
        if (!$Quiet) { Write-Host "$timeRemaining minutes before timeout exceeded."}
    } else {
        if (!$Quiet) { Write-Host "Timout limit of $timeoutMinutes minutes exceeded."}
        return $false
    }
    

    Start-Sleep -Seconds 5 
}


do {
    if ($Credential) {
        $svc = (invoke-command -ComputerName $ComputerName -ScriptBlock {param($ServiceName) Get-Service -Name "*$ServiceName*"} -Credential $Credential -ArgumentList $ServiceName)
    } else {
        $svc = (invoke-command -ComputerName $ComputerName -ScriptBlock {param($ServiceName) Get-Service -Name "*$ServiceName*"} -ArgumentList $ServiceName )
    }

    if ($svc.Status -ne "Running") {
        if (!$Quiet) { Write-Output "Service $ServiceName not running..."}
        $timeRemaining = Test-TimeRemaining -startTime $StartTime -timeoutMinutes $timeoutMinutes
        if ( $timeRemaining) {
            if (!$Quiet) { Write-Host "$timeRemaining minutes before timeout exceeded."}
            Start-Sleep -Seconds 5
        } else {
            if (!$Quiet) { Write-Host "Timeout limit of $timeoutMinutes minutes exceeded."}
            return $false
        }
    }
} until ($svc.Status -eq "Running" )

if (!$Quiet) { Write-Host "Service $ServiceName is available." }

return $true
