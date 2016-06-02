$Usage = @"
#-------------------------------------------------------------------------
# Solution: Config-Octopus
# Author: Sly Stewart
# Updated: 2/25/2013
# Version: 1.0
<#
# Description:
- Configures the Octopus service.
	All of this work is taken from Amit Budhu <Amitraj.Budhu@bpiedu.com>, 
	Im just repackaging it for use in this script.

#
# Usage: 
		Config-Octopus -AgentDir <String> -AppDir <String> -ComPort <INT> -TrustKey <String> -TempCertDir <String>
	Mandatory Parameters:
		-AgentDir <String>: Directory where the agent is installed.
		-AppDir <String>: Directory will the Application is installed.
		-ComPort <INT>: The Server communication port.
		-TrustKey <String>: The trust key for the server.
		-TempCertDir <String>: The thumbprint storage directory, for use when registering the agent to server.

#>
# Revision History
# Version 1.0 - Initial Commit 
#-------------------------------------------------------------------------

"@
if ($Help) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	throw "Showing Help."
}

Function Config-Octopus {
	param([parameter(Mandatory=$true)][String]$AgentDir, `
	[parameter(Mandatory=$true)][String]$AppDir, `
	[parameter(Mandatory=$true)][Int]$ComPort, `
	[parameter(Mandatory=$true)][String]$TrustKey, `
	[parameter(Mandatory=$true)][String]$TempCertDir)
	
	if (Test-Path $AgentDir) {
		$HereNow = $pwd
		cd $AgentDir
		 .\Tentacle.exe configure --appdir="$AppDir" --port=$ComPort --trust=$TrustKey
		$NCE = .\Tentacle.exe new-certificate
		$TempCert = Join-Path $TempCertDir "OctopusCert.txt"
		if (test-path $TempCert) {
			rm $TempCert -Force
		}
		Add-Content $TempCert -Value $NCE
		.\Tentacle.exe install
		cd $HereNow
	} else {
		if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: Octopus Agent directory `'$AgentDir`' does not exist!"
			}
	}
}