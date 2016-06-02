param([switch]$Help, [String]$XMLFile)

$Usage = @"
#-------------------------------------------------------------------------
# Solution: STIG-START-STANDUP.ps1
# Author: Sly Stewart
# Updated: 2/25/2013
# Version: 1.0
<#
# Description:
- Ensures that the STIG-ServerStandup.ps1 is running under the "Run as Administrator" Credentials.
	All of this work is taken from Amit Budhu <Amitraj.Budhu@bpiedu.com>, 
	Im just repackaging it for use in this script.

#
# Usage: 
		- STIG-START-STANDUP.ps1 -XMLFile <String> : Configure the local server as defined in the "-XMLFile <String>" file.
		- STIG-START-STANDUP.ps1 -Help : Show this help text.
		


#>
# Revision History
# Version 1.0 - Initial Commit 
#-------------------------------------------------------------------------

"@
if ($Help) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	throw "Showing Help."
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

function Check-Elevation {
#-------------------------------------------------------------------------
# FUNCTION: Check-Elevation
# PURPOSE: Check if the current powershell window is running with 
# admin priviliges
#-------------------------------------------------------------------------
    $cur_user = [Security.Principal.WindowsIdentity]::GetCurrent();
    $elevation = (New-Object Security.Principal.WindowsPrincipal $cur_user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) 
    $echeck = $elevation
    return $echeck
}

function Raise-Elevation {
#-------------------------------------------------------------------------
# FUNCTION: Raise-Elevaton
# PURPOSE: Create a new instance of powershell with higher permissions
# and exit the current running powershell
#-------------------------------------------------------------------------
param([parameter(Mandatory=$true)][String]$Scriptpath)
    $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell"
    $newProcess.Arguments = $myInvocation.MyCommand.Definition
    $newProcess.Verb = "runas"
    $process = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    #$args = "-Command `"& `'$Scriptpath`'`""
	$args = "$ScriptPath"

    Start-Process $process -ArgumentList $args  -verb RunAs 
    #exit
}

$Here = $PWD
if (!(Check-Elevation)) {
	Raise-elevation -ScriptPath "$Here\STIG-ServerStandup.ps1 -XMLFile `'$XMLFile`'"
} else {
	& "$Here\STIG-ServerStandup.ps1" -XMLFile "$XMLFile"
}