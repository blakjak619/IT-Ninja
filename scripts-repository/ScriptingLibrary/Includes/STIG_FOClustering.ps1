
function pingIT($Target) {
	$Ping_status = (gwmi Win32_PingStatus -Filter "Address='$Target'").StatusCode
	return $Ping_Status		
}

function CheckWFORequirements {
	$ReqCheck = 0
	if (!(Get-Module "FailoverClusters")) {
		if (!(Get-Module -ListAvailable "FailoverClusters")) {
			Write-Host "FailoverClusters is not installed."
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: Failover Clusters is not installed"
			}
		} else {
			try {
				Import-Module "FailoverClusters"
				$ReqCheck = 1
			} catch [Exception] {
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: Failed to load Failover Clusters PSModule."
				}
			}
		}
	} else {
		$ReqCheck = 1
	}
	return $ReqCheck
}

function NewFOCluster {
param($ClusterName, $ClusterIP)

	$PreFlight = CheckWFORequirements
	
	if ($PreFlight -gt 0) {
		try {
			New-Cluster "$ClusterName" -StaticAddress "$ClusterIP"
			$ClusterCheck = get-cluster
			if ($ClusterCheck) {
				Write-Host "Successfully created `"$ClusterName`" Cluster."
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "Successfully created `"$ClusterName`" Cluster."
				}
			} else {
				Write-Host "FAILURE:: There was an issue creating the cluster! $_"
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: There was an issue creating the cluster! $_"
				}
			}
		} catch [Exception] {
			Write-Host "FAILURE:: There was an issue creating the cluster! $_"
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: There was an issue creating the cluster! $_"
			}
		}
	}
}

function AddDiskToFOCluster {
param($DiskLetter, $DiskName)
	$PreFlight = CheckWFORequirements
	
	if ($PreFlight -gt 0) {
		if (get-cluster) {
			if (Test-Path $DiskLetter) {
				if (Test-Path ".\DiskFile.txt") {
					$Quiet = rm ".\DiskFile.txt" -Force
				}
				$AllDisks = Get-ClusterAvailableDisk
				if ($AllDisks) {
					foreach ($ListDisk in $AllDisks) {
						$Check = $null
						$Partitions = $ListDisk.Partitions 
						$Partitions > ".\DiskFile.txt"
						$Check = gc ".\DiskFile.txt" | Select-String "$DiskLetter" | Select-String "Name"
						if ($Check) {
							$CDName = $ListDisk.Name
							Write-Host "Found `'$DiskLetter`' with Name `'$CDName`'. Adding it to the cluster."
							if ($LoggingCheck) {
								ToLog -LogFile $LFName -Text "Found `'$DiskLetter`' with Name `'$CDName`'. Adding it to the cluster."
							}
							try {
								Add-ClusterDisk $ListDisk
								Write-Host "Added `'$DiskLetter`' with Name `'$CDName`' to the cluster."
								if ($LoggingCheck) {
									ToLog -LogFile $LFName -Text "Added `'$DiskLetter`' with Name `'$CDName`' to the cluster."
								}
							} catch [Exception] {
								Write-Host "FAILURE:: There was an issue Adding `'$DiskLetter`' with Name `'$CDName`' to the cluster. $_"
								if ($LoggingCheck) {
									ToLog -LogFile $LFName -Text "FAILURE:: There was an issue Adding `'$DiskLetter`' with Name `'$CDName`' to the cluster. $_"
								}
							}
							
							if ($DiskName) {
								#Rename the Disk 
								try {
									(Get-ClusterResource "$CDName").Name = "$DiskName"
									Write-Host "Renamed `'$DiskLetter`' with Name `'$CDName`' to `'$DiskName`'."
									if ($LoggingCheck) {
										ToLog -LogFile $LFName -Text "Renamed `'$DiskLetter`' with Name `'$CDName`' to `'$DiskName`'."
									}
								} catch [Exception] {
									Write-Host "FAILURE:: There was an issue renaming `'$DiskLetter`' with Name `'$CDName`' to `'$DiskName`'. $_"
									if ($LoggingCheck) {
										ToLog -LogFile $LFName -Text "FAILURE:: There was an issue renaming `'$DiskLetter`' with Name `'$CDName`' to `'$DiskName`'. $_"
									}
								}
								
								#This is commented out because when i create the quorum this way
								#The quorum disk had issues failing over between nodes.
								#If the quorum disk was set manually (using the SAME disk)
								#we had no issues failing over the cluster.
								#Set the Quorum Disk
								<#
								switch ($DiskName) {
									"Quorum" {
										$QuorumState = ""
										do {
											Start-Sleep -Seconds 2
											Write-Host "Waiting for Quorum disk to come online..." -ForegroundColor Yellow -BackgroundColor Black
											$DiskResources = (get-ClusterResource | ? {$_.ResourceType -like "*Disk*"})
											$QuorumState = ($DiskResources | ? {$_.Name -eq "Quorum"}).State
										} until ($QuorumState -eq "Online")
										try {
											#$Quiet = Set-ClusterQuorum -NodeAndDiskMajority "Quorum"
											$Quiet = Set-ClusterQuorum -DiskOnly "Quorum"
											#$Quiet = Set-ClusterQuorum -NodeMajority
											#Write-Host "Cluster Quorum set."
											if ($LoggingCheck) {
											#	ToLog -LogFile $LFName -Text "Cluster Quorum set."
											}
										} catch [Exception] {
											Write-Host "FAILURE:: There was an issue setting the `'Quorum`' disk. $_"
											if ($LoggingCheck) {
												ToLog -LogFile $LFName -Text "FAILURE:: There was an issue setting the `'Quorum`' disk. $_"
											}
										}
									}
									
									default {	#Nothing to do here
									}
								}
								#>
								#Set the Disk Path
								try {
									get-ClusterResource "$DiskName" | Set-ClusterParameter -name "DiskPath" -value "$DiskLetter"
									Write-Host "Set the Disk Path successfully."
									if ($LoggingCheck) {
										ToLog -LogFile $LFName -Text "Set the Disk Path successfully."
									}
								} catch [Exception] {
									Write-Host "FAILURE:: There was an issue setting the Disk Path. $_"
									if ($LoggingCheck) {
										ToLog -LogFile $LFName -Text "FAILURE:: There was an issue setting the Disk Path. $_"
									}
								}
							}
							
						}
						
						if (Test-Path ".\DiskFile.txt") {
							$Quiet = rm ".\DiskFile.txt" -Force
						}
					}
				}
			} else {
				Write-Host "FAILURE:: Trying to add a disk to the cluster that does not exist. `'$DiskLetter`' Does not exist."
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: Trying to add a disk to the cluster that does not exist. `'$DiskLetter`' Does not exist."
				}
			}
			
		}
		
	}
}

function JoinFOCluster {
param($ClusterName, $NewNode)
	$PreFlight = CheckWFORequirements
	if ($PreFlight -gt 0) {
		if ((pingIT $NewNode) -eq 0) {
			try {
				Add-ClusterNode -Cluster $ClusterName -Name $NewNode
				Write-Host "Added `'$NewNode`' to `'$ClusterName`' Cluster."
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "Added `'$NewNode`' to `'$ClusterName`' Cluster."
				}
			} catch [Exception] {
				Write-Host "FAILURE:: There was an issue adding `'$NewNode`' to `'$ClusterName`' Cluster. $_"
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: There was an issue adding `'$NewNode`' to `'$ClusterName`' Cluster. $_"
				}
			}
		}
	}
}

function TestFOCluster {
	param($Nodes)
	$PreFlight = CheckWFORequirements
	if ($PreFlight -eq 1) {
		$TimeStamp = Get-Date -UFormat "%Y%m%d_%H%M%S"
		$ReportFolder = PWD
		$Name = "ClusterReport_$TimeStamp"
		$Report = Join-Path $ReportFolder $Name
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "Starting to test the Failover Cluster..."
		}
		try {
			$Quiet = Get-ClusterGroup "Available Storage" | Stop-ClusterGroup
			$Output = Test-Cluster -Node $Nodes -ReportName "$Report"
			Write-Host "Completed Testing cluster with node(s) `'$Nodes`'. Cluster Report copied to `'$Report`'"
			$Quiet = Get-ClusterGroup "Available Storage" | Start-ClusterGroup
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Completed Testing cluster with node(s) `'$Nodes`'. Cluster Report copied to `'$Report`'"
			}
		} catch [Exception] {
			Write-Host "FAILURE:: There was an issue testing the cluster. $_"
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: There was an issue testing the cluster. $_"
			}			
		}
	}	
}