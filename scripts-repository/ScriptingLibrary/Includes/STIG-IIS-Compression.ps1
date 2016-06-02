
Function IISCompression {

param($IISPath,
[ValidateSet("Static", "Dynamic")][String]$Type, 
[ValidateSet("Enabled", "Disabled")][String]$State)
$Usage = @"
#-------------------------------------------------------------------------
# Solution: IISCompression
# Author: Sly Stewart 
# Updated: 3/13/2013
# Version: 1.0
<#
# Description: Sets IIS compression

- Mandatory Parameters
	[String]-IISPath <String>: The IIS path we need to alter 
	
- Optional Parameters
	[String]-Type <Static | Dynamic>: Sets context to Static or Dynamic content compression
	[String]-State <Enabled | Disabled>: Enable or Disable the context.


#
# Usage:
# - IISCompression -IISPath "IIS:\Sites\Padres" -Type Dynamic -State Disabled
#	## Disable "Dynamic Content Compression" for "IIS:\Sites\Padres"

# - IISCompression -IISPath "IIS:\Sites\Chargers" -Type Static -State Enabled
	## Enable "Static Content Compression" for "IIS:\Sites\Chargers"
#>
# Revision History
# Version 1.0 - Initial Commit
#-------------------------------------------------------------------------

"@
	if ($PSBoundParameters.Count -ne 3) {
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to CustomResponseHeader"
		}
		throw
	}

	if (Test-Path $IISPath) {
		if (!(Get-Module WebAdministration)) {
			if (Get-Module -ListAvailable -Name "WebAdministration") {
				Import-Module "WebAdministration"
				
			}
		}
		$Filter = "system.webserver/urlCompression"
		switch ($State) {
			"Enabled" { $Value = $true }
			"Disabled" { $Value = $false }
		}
		switch ($Type) {
			"Static" {
				try {
					Set-WebConfigurationProperty -PSPath $IISPath -filter $Filter -Name "doStaticCompression" -Value $Value
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "Successfully set Static compression to $State for `'$IISPath`'"
					}
				} catch [Exception] {
					Write-Host "Unable to set `'Static compression`' on `'$IISPath`'"
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: Unable to set `'Static compression`' on `'$IISPath`'"
					}
				}
			}
			"Dynamic" {
				try {
					Set-WebConfigurationProperty -PSPath $IISPath -filter $Filter -Name "doDynamicCompression" -Value $Value
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "Successfully set set Dynamic compression to $State for `'$IISPath`'"
					}
				} catch [Exception] {
					Write-Host "Unable to set `'Dynamic compression`' on `'$IISPath`'"
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: Unable to set `'Dynamic compression`' on `'$IISPath`'"
					}
				}
			}
		}

	} else {
		#IIS is not installed
		Write-Host "The IIS Path: `'$IISPath`' Does not exist!"
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: IIS path `'$IISPath`' does not exist."
		}
	}
}
