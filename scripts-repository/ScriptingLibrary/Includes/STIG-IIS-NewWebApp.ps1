function AddNewWebApp ([String]$Site, [String]$AppName, [String]$PhysicalPath, [String]$AppPool) {

$Usage = @"
#-------------------------------------------------------------------------
# Solution: AddNewWebApp
# Author: Sly Stewart 
# Updated: 8/1/2013
# Version: 1.0
<#
# Description: Add a new web app, really usefull when not converting an existing folder to a webapp.

- Mandatory Parameters
	[String]-Site: The IIS Site to create the webapp under.
	[String]-AppName: The WebApp's name.
	[String]-PhysicalPath: Physical path to this website.
	
-Optional Parameters
	[String]-AppPool: AppPool to create the website under. Website uses DefaultAppPool if an app pool is not specified.

#
# Usage:
# - AddNewWebApp -Site "SiteA" -AppName "WebApp2" -PhysicalPath "D:\WebApp2"
#	## Create a new WebApp named WebApp2 under SiteA with a physical path of "D:\WebApp2"

# - AddNewWebApp -Site "Default Web Site" -AppName "App23" -PhysicalPath "c:\Webz\App23" -AppPool "Dot Net 40"
#	## Create a new WebApp named "App23" under "Default Web Site" with a physical path of "c:\Webz\App23" using the "Dot Net 40" app pool.

#>
# Revision History
# Version 1.0 - Initial Commit - SS 8/1/2013
#-------------------------------------------------------------------------

"@

	if ($PSBoundParameters.Count -lt 3) {
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Required parameters were not passed to AddNewWebApp. Exiting."
		}
		throw "FAILURE:: Required parameters were not passed to AddNewWebApp. Exiting."
	}
	try {
		if (!(Get-Module -Name Webadministration)) {
			Import-Module Webadministration
		}
	} catch [Exception] {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: `"WebAdministration`" module could not be loaded! Exiting."
		}
		throw "`"WebAdministration`" module could not be loaded!"
	}
	
	if (!(Test-Path $PhysicalPath)) {
		$Quiet = New-Item -ItemType directory -Path $PhysicalPath -Force
	}
	if ($AppPool -ne $null) {
		try {
			$AP_ = dir "IIS:\AppPools\$AppPool" -ErrorAction SilentlyContinue
		} catch [Exception] {
			$AP_ = $null
		}
		if (!$AP_) {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: App Pool `"$AppPool`" does not exist. Exiting."
			}
			throw "App Pool `"$AppPool`" does not exist. Exiting."
		}
	}
	
	if (!(get-WebApplication -name $AppName)) {
		if (get-website -Name "$Site") {
			try {
				$WebAppParams = @{}
				$WebAppParams["Site"] = $Site
				$WebAppParams["Name"] = $AppName
				$WebAppParams["PhysicalPath"] = "$PhysicalPath"
				if ($AppPool -ne $null) {
					$WebAppParams["ApplicationPool"] = $AppPool
				}
				
				$WebApp = New-WebApplication @WebAppParams
			} catch [Exception] {
				Write-Host "Unable to create WebApp `'$AppName`'!!" -ForegroundColor Red -BackgroundColor White
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: Unable to create WebApp `'$AppName`'. $_"
				}
			}
			
			if ($WebApp) {
				Write-Host "New WebApp `'$AppName`' created successfully."
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "New WebApp `'$AppName`' created successfully."
				}
			}
		} else {
			Write-Host "WebApp `'$AppName`' parent website `'$Site`' does not exist!!" -ForegroundColor Red -BackgroundColor White
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: WebApp `'$AppName`' parent website `'$Site`' does not exist"
			}
		}
		
	} else {
		Write-Host "WebApp `'$AppName`' already exists!" -ForegroundColor Red -BackgroundColor White
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: WebApp `'$AppName`' already exists!"
		}
	}
}