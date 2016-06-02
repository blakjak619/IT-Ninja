Function CreateWebSite {

	param([string]$Name, `
	[string]$PhysicalPath, `
	[string]$ApplicationPool, `
	[Parameter(ParameterSetName="S")][Bool]$SSL, `
	[Parameter(ParameterSetName="S")]$SSL_Cert, `
	[Parameter(ParameterSetName="S")]$SSL_IP, `
	[Parameter(ParameterSetName="S")]$SSL_Port)
$Usage = @"
#-------------------------------------------------------------------------
# Solution: CreateWebSite
# Author: Sly Stewart
# Updated: 12/07/2012
# Version: 1.1
<#
# Description:
- Creates a website, with the optional ability to attach to Application Pools, or use SSL Certs.
- Mandatory Parameters of [String]-Name and [String]-PhysicalPath

# Note on using the SSL Switch
# If -SSL $true is used, You must provide values for:
#	-SSL_Cert : Object generated from '`$MyCert = gci "Cert:\LocalMachine\MyCertLocation\" | ? {`$_.Subject -like "*MyPreviouslyGeneratedCert*" }'
#	-SSL_IP: "0.0.0.0" for All Unassigned, or another specific bound address.
#	-SSL_Port: Port SSL will be ran on. traditionally, "443".
#
#
# Usage:
# - CreateWebSite -Name "WebApp1" -PhysicalPath "C:\InetPub\WebApp1" -ApplicationPool "WebAppPool" -SSL $True -SSL_IP "0.0.0.0" -SSL_Port "443" -SSL_Cert $MyCert
	#Creates a website with the following properties:
	#	Name: WebApp1
	#	Physical Path: "C:\InetPub\WebApp1"
	#	Application Pool: "WebAppPool"
	#	SSL Enabled
	#	SSL IP: All Unassigned on Port 443
	#	Using SSL cert passed through `$MyCert
#
# - CreateWebSite -Name "WebApp2" -PhysicalPath "C:\InetPub\WebApp1"
#	#Create a basic website with the name "WebApp2" and PhysicalPath "C:\InetPub\WebApp1"

#>
# Revision History
# Version 1.0 - Initial Commit 
# Version 1.01 - Added provision to exit quietly if the website already exists. -SS
# Version 1.1 - Added a duplicate check for SSL binding address. -SS 3/20/2013
#-------------------------------------------------------------------------

"@

if ((!$Name) -or (!$PhysicalPath)) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	if ($LoggingCheck) {
		ToLog -LogFile $LFName -Text "FAILURE:: mandatory parameters not passed to CreateWebSite (Name or PhsicalPath)."
	}
	throw
}

if (($SSL) -and ((!$SSL_Cert) -or (!$SSL_IP) -or (!$SSL_Port))) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	if ($LoggingCheck) {
		ToLog -LogFile $LFName -Text "FAILURE:: mandatory parameters not passed to CreateWebSite (SSL, SSLCert, SSLIP, or SSLPort)."
	}
	throw
}

Import-Module WebAdministration
if (!(Test-Path "IIS:\Sites\$Name")) {	
	try {
			if (get-website -name "*") {
				New-Website -name "$Name" -force | Out-Null
			} else {
				New-Website -name "$Name" -id 1  -force | Out-Null
			}
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Base website `'$Name`' created."
			}
		} catch [Exception] {
			Write-Host "New Website creation failed for `'$Name`' Website. `n`n $_" -ForegroundColor Red -BackgroundColor White
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: New Website creation failed for `'$Name`' Website. $_"
			}
			throw
		}
		if (($PhysicalPath) -or ($ApplicationPool) -or ($SSL)) {
			$WebSite = Get-Item "IIS:\Sites\$Name"

			if ($PhysicalPath) {
				if (!(Test-Path $PhysicalPath)) {
					New-Item -ItemType Directory -Path "$PhysicalPath"
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "Created physical path `'$PhysicalPath`' for website `'$Name`'"
					}
				}
				try {
					$WebSite | Set-ItemProperty -Name "PhysicalPath" -Value "$PhysicalPath"
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "Physical path set for website `'$Name`'"
					}
				} catch [Exception] {
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: set Physical path failed for `'$Name`' Website. $_"
					}
				}
			}
			if ($ApplicationPool) {
				if (Get-Item "IIS:\AppPools\$ApplicationPool") {
					try {
						$WebSite | Set-ItemProperty -Name "ApplicationPool" -Value "$ApplicationPool"
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "AppPool `'$ApplicationPool`' set for website `'$Name`'"
						}
					} catch [Exception] {
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "FAILURE:: unable to set AppPool `'$ApplicationPool`' set for website `'$Name`'. $_"
						}
					}
				} else {
					Write-Host "Unable to set $Name ApplicationPool. $ApplicationPool Does not currently Exist." -ForegroundColor Red -BackgroundColor White
					if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "FAILURE:: Unable to set `'$Name`' ApplicationPool. `'$ApplicationPool`' Does not currently Exist."
					}
					throw
				}
			}
			if ($SSL) {
				try {
						cd IIS:\SslBindings
						$DupeCheck = dir | ? {(($_.IPAddress -eq "$SSL_IP") -and ($_.Port -eq $SSL_Port))}
						if (!$DupeCheck) {
							$SSL_Cert | New-Item $SSL_IP!$SSL_Port
							if ($LoggingCheck) {
								ToLog -LogFile $LFName -Text "Set SSL Binding for `'$Name`' successfully."
							}
							Pop-Location
						} else {
							if ($LoggingCheck) {
								ToLog -LogFile $LFName -Text "SSL Binding for `'$Name`' (IP: `'$SSL_IP`', Port: `'$SSL_Port`') already exists. Skipping."
							}
						}
				} catch [Exception] {
					Write-Host "There was an issue applying the SSL Cert to $Name. `n`n $_" -ForegroundColor Red -BackgroundColor White
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: Unable to set `'$Name`' SSL Binding (IP: `'$SSL_IP`', Port: `'$SSL_Port`')"
					}
				}
			}
		}
} else {
	if ($LoggingCheck) {
		ToLog -LogFile $LFName -Text "Website $Name already exists."
	}
}
}

