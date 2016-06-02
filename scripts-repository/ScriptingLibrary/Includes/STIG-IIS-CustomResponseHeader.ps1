
function CustomResponseHeader {
param($IISPath, `
[parameter(parameterSetName="CacheDays")][int]$ExpireCacheInDays, `
[parameter(parameterSetName="CacheDate")][DateTime]$ExpireCacheOnDate, `
[parameter(parameterSetName="DisableCache")][switch]$DisableCache, `
[parameter(parameterSetName="NoClientCache")][switch]$ClientNoCache)
$Usage = @"
#-------------------------------------------------------------------------
# Solution: CustomResponseHeader
# Author: Sly Stewart 
# Updated: 3/13/2013
# Version: 1.0
<#
# Description: Sets common HTTP Response header options

- Mandatory Parameters
	[String]-IISPath <String>: The IIS path we need to alter 
	
- Optional Parameters
	[int]-ExpireCacheInDays <String>: Set the cache to expire in X days
	[DateTime]-ExpireCacheOnDate <DateTime>: Sets the cache to expire on a specific date
	[switch]-DisableCache: Disable the response headers.
	[switch]-ClientNoCache: Instruct the client not to cache content.

#
# Usage:
# - CustomResponseHeader -IISPath "IIS:\Sites\Padres" -ExpireCacheInDays 5
#	## Set the custom header to expire cache in 5 days on "IIS:\Sites\Padres"

# - CustomResponseHeader -IISPath "IIS:\Sites\Chargers" -ExpireCacheOnDate ((get-date).AddDays(15))
	## Sets the custom header to expire cache in 15 days from (Today) on "IIS:\Sites\Chargers"

# - CustomResponseHeader -IISPath "IIS:\Sites\CleIndians\Players" -DisableCache
	## Disable any header cache information for "IIS:\Sites\CleIndians\Players"

# - CustomResponseHeader -IISPath "IIS:\Sites\CleIndians\Players" -ClientNoCache
	## Instruct the client to not cache content for "IIS:\Sites\CleIndians\Players"

#>
# Revision History
# Version 1.0 - Initial Commit
#-------------------------------------------------------------------------

"@

	if ($PSBoundParameters.Count -lt 2) {
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to CustomResponseHeader"
		}
		throw
	}
	
try {
	Import-Module WebAdministration
} catch [Exception] {
	Write-Host "IIS need to be installed."
	if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: IIS need to be installed."
		}
	throw
}
	
	$SectionFilter = "system.webServer/staticContent"
	$CacheFilter = "system.webServer/staticContent/clientCache"
	
	$Mod = $false
	if ($ExpireCacheInDays) {
		$Now = Get-Date
		$Future = $Now.AddDays($ExpireCacheInDays)
		$TimeSpan = New-TimeSpan -Start $Now -End $Future
		try {
			Set-WebConfigurationProperty -PSPath $IISPath -filter $CacheFilter -Name "cacheControlMode" -Value "UseMaxAge"
			Set-WebConfigurationProperty -PSPath $IISPath -filter $CacheFilter -Name "cacheControlMaxAge" -Value $TimeSpan
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Successfully set custom response header UseMaxAge for `'$IISPath`'"
			}
		} catch [Exception] {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: There was an issues setting custom Response Header for `'$IISPath`'. $_"
			}
		}
	} elseif ($ExpireCacheOnDate) {
		try {
			Set-WebConfigurationProperty -PSPath $IISPath -filter $CacheFilter -Name "cacheControlMode" -Value "UseExpires"
			Set-WebConfigurationProperty -PSPath $IISPath -filter $CacheFilter -Name "httpExpires" -Value $ExpireCacheOnDate
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Successfully set custom response header UseExpires for `'$IISPath`'"
			}
		} catch [Exception] {
			if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: There was an issues setting custom Response Header for `'$IISPath`'. $_"
				}
		}
	} elseif ($DisableCache) {
		try {
			Set-WebConfigurationProperty -PSPath $IISPath -filter $CacheFilter -Name "cacheControlMode" -Value "NoControl"
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Successfully set custom response header NoControl for `'$IISPath`'"
			}
		} catch [Exception] {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: There was an issues setting custom Response Header for `'$IISPath`'. $_"
			}
		}
	} elseif ($ClientNoCache) {
		try {
			Set-WebConfigurationProperty -PSPath $IISPath -filter $CacheFilter -Name "cacheControlMode" -Value "DisableCache"
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Successfully set custom response header DisableCache for `'$IISPath`'"
			}
		} catch [Exception] {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: There was an issues setting custom Response Header for `'$IISPath`'. $_"
			}
		}
	}
	
}
