function IISOutputCaching {
	param([String]$IISPath, `
	[ValidateSet("Add", "ClearAll")][String]$Action, `
	[ValidateSet("DontCache", "CacheUntilChange", "CacheForTimePeriod", "DisableCache")][String]$KernCaching, `
	[String]$Extension, `
	[ValidateSet("DontCache", "CacheUntilChange", "CacheForTimePeriod", "DisableCache")][String]$CachePolicy, `
	[TimeSpan]$Duration, `
	[ValidateSet("Any", "Client", "Downstream", "Server", "None", "ServerAndClient")][String]$Location)

	$Usage = @"
	#-------------------------------------------------------------------------
	# Solution: IISOutputCaching
	# Author: Sly Stewart 
	# Updated: 3/15/2013
	# Version: 1.0
	<#
	# Description: Sets a single IIS Output caching, or Removes ALL Output Caching items

	- Mandatory Parameters
		[String]-IISPath <String>: The IIS path we need to alter 
		[String]-Action <"Add" | "ClearAll">: Either Add a single item or remove all items from Output Caching
		
	- Optional Parameters
		[String]-Extension <String>: The extension to add.
		[String]-KernCaching <"DontCache" | "CacheUntilChange" | "CacheForTimePeriod" | "DisableCache">
			Set up Kernel-Mode Caching  with a Scheme
		[String]-CachePolicy <"DontCache" | "CacheUntilChange" | "CacheForTimePeriod" | "DisableCache">
			Set up User-Mode Caching  with a Scheme
		[TimeSpan]-Duration <TimeSpan>: TimeSpan used when selecting "CacheForTimePeriod"
		[String]-Location <String>: location of the output-cached HTTP response for a resource.

	#
	# Usage:
	# - IISOutputCaching -IISPath "IIS:\Sites\Padres" -Action "ClearAll"
	#	## Clears all output caching items on "IIS:\Sites\Padres"

	# - IISOutputCaching -IISPath "IIS:\Sites\Chargers" -Action "Add" -Extension ".nrt" -KernCaching CacheUntilChange
		## Add the extension ".nrt" and sets up Kernel-Mode Caching "Caching Until Change" on "IIS:\Sites\Chargers"

	# - IISOutputCaching -IISPath "IIS:\Sites\CleIndians\Players" -Action "Add" -Extension ".abc" -CachePolicy CacheForTimePeriod -Duration (new-timespan -minutes 2) -Location Downstream
		## Add the extension ".abc" with user-mode Caching for time period, with a 2 minute duration with downstream output caching set.

	#>
	# Revision History
	# Version 1.0 - Initial Commit. SS - 3/15/2013
	#-------------------------------------------------------------------------

"@
	if (Test-Path $IISPath) {
		if (!(Get-Module WebAdministration)) {
			if (Get-Module -ListAvailable -Name "WebAdministration") {
				Import-Module "WebAdministration"
				
			} else {
				Write-Host "IIS commandline tools is not installed!"
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: IIS commandline tools is not installed!"
				}
				throw
			}
		}
	if (!$IISPath) {
		Write-Host $usage
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to IISOutputCaching"
		}
		throw
	}
		$BaseFilter = "system.webServer/caching"
		if ($Action -eq "Add") {
			$CachingEnabled = (get-webConfigurationProperty -PSPath $IISPath -filter $BaseFilter -name enabled).Value
			if ($CachingEnabled -ne $true) {
				try {
					set-webConfigurationProperty -PSPath $IISPath -filter $BaseFilter -name enabled -Value $true
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "Successfully set UserMode caching to Enabled for `'$IISPath`'."
					}
				} catch [Exception] {
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: Unable to set UserMode caching to Enabled for `'$IISPath`'. $_"
					}
				}
			}
			if ($KernCaching) {
				$CheckKernCache = (get-webConfigurationProperty -PSPath $IISPath -filter $BaseFilter -name enableKernelCache).Value
				if ($CheckKernCache -ne $true) {
					try {
						set-webConfigurationProperty -PSPath $IISPath -filter $BaseFilter -name enableKernelCache -Value $true
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "Successfully set KernelMode caching to Enabled for `'$IISPath`'."
						}
					} catch [Exception] {
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "FAILURE:: Unable to set KernelMode caching to Enabled for `'$IISPath`'. $_"
						}
					}
				}
			}
			$Value = @{}
			$Extension_Filter = $BaseFilter + "/profiles"
			$Value.Add("extension", $Extension)
			if ($CachePolicy) {
				$Value.Add("policy", $CachePolicy)
			}
			if ($KernCaching) {
				$Value.Add("kernelCachePolicy", $KernCaching)
			}
			if ($Duration) {
				$SS = $Duration.Seconds
				$MM = $Duration.Minutes
				$HH = $Duration.Hours
				$TimeString = "$HH`:$MM`:$SS"
				$Value.Add("duration", $TimeString)
			}
			if ($Location) {
				$Value.Add("location", $Location)
			}
			try {
				Add-WebConfiguration -Filter $Extension_Filter -PSPath $IISPath -Value $Value
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "Successfully set Output caching for `'$IISPath`'."
				}
			} catch [Exception] {
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: Unable to set Output caching $Value for `'$IISPath`'. $_"
				}
			}
		}
		
		if ($Action -eq "ClearAll") {
			$ClearAll_Filter = "system.webServer/caching/profiles/add"
			try {
				Clear-webConfiguration -Filter $ClearAll_Filter -PSPath $IISPath
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "Successfully Removed all Output caching for `'$IISPath`'."
				}
			} catch [Exception] {
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: Unable to remove all Output caching $Value for `'$IISPath`'. $_"
				}
			}
		}
		
	}
}
