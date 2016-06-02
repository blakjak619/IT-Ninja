Function CreateIISCert {
	param ([string]$MakeCertPath, `
	[string]$CertName)
$Usage = @"
#-------------------------------------------------------------------------
# Solution: ConfigureDTCSec
# Author: Sly Stewart
# Updated: 12/07/2012
# Version: 1.01
<#
# Description:
- Creates a Self-Signed IIS SSL Cert in the Certificate store "cert:\LocalMachine\My"
	# Cert expires on "12/31/2039 11:59:59 GMT"
- Mandatory Parameters of [String]-MakeCertPath, [String]-CertName
	[String]-MakeCertPath: Full path to local Makecert.exe
	[String]-CertName: Cert canonical name

# Dependencies:
<#
		I'm using MAKECERT.exe to create the self signed cert. Makecert is part of the Windows SDK
		http://msdn.microsoft.com/en-us/windows/desktop/bb980924
		MAKECERT.exe will need to be copied locally in order to use with this script.
		#Makecert.exe switches:
		# http://msdn.microsoft.com/en-us/library/bfsktky3%28v=vs.110%29.aspx
#>
#
# Usage:
# - CreateIISCert -MakeCertPath "C:\Temp\Makecert.exe" -CertName "SSL-IISCert"
#	#Creates an SSL Cert named "SSL-IISCert" in the "cert:\LocalMachine\My" Certificate Store.

#>
# Revision History
# Version 1.0 - Initial Commit 
# Version 1.01 - Added a provision to skip creation if cert already exists. -SS
#-------------------------------------------------------------------------

"@
if ($PSBoundParameters.Count -eq 0) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	if ($LoggingCheck) {
		ToLog -LogFile $LFName -Text "FAILURE:: No parameters were passed to CreateIISCert."
	}
	throw
}

if ((!$MakeCertPath) -or (!$CertName)) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	if ($LoggingCheck) {
		ToLog -LogFile $LFName -Text "FAILURE:: Required parameters were not passed to CreateIISCert."
	}
	throw
}
if (!(gci "Cert:\LocalMachine\My\" | ? {$_.Subject -like "*$CertName*" })) {
		if (Test-Path $MakeCertPath) {
			try {
				Invoke-Expression "$MakeCertPath -r -pe -n `"CN=$CertName`" -eku 1.3.6.1.5.5.7.3.1 -ss my -sr LocalMachine -sky exchange -sp `"Microsoft RSA SChannel Cryptographic Provider`" -sy 12"
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "Created $CertName Successfully."
				}
			} catch [Exception] {
				Write-Host "Unable to create Self Signed SSL Cert! `n`n $_" -ForegroundColor Red -BackgroundColor White
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: Unable to create Self Signed SSL Cert `'$CertName`' `n $_"
				}
			}
		} else {
			Write-Host "Unable to create Self Signed SSL Cert! `n`n PATH Not Found: $MakeCertPath" -ForegroundColor Red -BackgroundColor White
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: Unable to create Self Signed SSL Cert! PATH Not Found: $MakeCertPath"
			}
		}
		#ToLog -LogFile $LogFile -LogText "Created $CertName Successfully."
	} else {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "SSL Cert `'$CertName`' already exists and is imported."
		}
	}
}