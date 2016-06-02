Function  MoveEVTLog {
param(`
[string]$RegSubKey, `
[string]$NewLocation)
$Usage = @"
#-------------------------------------------------------------------------
# Solution: MoveEVTLog
# Author: Sly Stewart
# Updated: 12/18/2012
# Version: 1.0
<#
# Description:
- Changes an .EVT log file to a new location. Requires a reboot before changes take effect.

#
# Usage:
# - MoveEVTLog -RegSubKey <String> -NewLocation <String>
#
# - MoveEVTLog -RegSubKey "HKLM:\SYSTEM\CurrentControlSet\Services\eventlog\Application" -NewLocation "D:\WinLogs\Application.evtx"
	# Moves the Windows "Application" log to "D:\WinLogs\Application.evtx"

#
# - MoveEVTLog -RegSubKey "HKLM:\SYSTEM\CurrentControlSet\Services\eventlog\System" -NewLocation "F:\SysLog\System.evtx"
	# Moves the Windows "System" log to "F:\SysLog\System.evtx"

## Common Log Registry locations:
"HKLM:\SYSTEM\CurrentControlSet\Services\eventlog\Application"
"HKLM:\SYSTEM\CurrentControlSet\Services\eventlog\HardwareEvents"
"HKLM:\SYSTEM\CurrentControlSet\Services\eventlog\Internet Explorer"
"HKLM:\SYSTEM\CurrentControlSet\Services\eventlog\Key Management Service"
"HKLM:\SYSTEM\CurrentControlSet\Services\eventlog\Media Center"
"HKLM:\SYSTEM\CurrentControlSet\Services\eventlog\OAlerts"
"HKLM:\SYSTEM\CurrentControlSet\Services\eventlog\Security"
"HKLM:\SYSTEM\CurrentControlSet\Services\eventlog\System"
"HKLM:\SYSTEM\CurrentControlSet\Services\eventlog\Windows PowerShell"

"HKLM:\SYSTEM\CurrentControlSet\Services\eventlog\<Event-Log-Name>"

#>
# Revision History
# Version 1.0 - Initial Commit 
#-------------------------------------------------------------------------
"@
	if ((!$RegSubKey) -or (!$NewLocation)) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to MoveEVTLog"
		}
		Write-Host $Usage
		throw
	}

	if (Test-Path $RegSubKey) {
		#Ensure the new location created first.
		try {
			$NewLocS = $NewLocation.Split("\")
			$EVT_FN = $NewLocS[$NewLocS.Length - 1]
			$EVTParentFolder = $NewLocation.TrimEnd("$EVT_FN")
			if (!(Test-Path $EVTParentFolder)) {
				New-Item -ItemType Directory -Path $EVTParentFolder -Force | Out-Null
			}
		} catch [Exception] {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: There was a problem creating the parent folder `"$EVTParentFolder`"."
			}
			Write-Host "There was a problem creating the parent folder `"$EVTParentFolder`"."
		}
	
		$RKCheck = (Get-ItemProperty -Path $RegSubKey -Name "File" -ErrorAction "SilentlyContinue").File
		$FlagCheck = (Get-ItemProperty -Path $RegSubKey -Name "Flags" -ErrorAction "SilentlyContinue").Flags

		###DWORD Flags hex 1
		if ($RKCheck) {
			Set-ItemProperty -Path "$RegSubKey" -Name "File" -Value $NewLocation | Out-Null
		} else {
			New-ItemProperty -Path "$RegSubKey" -Name "File" -Value $NewLocation -PropertyType "ExpandString" | Out-Null
		}
	
		if (!$FlagCheck) {
			New-ItemProperty -Path "$RegSubKey" -Name "Flags" -Value 1 -PropertyType "DWORD" | Out-Null
		}

		
	} else {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Registry SubKey `'$RegSubKey`' does not exist!"
		}
	}
	
}

Function NewEVTLog {
Param (`
[String]$Name, `
[String]$Source, `
[String]$FullPath)
$Usage = @"
#-------------------------------------------------------------------------
# Solution: NewEVTLog
# Author: Sly Stewart
# Updated: 12/19/2012
# Version: 1.0
<#
# Description:
- Creates a new MS EventViewer log file, or registers a new log source within an existing log file.
	New Log shows up under "Applications and Services Logs" in the Event Viewer.

#
# Usage:
# - NewEVTLog -Name <String> -Source <String> [-FullPath <String>]
	Mandatory Parameters:
	# -Name: Name of the Log file (New or existing) e.g. "AppLog1", "System"
	# -Source: Event Source to register with the log file. Event sources need to be registered with the log file in order to log to it.
				Commonly, Either the application name for a small application, or a component for a large application.
	
	Optional Parameters:
	# -FullPath: Full path to where to Create the physical log file at. If not used, the default path will be:
		C:\Windows\System32\Winevt\Logs\<LogFileName>.evtx
		e.g. "C:\Temp\Logfiles\AppLog1.evtx"
#
# - NewEVTLog -Name PadresLog -Source PadresFan -FullPath "D:\WinLogs\PadresLog.evtx"
	# Create a new log named "PadresLog" with the physical path of "D:\WinLogs\PadresLog.evtx". Registers the Event Source "PadresFan" with the log.

#
# - NewEVTLog -Name SDGulls -Source GullApp1
	# If the log file SDGulls does not exist, create it, then register the Event Source "GullApp1" with the SDGulls Log file.

#>
# Revision History
# Version 1.0 - Initial Commit 
#-------------------------------------------------------------------------
"@

	if ((!$Name) -or (!$Source)) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to NewEVTLog"
		}
		Write-Host $Usage
		throw
	}
	try {
		New-EventLog -LogName $Name -Source $Source
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "Successfully created EventLog `'$Name`' with event source `'$Source`'."
		}
	} catch [Exception] {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: There was an issue creating EventLog `'$Name`' with event source `'$Source`'. $_"
		}
	}
	if ($FullPath) {
		$EVT_Reg = "HKLM:\SYSTEM\CurrentControlSet\Services\eventlog\$Name"
		MoveEVTLog -RegSubKey $EVT_Reg -NewLocation $FullPath
		
	}
	Write-EventLog -LogName $Name -Source $Source -EventId 1 -Message "This is a starter message. Please disregard."
	
}