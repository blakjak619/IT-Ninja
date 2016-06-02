. c:\udeploy-agent\var\work\powershell_scripts\includes\LIB-Logging.ps1
LLInitializeLogging -LogLevel $LLCUSTOM

Import-Module WebAdministration

# Constants
$ChosenDynamicThreshold = 130

# We don't need a restart unless something changes, specifically if we set the dynamicIdleThreshold
$RestartNeeded = $false

# Get the current value for dynamicIdleThreshold
$dynamicIdleThreshold = $null #Set a default value in case it isn't currently set.
$ValRegex = [regex]'"([0-9]*)"'

$dynamicIdleThresholdLine = c:\windows\system32\inetsrv\appcmd list config -section:system.applicationHost/webLimits | select-string dynamicIdleThreshold

if($dynamicIdleThresholdLine){ # By default there is no setting so the select-string should return null
    $dynamicIdleThreshold = [regex]::match($dynamicIdleThresholdLine,$ValRegex).Groups[1].Value
    LLToLog -EventID 10004 -Text "Existing dynamicIdleThreshold was set to $dynamicIdleThreshold"
}

# Test the value and set it if needed
if($dynamicIdleThreshold -ne $ChosenDynamicThreshold){
    LLToLog -EventID 10006 -Text "dynamicIdleThreshold is being set to $ChosenDynamicThreshold"
    try{
        set-webconfigurationproperty /system.applicationHost/webLimits -name dynamicIdleThreshold -value $ChosenDynamicThreshold
        $RestartNeeded = $true
    } catch {
        LLToLog -EventID 10005 -Text "Failed to set dynamicIdleThreshold because $_.Exception"
    }
}

# For each apppool check the idleTimeout and set it 0 if it's not.
# If we aren't doing an IISRESET because of the dynamicIdleThreshold setting then restart the apppool otherwise the IISRESET will restart all of them
foreach($AppPool in ls IIS:\AppPools){
    $TimeOut = (Get-ItemProperty("IIS:\AppPools\$($AppPool.Name)") -Name processModel.idleTimeout.Value).TotalMinutes
    if($TimeOut -ne 0){
        LLToLog -EventID 10006 -Text "$($AppPool.Name) idleTimeout was set to $TimeOut, setting to 0"
        try{
            $AppPool.processModel.idleTimeout = [TimeSpan]::FromMinutes(0)
            Set-ItemProperty ("IIS:\AppPools\"+$AppPool.Name) -Name processModel.idleTimeout $AppPool.processModel.idleTimeout
            if(-not $RestartNeeded){
                $AppPool.Recycle()
                LLToLog -EventID 10008 -Text "$($AppPool.Name) was restarted."
            }
        } catch {
            LLToLog -EventID 10003 -Text "Failed to set IdleTimeout for $($AppPool.Name) because $_.Exception"
        }
    }
}

# If dynamicIdleThreshold was set, it's a IIS-wide setting so resetiis
if($RestartNeeded){
    Invoke-Command -scriptblock {iisreset}
    LLToLog -EventID 10010 -Text "IISRESET because dynamicIdleThreshold was set."
}

