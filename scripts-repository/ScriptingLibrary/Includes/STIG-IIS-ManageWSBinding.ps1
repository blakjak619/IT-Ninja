Function ManageWSBinding {
	
	param([string]$WSName, `
	[Hashtable]$WSBindings, `
	[switch]$Remove)
$Usage = @"
#-------------------------------------------------------------------------
# Solution: ManageWSBinding
# Author: Sly Stewart
# Updated: 12/07/2012
# Version: 1.0
<#
# Description:
- Creates or delete an IIS Website Binding. Website Name CAN NOT contain any spaces.
- Mandatory Parameters of [String]-WSName, [Hashtable]-WSBindings
- Optional Parameter of [Switch]-Remove to remove a binding instead of the default add.

# Important notes on using the Hashtable format for Binding Definitions:
<#
	 -WSBindings needs to be a hashtable with the following keys.
	 `$WebBinding = @{} 
	 `$WebBinding.Add("Type", "")
	 #"http" | "https"| "net.tcp" | "net.pipe" | "net.msmq" | "msmq.formatname"
	 #If the type is not http/https we add that into enabled protocols.
	 `$WebBinding.Add("IPAddress", "")
	 # "*" for "All Unassigned", or a specific IP Address to bind to.
	 `$WebBinding.Add("Port", )
	 `$WebBinding.Add("HostName", "")
	 #Input a value to use a Host Header for this binding.
	 		-OR-
	 `$WebBinding = @{"Type"="https";"IPAddress"="*";"Port"="443";"HostName"=""}
	 
#>
# Dependencies:
# This relies on APPCMD Being in the default location. AppCmd.exe is part of the IIS install.
	## C:\Windows\System32\inetsrv\appcmd.exe
#
# Usage:
#	`$BindHash = @{"Type"="https";"IPAddress"="*";"Port"="443";"HostName"=""}
#	AddWSBinding -WSName "SSLWebApp" -WSBindings $BindHash
#	## Create an HTTPS Binding on port 443 for the Website "SSLWebApp"

#	
#	`$RHash = @{"Type"="http";"IPAddress"="*";"Port"=80;"HostName"=""}
#	AddWSBinding -WSName "WebApp2" -WSBindings $RHash -Remove
#	##Remove binding for WebApp2 on port 80


#	
#	`$HHash = @{"Type"="http";"IPAddress"="*";"Port"=80;"HostName"="www.webapp3.com"}
#	AddWSBinding -WSName "WebApp3" -WSBindings $HHash
#	##Add binding for "WebApp3" Website on port 80 using a Host Header of "www.webapp3.com"

#	`$HHash = @{"Type"="net.msmq";"IPAddress"="";"Port"=;"HostName"="";bindingInfo="msmq-info"}
#	AddWSBinding -WSName "WebApp4" -WSBindings $HHash
#	##Add net.msmq binding for "WebApp4" Website using binding info of "msmq-info"

#>
# Revision History
# Version 1.0 - Initial Commit 
# Version 1.01 - Added provision to exit quietly if the binding already exists. -SS
# Version 1.03 - Added in a provision on the bindings for non-http* protocols to handle the bindingInformation.
# Version 1.1 - Changed the addition of protocols into a seperate function libray "STIG-IIS-ADVSettinigs.ps1". This script now uses that libray for enabling new protocols.
#-------------------------------------------------------------------------

"@

if ((!$WSName) -or (!$WSBindings)) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	throw
}
		$ValidProtocols = @{"http"=0; "https"=0; "net.tcp"=0; "net.pipe"=0; "net.msmq"=0; "msmq.formatname"=0}
		if ($WSName | select-string " ") {
			write-host 'Param $WSName can not contain any spaces for the configuration of Bindings!!' -ForegroundColor Red -BackgroundColor White
			write-host "Binding configuration of $WSName Failed!!" -ForegroundColor Red -BackgroundColor White
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: Binding configuration of `'$WSName`' Failed!! Website Name can not contain any spaces. Exiting"
			}
			throw
		}
		try {
				
				$BType = $WSBindings["Type"]
				$BIP = $WSBindings["IPAddress"]
				$BPort = $WSBindings["Port"]
				$BHost = $WSBindings["HostName"]
				$BBinding = $WSBindings["bindingInfo"]
				$WSPath = "IIS:\Sites\$WSName"
				
				if (!($ValidProtocols.ContainsKey($BType))) {
					write-host "Binding protocol `'$BType`' is not valid!! `n Binding Failed!" -ForegroundColor Red -BackgroundColor White
					Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: Binding protocol `'$BType`' is not valid!! Binding Failed!. Exiting"
					}
					throw
				}
				
				#If the type is not http/https we will need to add that into enabled protocols
				if (!($BType | select-string "http")) {
					if (!$Remove) {
						#Added functionality from STIG-IIS-ADVSettinigs.ps1
						alterEnabledProto -Action "Add" -IISPath $WSPath -Protocol $BType
					}
				}
	<#			
	This is commented out because its not appending new bindings.
	It replaces the previous binding configuration with the new.
				if (!($BHost -eq "")) {
					$WSSite | Set-ItemProperty -Name "Bindings" -Value @{protocol="$BType";bindinginformation="$BIP:$BPort:$BHost"}
				} else {
					$WSSite | Set-ItemProperty -Name "Bindings" -Value @{protocol="$BType";bindinginformation="$BIP:$BPort:"}
				}
	#>

	## This relies on APPCMD Being in the default location.
	## C:\Windows\System32\inetsrv\appcmd.exe
	## THIS WILL NOT WORK WITH SITE NAMES WITH SPACES!!
	## AppCMD will not run here correctly within Powershell.
	## Quoting $WSName to handle spaces will not work as desired (using IIS 7.5's appcmd.exe)
	Set-Location "IIS:\Sites"
	if ($BType | Select-String "http") {
		$HTTP = $true
		$SiteExist = Get-WebBinding -name $WSName | ? {$_.protocol -eq "$BType" -and $_.BindingInformation -eq "$BIP`:$BPort`:$BHost"}
	} else {
		$HTTP = $false
		$SiteExist = Get-WebBinding -name $WSName | ? {$_.protocol -eq "$BType" -and $_.BindingInformation -eq "$BBinding"}
	}
				if (Test-Path "C:\Windows\System32\inetsrv\appcmd.exe") {
					if (!$Remove) {
						#If there is already a matching binding on that port, do nothing.
						if (!(Get-Module -ListAvailable -name WebAdministration)) {
						if ($LoggingCheck) {
								ToLog -LogFile $LFName -Text "FAILURE:: IIS Is not installed! Exiting."
							}
							throw "IIS is required!"							
						} else {
							Import-Module WebAdministration | Out-Null
						}
						
						if (!$SiteExist) {
							if ($HTTP) {
								try {
									Invoke-Expression "cmd.exe /C `"C:\Windows\System32\inetsrv\appcmd.exe set site $WSName /+bindings.[protocol=`'$BType`',bindingInformation=`'$BIP`:$BPort`:$BHost`']`""
									if ($LoggingCheck) {
										ToLog -LogFile $LFName -Text "Successfully set binding information on `'$WSName`' : [protocol=`'$BType`',bindingInformation=`'$BIP`:$BPort`:$BHost`'] "
									}
								} catch [Exception] {
									if ($LoggingCheck) {
										ToLog -LogFile $LFName -Text "FAILURE:: There was an issue setting binding information on `'$WSName`' : [protocol=`'$BType`',bindingInformation=`'$BIP`:$BPort`:$BHost`'] "
									}
								}
							} else {
								try {
									Invoke-Expression "cmd.exe /C `"C:\Windows\System32\inetsrv\appcmd.exe set site $WSName /+bindings.[protocol=`'$BType`',bindingInformation=`'$BBinding`']`""
								if ($LoggingCheck) {
										ToLog -LogFile $LFName -Text "Successfully set binding information on `'$WSName`' : [protocol=`'$BType`',bindingInformation=`'$BBinding`'] "
									}
								} catch [Exception] {
									if ($LoggingCheck) {
										ToLog -LogFile $LFName -Text "FAILURE:: There was an issue setting binding information on `'$WSName`' : [protocol=`'$BType`',bindingInformation=`'$BBinding`'] "
									}
								}
							}
						}
					} else {
						if ($SiteExist) {
							if ($HTTP) {
								try {
									Invoke-Expression "cmd.exe /C `"C:\Windows\System32\inetsrv\appcmd.exe set site $WSName /-bindings.[protocol=`'$BType`',bindingInformation=`'$BIP`:$BPort`:$BHost`']`""
								if ($LoggingCheck) {
										ToLog -LogFile $LFName -Text "Successfully removed binding information on `'$WSName`' : [protocol=`'$BType`',bindingInformation=`'$BIP`:$BPort`:$BHost`'] "
									}
								} catch [Exception] {
									if ($LoggingCheck) {
										ToLog -LogFile $LFName -Text "FAILURE:: There was an issue removing binding information on `'$WSName`' : [protocol=`'$BType`',bindingInformation=`'$BIP`:$BPort`:$BHost`'] "
									}
								}
							} else {
								try {
									Invoke-Expression "cmd.exe /C `"C:\Windows\System32\inetsrv\appcmd.exe set site $WSName /-bindings.[protocol=`'$BType`',bindingInformation=`'$BBinding`']`""	
								if ($LoggingCheck) {
										ToLog -LogFile $LFName -Text "Successfully removed binding information on `'$WSName`' : [protocol=`'$BType`',bindingInformation=`'$BBinding`'] "
									}
								} catch [Exception] {
									if ($LoggingCheck) {
										ToLog -LogFile $LFName -Text "FAILURE:: There was an issue removing binding information on `'$WSName`' : [protocol=`'$BType`',bindingInformation=`'$BBinding`'] "
									}
								}
							}
						}
					}
				} else {
					##AppCMD cant be found!
					write-host "appcmd was not found in `"C:\Windows\System32\inetsrv\`". Unable to set bindings for $WSName!"
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: appcmd was not found in `'C:\Windows\System32\inetsrv\`'. Unable to set bindings for `'$WSName`'!"
					}
					throw
				}
			} catch [Exception] {
				#There was a problem setting the bindings...
				Write-Host "There was a problem setting the bindings for `'$WSName`' Website. `n`n $_" -ForegroundColor Red -BackgroundColor White
				Write-Host "Binding Parameters passed:"
				if ($WSBindings) {
					foreach ($WSB in ($WSBindings.Keys)) {
						$Value = $WSBindings["$WSB"]
						Write-Host "Key: `'$WSB`', Value: `'$Value`'"
					}
				}
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: There was a problem setting the bindings for `'$WSName`' Website. $_"
					ToLog -LogFile $LFName -Text "Binding Parameters passed:"
					if ($WSBindings) {
						foreach ($WSB in ($WSBindings.Keys)) {
							$Value = $WSBindings["$WSB"]
							ToLog -LogFile $LFName -Text "Key: `'$WSB`', Value: `'$Value`'"
						}
					}
				}
				throw
			}

	}
