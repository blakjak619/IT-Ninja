[regex]$IPv4Regex = "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}"

function pingMachine ( $address ) {
	$ping = gwmi Win32_PingStatus -Filter "Address='$address'"
	return $ping.StatusCode
}
function iSCSINetworkPresent {
param([string] $iSCSIPortalTargetIP)

    LLTraceMsg -InvocationInfo $MyInvocation

	# Calculate the subnet address for the iSCSI target
	#$Target_Mask = ConvertTo-Mask 
	# Verify that there is a separate NIC for the iSCSI communications
	$NIC_IP_List = Get-NetAdapter | Get-NetIPAddress | Select IPAddress,PrefixLength,SubnetMask,ifindex
	foreach ($NIC_IP in $NIC_IP_List){
        # Get the NIC name so we can identify the NIC to the user in messages
		$EffectedNIC = (Get-NetAdapter | Where-Object {$_.ifindex -eq $NIC_IP.ifindex}).ifName

		#Calculate the NIC subnet address
		if($NIC_IP.SubnetMask) {
			$NIC_Mask = $NIC_IP.SubnetMask
		} else {
			$NIC_Mask = ConvertTo-Mask $NIC_IP.PrefixLength
		}

		# If the resulting subnet mask isn't valid, well... Tell someone but allow the clustering to go on
		if(($IPv4Regex.match($NIC_Mask)).Success -eq $false){
			LLToLog -EventID $LLWARN -Text "Unable to get subnetmask from NIC $EffectedNIC"
		} else {
			#Calculate the NIC subnet address
            $NIC_SubAddress = Get-NetworkAddress -IPAddress $NIC_IP.IPAddress -SubnetMask $NIC_Mask
            $Portal_SubAddress = Get-NetworkAddress -IPAddress $iSCSIPortalTargetIP -SubnetMask $NIC_Mask
            if($NIC_SubAddress -eq $Portal_SubAddress){
                LLToLog -EventID $LLINFO -Text "NIC $EffectedNIC is the on the iSCSI subnet."
                return $true
            }
		}
	}
    return $false
}
function AttachiSCSIDisks {
param([string]$Target_IP)

	LLTraceMsg -InvocationInfo $MyInvocation

	if (isServer2012orLater) {
		try {
			# Is the Target_IP a valid IPv4 address?
			
			if( $IPv4Regex.match( $Target_IP).Success -ne $true){
				$errmsg = "The iSCSI Portal IP provided ($TargetIP) is not a valid IPv4 address."
				LLToLog -EventID $LLERROR -Text 
				throw $errmsg 
			}
			if(-not (iSCSINetworkPresent -iSCSIPortalTargetIP $Target_IP)) {
				LLToLog -EventID $LLWARN -Text "A dedicated NIC for the iSCSI communication was not found. Proceeding anyway."
			}
			New-IscsiTargetPortal -TargetPortalAddress $Target_IP
			$iScsiSession = (Get-IscsiTarget | Connect-IscsiTarget -IsPersistent $true)
			iSCSI_ImportAllTargets -Persistant $True
		} catch {

			$errmsg = "FAILURE:: Unable to attach iSCSI disks. Reason: $_.Exception"
			Write-Host $errmsg
			if ($LoginCheck) { ToLog -LogFile $LFName -EventID 1 -Text $errmsg }
		}
	} else {
		if ((pingMachine $Target_IP) -eq 0) {
			#Right now this is only going to work with windows 2008 R2 boxes.
			if (((gwmi Win32_OperatingSystem).Caption) -like "*Server*2008*") {

				if (Get-Command "iscsicli") {
					$Quiet = Set-Service "msiscsi" -StartupType "Automatic"
					$Quiet = Start-Service "msiscsi"
				
					try {
						$Output = Invoke-Expression "iscsicli.exe QAddTargetPortal $Target_IP"
						$LoginCheck = $Output | Select-String "operation completed successfully."
						if ($LoginCheck) {
							Write-Host "Successfully added the target portal `'$Target_IP`'"
							if ($LoggingCheck) {
								ToLog -LogFile $LFName -Text "Successfully added the target portal `'$Target_IP`'"
							}
						} elseif ($Output | Select-String "Failed.") {
							Write-Host "FAILURE:: There was an issue adding the target portal `'$Target_IP`'"
							Write-Host $Output
							if ($LoggingCheck) {
								ToLog -LogFile $LFName -Text "FAILURE:: There was an issue adding the target portal `'$Target_IP`' $_"
								ToLog -LogFile $LFName -Text $Output
							}
						}
					} catch [Exception] {
						Write-Host "FAILURE:: There was an issue adding the target portal `'$Target_IP`' $_"
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "FAILURE:: There was an issue adding the target portal `'$Target_IP`' $_"
						}
					}
				} else {
					Write-Host "FAILURE:: iscsicli command not found."
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: iscsicli command not found."
					}
				}
			} else {
				Write-Host "FAILURE:: Windows 2008 Server is the only supported OS."
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: Windows 2008 Server is the only supported OS."
				}
			}
		} else {
			Write-Host "FAILURE:: iSCSI Target Portal `'$Target_IP`' not found!"
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: iSCSI Target Portal `'$Target_IP`' not found!"
			}
		}
	}
}
function iSCSI_AddTargetPortal {
param([string]$Target_IP)
	LLTraceMsg -InvocationInfo $MyInvocation

	if ((pingMachine $Target_IP) -eq 0) {
		#Right now this is only going to work with windows 2008 R2 boxes.
		if (((gwmi Win32_OperatingSystem).Caption) -like "*Server*2008*") {

			if (Get-Command "iscsicli") {
				$Quiet = Set-Service "msiscsi" -StartupType "Automatic"
				$Quiet = Start-Service "msiscsi"
				
				try {
					$Output = Invoke-Expression "iscsicli.exe QAddTargetPortal $Target_IP"
					$LoginCheck = $Output | Select-String "operation completed successfully."
					if ($LoginCheck) {
						Write-Host "Successfully added the target portal `'$Target_IP`'"
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "Successfully added the target portal `'$Target_IP`'"
						}
					} elseif ($Output | Select-String "Failed.") {
						Write-Host "FAILURE:: There was an issue adding the target portal `'$Target_IP`'"
						Write-Host $Output
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "FAILURE:: There was an issue adding the target portal `'$Target_IP`' $_"
							ToLog -LogFile $LFName -Text $Output
						}
					}
				} catch [Exception] {
					Write-Host "FAILURE:: There was an issue adding the target portal `'$Target_IP`' $_"
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: There was an issue adding the target portal `'$Target_IP`' $_"
					}
				}
			} else {
				Write-Host "FAILURE:: iscsicli command not found."
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: iscsicli command not found."
				}
			}
		} else {
			Write-Host "FAILURE:: Windows 2008 Server is the only supported OS."
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: Windows 2008 Server is the only supported OS."
			}
		}
	} else {
		Write-Host "FAILURE:: iSCSI Target Portal `'$Target_IP`' not found!"
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: iSCSI Target Portal `'$Target_IP`' not found!"
		}
	}
}
function iSCSI_ImportAllTargets {
param([Bool]$Persistant)
	LLTraceMsg -InvocationInfo $MyInvocation

	if (((gwmi Win32_OperatingSystem).Caption) -like "*Server*2008*") {
		if (Get-Command "iscsicli") {
			$SVC_Check = Get-Service "msiscsi"
			if ($SVC_Check) {
				if (($SVC_Check).Status -eq "Stopped") {
					Start-Service "msiscsi"
				}
					$TList = Invoke-Expression "iscsicli ListTargets" | Select-String "iqn."
					if ($TList) {
						foreach ($iSCSI in $TList) {
							[string]$iString = $iSCSI 
							$iTarget = $iString.Replace(" ", "")
							try {
								$Output = Invoke-Expression "iscsicli QLoginTarget $iTarget"
								$LTCheck = $Output | Select-String "operation completed successfully."
								if ($LTCheck) {
									if ($LoggingCheck) {
										LLToLog -EventID $LLINFO -Text "$Output"
										LLToLog -EventID $LLINFO -Text "Successfully imported `'$iTarget`'"
									}
								} else {
									if ($LoggingCheck) {
										LLToLog -EventID $LLERROR -Text "FAILURE:: There was an issue logging into `'$iTarget`' $_"
										LLToLog -EventID $LLINFO -Text "$Output"
									}
								}
							} catch [Exception] {
								if ($LoggingCheck) {
									LLToLog -EventID $LLERROR -Text "FAILURE:: There was an issue logging into `'$iTarget`' $_"
								}
							}
							if ($Persistant) {
								try {
									$Output = Invoke-Expression "iscsicli PersistentLoginTarget $iTarget T * * * * * * * * * * * * * * * 0"
									$PTCheck = $Output | Select-String "operation completed successfully."
									if ($PTCheck) {
										if ($LoggingCheck) {
											LLToLog -EventID $LLINFO -Text "$Output"
											LLToLog -EventID $LLINFO -Text "Successfully set `'$iTarget`' to a Persistent Target."
										}
									} else {
										if ($LoggingCheck) {
											LLToLog -EventID $LLERROR -Text "FAILURE:: There was an issue setting `'$iTarget`' to Persistant status. $_"
											LLToLog -EventID $LLINFO -Text $Output
										}
									}
								} catch [Exception] {
									if ($LoggingCheck) {
										LLToLog -EventID $LLERROR -Text "FAILURE:: There was an issue setting `'$iTarget`' to Persistant status. $_"
									}
								}
							}
						}
					} else {
						if ($LoggingCheck) {
							LLToLog -EventID $LLERROR -Text "FAILURE:: No iSCSI Targets were found."
						}
					}
			} else {
				if ($LoggingCheck) {
					LLToLog -EventID $LLERROR -Text "FAILURE:: msiscsi service not found!"
				}
			}
			
		} else {
			if ($LoggingCheck) {
				LLToLog -EventID $LLERROR -Text "FAILURE:: iscsicli command not found."
			}
		}
	} else {
		if(isServer2012orLater){
			Get-Disk | Where-Object BusType -eq "iSCSI" | ForEach {
				LLToLog -EventID $LLINFO -Text "Processing iSCSI disk #$($_.Number)"
				$TgtNbr = $_.Number
				InitializeDisk -DiskID $TgtNbr
				PartitionAndFormatDisk -DiskID $TgtNbr
			}
		} else {
			if ($LoggingCheck) {
				LLToLog -EventID $LLERROR -Text "FAILURE:: Windows 2008 and 2012 Server is the only supported OS."
			}
		}
	}
}
function iSCSI_ImportSingleTarget {
param([bool]$Persistant, $iQN_String)
LLTraceMsg -InvocationInfo $MyInvocation

if (((gwmi Win32_OperatingSystem).Caption) -like "*Server*2008*") {
		if (Get-Command "iscsicli") {
			$SVC_Check = Get-Service "msiscsi"
			if ($SVC_Check) {
				if (($SVC_Check).Status -eq "Stopped") {
					Start-Service "msiscsi"
				}
				$TList = Invoke-Expression "iscsicli ListTargets" | Select-String "$iQN_String"
				if ($TList) {
					[string]$iString = $TList
					$iTarget = $iString.Replace(" ","")
					try {
						$Output = Invoke-Expression "iscsicli QLoginTarget $iTarget"
						$SCheck = $Output | Select-String "completed successfully."
						if ($SCheck) {
							Write-Host "Successfully imported `'$iTarget`'"
							if ($LoggingCheck) {
								ToLog -LogFile $LFName -Text "$Output"
								ToLog -LogFile $LFName -Text "Successfully imported `'$iTarget`'"
							}
						} else {
							$LoopCount = 0
							do {
								Start-Sleep -Seconds 2
								$Output = Invoke-Expression "iscsicli QLoginTarget $iTarget"
								$SCheck = $Output | Select-String "completed successfully."
								if ($SCheck) {
									Write-Host "Successfully imported `'$iTarget`'"
									if ($LoggingCheck) {
										ToLog -LogFile $LFName -Text "Successfully imported `'$iTarget`'"
									}
								}
								$LoopCount++
								Write-Host "Attempting to log into `'$iTarget`'. Try `# $LoopCount."
							} until (($SCheck) -or ($LoopCount -gt 4))
							
							if ((!$SCheck) -and ($LoopCount -gt 4)) {
								#Write this off as a failure. Present an error.
								Write-Host "FAILURE:: unable to log into `'$iTarget`'."
								if ($LoggingCheck) {
									ToLog -LogFile $LFName -Text "FAILURE:: unable to log into `'$iTarget`'."
									ToLog -LogFile $LFName -Text "$Output"
								}
							}
						}
						
					} catch [Exception] {
						Write-Host "FAILURE:: There was an issue logging into `'$iTarget`' $_"
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "FAILURE:: There was an issue logging into `'$iTarget`' $_"
						}
					}
					if ($Persistant) {
						try {
							$Output = Invoke-Expression "iscsicli PersistentLoginTarget $iTarget T * * * * * * * * * * * * * * * 0"
							$PersistantTargets = Invoke-Expression "iscsicli ListPersistentTargets"
							$PCheck = $PersistantTargets | Select-String "$iTarget"
							if ($PCheck) {
								Write-Host "Successfully set `'$iTarget`' to a Persistent Target."
								if ($LoggingCheck) {
									ToLog -LogFile $LFName -Text "Successfully set `'$iTarget`' to a Persistent Target."
								}
							} else {
								$LoopCount = 0
								do {
									Start-Sleep -Seconds 2
									$Output = Invoke-Expression "iscsicli PersistentLoginTarget $iTarget T * * * * * * * * * * * * * * * 0"
									$PersistantTargets = Invoke-Expression "iscsicli ListPersistentTargets"
									$PCheck = $PersistantTargets | Select-String "$iTarget"
									if ($PCheck) {
										Write-Host "Successfully made `'$iTarget`' persistant"
										if ($LoggingCheck) {
											ToLog -LogFile $LFName -Text "Successfully made `'$iTarget`' persistant"
										}
									}
									$LoopCount++
									Write-Host "Attempting to make `'$iTarget`' persistant. Try `# $LoopCount."
								} until (($PCheck) -or ($LoopCount -gt 4))
								
								if ((!$PCheck) -and ($LoopCount -gt 4)) {
									#Write this off as a failure. Present an error.
									Write-Host "FAILURE:: unable to make `'$iTarget`' persistant."
									if ($LoggingCheck) {
										ToLog -LogFile $LFName -Text "FAILURE:: unable to make `'$iTarget`' persistant."
										ToLog -LogFile $LFName -Text "$Output"
									}
								}
							}
							
						} catch [Exception] {
							Write-Host "FAILURE:: There was an issue setting `'$iTarget`' to Persistant status. $_"
							if ($LoggingCheck) {
								ToLog -LogFile $LFName -Text "FAILURE:: There was an issue setting `'$iTarget`' to Persistant status. $_"
							}
						}
					}
				} else {
					Write-Host " `"$iQN_String`" was not found. Printing a list of available iQN Targets..." -ForegroundColor Yellow -BackgroundColor Black
					Invoke-Expression "iscsicli ListTargets"
				}
				Start-Sleep -Seconds 2
			} else {
				Write-Host "FAILURE:: msiscsi service not found!"
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: msiscsi service not found!"
				}
			}
		} else {
			Write-Host "FAILURE:: iscsicli command not found."
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: iscsicli command not found."
			}
		}
} else {
	Write-Host "FAILURE:: Windows 2008 Server is the only supported OS."
	if ($LoggingCheck) {
		ToLog -LogFile $LFName -Text "FAILURE:: Windows 2008 Server is the only supported OS."
	}
}

}
function iSCSI_WriteDiskpartScript {
param([string]$DiskLabel = "iSCSI", [string]$ScriptFile, [string]$iQN, [string]$Action)
	LLTraceMsg -InvocationInfo $MyInvocation

	$DeviceID = (((gwmi -namespace ROOT\WMI -class "MSiSCSIInitiator_SessionClass") | ? {$_.TargetName -eq "$iQN"}).Devices | select LegacyName).LegacyName
	Write-Host "$DeviceID" -ForegroundColor Yellow
	if ($DeviceID) {
		$WMIDisk = gwmi Win32_DiskDrive | ? {$_.DeviceID -eq "$DeviceID"}
		$ID = $WMIDisk.Index
		if ($DiskLabel -eq "iSCSI") {
			$DL = $DiskLabel + $ID
		} else {
			$DL = $DiskLabel
		}
		if ($Action -eq "Join") {
		$Diskpart = @"
select disk $ID
online disk noerr
attributes disk clear readonly noerr
"@
		} else {
		$Diskpart = @"
select disk $ID
online disk noerr
attributes disk clear readonly noerr
convert gpt noerr
create partition primary noerr
format quick Label="$DL" noerr
"@
		}
		Add-Content $ScriptFile -Value $Diskpart
		$Diskpart
		$DiskOut = New-Object PSObject
		$DiskOut | Add-Member -MemberType NoteProperty -Name "Index" -Value $ID
		$DiskOut | Add-Member -MemberType NoteProperty -Name "Label" -Value $DL
		$DiskOut | Add-Member -MemberType NoteProperty -Name "iQN" -Value $iQN
		return $DiskOut
	}

}
<#
function iSCSI_WriteDiskpartJoin {
param([string]$DiskLabel = "iSCSI", [string]$ScriptFile, [string]$iQN)
	$DeviceID = (((gwmi -namespace ROOT\WMI -class "MSiSCSIInitiator_SessionClass") | ? {$_.TargetName -eq "$iQN"}).Devices | select LegacyName).LegacyName
	if ($DeviceID) {
		$WMIDisk = gwmi Win32_DiskDrive | ? {$_.DeviceID -eq "$DeviceID"}
		$ID = $WMIDisk.Index
		if ($DiskLabel -eq "iSCSI") {
			$DL = $DiskLabel + $ID
		} else {
			$DL = $DiskLabel
		}
		
		Add-Content $ScriptFile -Value $Diskpart
		$DiskOut = New-Object PSObject
		$DiskOut | Add-Member -MemberType NoteProperty -Name "Index" -Value $ID
		$DiskOut | Add-Member -MemberType NoteProperty -Name "Label" -Value $DL
		$DiskOut | Add-Member -MemberType NoteProperty -Name "iQN" -Value $iQN
		return $DiskOut
	}

}
#>
function DiskpartCommit {
param([String]$ScriptFile)
	LLTraceMsg -InvocationInfo $MyInvocation
	if (Test-Path $ScriptFile) {
		Add-Content "$ScriptFile" -Value "Exit"
		Invoke-Expression "Diskpart /s `'$ScriptFile`'"
		Start-Sleep -Seconds 2
	}
}
