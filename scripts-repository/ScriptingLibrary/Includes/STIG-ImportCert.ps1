
function ImportECert {

	param([String]$CertPath, [String]$CertRootStore = "LocalMachine", [String]$CertStore = "My", [String]$CertPass, [String]$SecurePass)

$Usage = @"
#-------------------------------------------------------------------------
# Solution: ImportECert
# Author: Sly Stewart 
# Updated: 3/18/2013
# Version: 1.0
<#
# Description: Imports a Pre-existing SSL cert file

- Mandatory Parameters
	[String]-CertPath <String>: Path to the SSL Cert file.
	
- Optional Parameters
	[String]-CertRootStore: The Root Certificate store. If not specified, defaults to "LocalMachine"
	[String]-CertStore: The Certificate sub-store. If not specified, defaults to "My".
	[String]-CertPass: Password for the certificate, in Clear text. Use "Prompt" if you want to be securely prompted for the password.
	[String]-SecurePass: Use a SecureString instead of a Clear Text password.

#
# Usage:
# - ImportECert -CertPath "C:\Temp\SDChargers.pfx" -SecurePass "7a00c04fc297eb01000000028122480d712e4bb7b0820"
#	## Import the SDChargers.pfx Cert with a secure password to the LocalMachine\My store

# - ImportECert -CertPath "D:\SDPadres.pfx" -CertPass "Prompt"
	## Import the D:\SDPadres.pfx cert file to the LocalMachine\My store, prompting the user for the password.

# - ImportECert -CertPath "C:\CleIndians.cer" -CertRootStore "CurrentUser"
	## Import the "C:\CleIndians.cer" cert file to the CurrentUser\My store, prompting the user for the password.

# - ImportECert -CertPath "C:\Server.pfx" -CertRootStore "CurrentUser" -CertStore "Remote Desktop" -CertPass "MySecretPassword"
	## Import the "C:\Server.pfx" into the "CurrentUser\Remote Desktop" Cert Store using the password "MySecretPassword".

#>
# Revision History
# Version 1.0 - Initial Commit
#-------------------------------------------------------------------------

"@
	if (Test-Path $CertPath) {
		$PFX = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2

		if ($CertPass -eq "Prompt") {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Prompting the user for cert password..."
			}
			$CertPrompt = Read-Host "Please enter the Cert password for `'$CertPath`'" -AsSecureString
		}
	if (!$SecurePass) {
		try {
			if ($CertPass) {
				if ($CertPass -eq "Prompt") {
					$PFX.Import($CertPath, $CertPrompt, "Exportable,PersistKeySet")	
				} else {
					$PFX.Import($CertPath, $CertPass, "Exportable,PersistKeySet")
				}
			} else {
				$PFX.Import($CertPath)
			}
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Successfully imported cert with password."
			}
		} catch [Exception] {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: Failed import cert with password. $_"
			}
		}
	} else {
		$TempSFile = "TempSFile"
		if (Test-Path $TempSFile) {
			rm $TempSFile -Force
		}
		Add-Content $TempSFile -Value $SecurePass
		$Secure = gc $TempSFile
		$SecureTX = $Secure | ConvertTo-SecureString
		try {
			$PFX.Import($CertPath, $SecureTX, "Exportable,PersistKeySet")
		} catch [Exception] {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: Failed import cert with SecureString. $_"
			}
		}
		rm $TempSFile -Force
	}
		if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "(CertStore: $CertStore, CertRootStore: $CertRootStore)"
			}
		$Store = New-Object System.Security.Cryptography.X509Certificates.X509Store($CertStore, $CertRootStore)
		$Store.Open("MaxAllowed")
		try {
			$Store.Add($PFX)
			$Store.Close()
		} catch [Exception] {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: Failed add cert. $_"
			}
		}
	} else {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: `'$CertPath`' does not exist."
		}
	}

}
