Function DoXMLScriptOrder {
param(
	[xml]$XMLParams
)
#region Setup Temp Path
	if ($BinServer -ne "") {
		$TempFldrN = $XMLParams.params.Folders.Temp
		$TempFldrPath = Join-Path $ScriptPath $TempFldrN
		if (!(Test-Path $TempFldrPath)) {
			New-Item -ItemType Directory -Path $TempFldrPath | Out-Null
		}
	}
#endregion
#region LocalRights
	#Sets Local Rights
	$Rights = $XMLParams.params.LocalRights
	if ($Rights) {
		foreach($RightSetting in $Rights) {
			$Action = $RightSetting.Action.ToLower()
			$User = $RightSetting.User
			$Right = $RightSetting.Right
			switch ($Action) {
				"add"    { AddAccountPolicy    -account $User -right $Right }
				"remove" { RemoveAccountPolicy -account $User -right $Right }
				default  { if ($LoggingCheck) {ToLog -LogFile $LFName -EventID $WARNING -Text "Action $Action not support for LocalRights"} }
			}
		}
	}
#endregion
#region EnvVars
	#Sets local or system environment variables
	$EnvVars = $XMLParams.params.EnvVars
	if ($EnvVars) { Process-EnvVarNode $Activity }
#endregion
#region Bindependency.File
	#Copy any dependencies to the machine before anything else is done.
	$BinDepFiles = $XMLParams.params.Bindependency.File | ? {$_.Action -eq "Add" -or $_.Action -eq "Execute"}
	if ($BinDepFiles) {
		foreach ($File in $BinDepFiles) {
			$PBR = $File.PathFromBinRoot
			$ExPath = Join-Path $BinServer $PBR
			$LocFile = $File.Name
			$LocPath = Join-Path $TempFldrPath $LocFile
			try {
				copy -Path "$ExPath" -Destination "$LocPath"
				if (!(Test-Path $LocPath)) {
					throw "Required File `'$LocPath`' is missing!"
				} else {
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "Copied `'$LocPath`' Locally."
					}
					if ($File.Action -eq "Execute") {
						ProcessLauncher($File)
								}
							}
			} catch [Exception] {
				if ($LoggingCheck) {ToLog -LogFile $LFName -Text "$_.Exception"}
				$ErrMsg = "There is an issue copying a required file! `n $_"
				Throw $ErrMsg
			}
		}
	}
#endregion
#region Bindependency.Folder
	$BinDepFolders = $XMLParams.params.Bindependency.Folder | ? {$_.Action -eq "Add" }
	if ($BinDepFolders) {
		foreach ($Folder in $BinDepFolders) {
			ProcessFolderActions -FolderInfo $Folder
		}
	}
#endregion
#region DirectAttached
	#From STIG-DirectAttachedDisks.ps1
	#If directed, format and partition any BLANK direct attached drives.
	#Labels the drives disk0, disk1, etc. based on index.
	#If you havef a c:\ drive already, then the first drive will be named
	#disk1
	$DirectAttachedNode = $XMLParams.params.Volume.DirectAttached
	if ($DirectAttachedNode) {
		$FormatAndPartDisk_Str = $DirectAttachedNode.FormatAndPartitionDisks
		if ($FormatAndPartDisk_Str -eq "True") {
			$DiskFormatParams = @{}
			$Disk_AlignInt = $DirectAttachedNode.Alignment
			if (($Disk_AlignInt -ne "") -or ($Disk_AlignInt -ne $null)) {
				$DiskFormatParams["Alignment"] = $Disk_AlignInt
			}
			
			$Disk_BlockStr = $DirectAttachedNode.BlockSize
			if (($Disk_BlockStr -ne "") -or ($Disk_BlockStr -ne $null)) {
				$DiskFormatParams["BlockSize"] = $Disk_BlockStr
			}
			
			FormatAndPartitionAllBlankDisks @DiskFormatParams
		}
	}
#endregion
#region Volume.CDROM
	#Move any volumes around FIRST, such as the cdrom...
	$CDROM_Moves = $XMLParams.params.Volume.CDROM | ? {$_.Action -eq "MoveFirst"}
	if ($CDROM_Moves) {
		foreach ($CDROM in $CDROM_Moves) {
			$CDConditional = $CDROM.MoveIf
			if ($CDConditional) {
				$CDRCheck = gwmi Win32_Volume | ? {($_.DriveType -eq 5) -and ($_.DriveLetter -eq "$CDConditional")}
				if ($CDRCheck) {
					[String]$FNextLetter = NextOpenDL
					ReLocDisk -DriveLetter $CDConditional -NewLetter $FNextLetter
				}
			}
			
		}
	}
#endregion
#region Volume.Part MoveFirst
	$FirstMove = $XMLParams.params.Volume.Part | ? {$_.Action -eq "MoveFirst"}
	if ($FirstMove) {
		foreach ($Partition in $FirstMove) {
			$FPLabel = $Partition.Label
			$FPC_Lett = $Partition.CurrentLetter
			$FPN_Lett = $Partition.NewLetter
			
			if ($FPN_Lett -eq "NextAvailable") {
				if ($FPC_Lett) {
					[String]$FNextLetter = NextOpenDL
					ReLocDisk -DriveLetter $FPC_Lett -NewLetter $FNextLetter
				} elseif ($PLabel) {
					[String]$FNextLetter = NextOpenDL
					ReLocDisk -ILabel $FPLabel -NewLetter $FNextLetter
				}
			} else {
				if ($FPC_Lett) {
					ReLocDisk -DriveLetter $FPC_Lett -NewLetter $FPN_Lett
				} elseif ($FPLabel) {
					ReLocDisk -ILabel $FPLabel -NewLetter $FPN_Lett
				}
			}
		}
	}
#endregion
#region Volume.iSCSI
	#Import iSCSI Disks...
	$iSCSI_XMLNode = $XMLParams.params.Volume.iSCSI	
	if ($iSCSI_XMLNode) {
		$PortalIP = $null
		if (isServer2012orLater) {
			$PortalIP = $iSCSI_XMLNode.Portal.Address
			if ($PortalIP) {
				AttachiSCSIDisks -Target_IP "$PortalIP"
			}
		} else {
			$LCName = $Env:COMPUTERNAME
			$SkipDiskClean = $false
			#Will these disks be used in a failover cluster.
			#Check to see if the FailoverClustering XML node is present.
			$FOClust_XMLNode = $XMLParams.params.FailoverClustering.Cluster
			if ($FOClust_XMLNode) {
				$LXNode = $FOClust_XMLNode.Nodes.Node | ? {$_.NodeName -eq "$LCName"}
				$LocalAction = $LXNode.Action
				if ($LocalAction -eq "Join") {
					$SkipDiskClean = $true
				}
			
				#Looking to see that the cluster service / a cluster is not already created.
				#If it is, we are running this a second time on the same server which probably
				#means we are trying to join other nodes to the cluster.
				try {
					if (Get-Service "ClusSvc" -ErrorAction SilentlyContinue) {
						$ClusSvc = Get-Service "ClusSvc" -ErrorAction SilentlyContinue
						if ((($ClusSvc).Status) -eq "Running") {
							Import-Module failoverclusters
							$ClusterCheck = get-cluster
						} else {
							$ClusterCheck = $null
						}
					} else {
						$ClusterCheck = $null
					}
				} catch [Exception] {
					$ClusterCheck = $null
				}
			}
			if (!$ClusterCheck) {
				$iSCSI_Portals = $iSCSI_XMLNode.Portal
				foreach ($PortalNode in $iSCSI_Portals) {
					$iSCSI_PortalAddress = $PortalNode.Address
					if ($iSCSI_PortalAddress) {
						# Add the iSCSI target
						iSCSI_AddTargetPortal -Target_IP $iSCSI_PortalAddress
						$AllLuns = $PortalNode.LUN | ? {$_.Action -eq "Add"}
						if ($AllLuns) {
							$Disks = @()
							$DiskpartScrpt = Join-path $ScriptPath "DPScrpt"
							foreach ($XML_LUN in $AllLuns) {
								$Lun_Parameters = @{}
								$iQN = $XML_LUN.iQN
								if ($iQN) {
									$Lun_Parameters["iQN_String"] = $iQN
									$PersistantStr = $XML_LUN.Persistant
									if ($PersistantStr) {
										$PersistantDisk = [System.Convert]::ToBoolean($PersistantStr)
									} else {
										$PersistantDisk = $false
									}
									$Lun_Parameters["Persistant"] = $PersistantDisk
									#Import a single LUN at a time.
									iSCSI_ImportSingleTarget @Lun_Parameters
								
									#Online the Disk / Format / Partition, but only if we are creating a new cluster.
												
									$OFP_Params = @{}
									$Disk_Label = $XML_LUN.Label
									if ($Disk_Label) {
										$OFP_Params["DiskLabel"] = $Disk_Label
									}
									$OFP_Params["iQN"] = $iQN
								
									$OFP_Params["ScriptFile"] = $DiskpartScrpt
									$OFP_Params["Action"] = $LocalAction
								
									$DiskInfo = iSCSI_WriteDiskpartScript @OFP_Params
									$Disks += $DiskInfo
							
								}
							}
							#Disk Clean should only be done on the first server that creates the cluster.
							#and imports the disks.
							if (!$SkipDiskClean) {
								DiskpartCommit -ScriptFile $DiskpartScrpt
								##
								if ($Disks) {
									foreach ($DiskData in $Disks) {
										[String]$FinalLabel = $DiskData.Label
										$DiskiQN = $DiskData.iQN
										$XMLDrive = $AllLuns | ? {$_.iQN -eq "$DiskiQN"}
										$FinalLetter = $XMLDrive.DriveLetter
										if ($FinalLetter) {
											if ($FinalLetter -ne "") {
												# Change the drive letter to something the user wants.
												ReLocDisk -ILabel "$FinalLabel" -NewLetter $FinalLetter
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
#endregion
#region Volume.Part Relocate
	#Re Address any drives if needed.
	$DriveMove = $XMLParams.params.Volume.Part | ? {$_.Action -eq "Relocate"}
	if ($DriveMove) {
		foreach ($Partition in $DriveMove) {
			$PLabel = $Partition.Label
			$PC_Lett = $Partition.CurrentLetter
			$PN_Lett = $Partition.NewLetter
			
			if ($PN_Lett -eq "NextAvailable") {
				if ($PC_Lett) {
					[String]$NextLetter = NextOpenDL
					ReLocDisk -DriveLetter $PC_Lett -NewLetter $NextLetter
				} elseif ($PLabel) {
					[String]$NextLetter = NextOpenDL
					ReLocDisk -ILabel $PLabel -NewLetter $NextLetter
				}
			} else {
				if ($PC_Lett) {
					ReLocDisk -DriveLetter $PC_Lett -NewLetter $PN_Lett
				} elseif ($PLabel) {
					ReLocDisk -ILabel $PLabel -NewLetter $PN_Lett
				}
			}
		}
	}
#endregion
#region Filesystem
#region Filesystem.Folders
	#Folder Actions

	$FolderActions = $XMLParams.params.FileSystem.Folders.Item
	if ($FolderActions) {
		$DFolders = $FolderActions | ? {$_.Action -eq "Delete"}
		if ($DFolders) {
			foreach ($item in $DFolders) {
				$DPath = $item.Path
				if (Test-Path $DPath) {
					try {
						$Quiet = Remove-Item $DPath -Force
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "Successfully removed `'$DPath`' Folder."
						}
					} catch [Exception] {
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "FAILURE:: There was an issue removing `'$DPath`' Folder $_"
						}
					}
				}
			}
		}
		
		$CFolders = $FolderActions | Where-Object {$_.Action -eq "Add"}
		if ($CFolders) {
			foreach ($item in $CFolders) {
				$CPath = $item.Path
				if (!(Test-Path $CPath)) {
					try {
						$Quiet = New-Item -ItemType "Directory" -Path $CPath -Force
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "Successfully added `'$CPath`' Folder."
						}
					} catch [Exception] {
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "FAILURE:: There was an issue adding `'$CPath`' Folder $_"
						}
					}
				}
			}
		}
	}
#endregion
#region Filesystem Files
	$FileActions = $XMLParams.params.FileSystem.File
	foreach($File in $FileActions){
		ParseFileXML -FileNode $File
	}
#endregion

#region .Net 1.1
	#Check to see if .net 1.1 needs to be installed.
	$Net11Check = $BinDepFiles | Where-Object {$_.Name -eq "NetFx64.exe"}
	if ($NET11Check){
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text ".NET11 is requested to install."
		}
		if (!(gwmi Win32_Product | ? {$_.name -like "*Net*1.1*"})) {
			if ($LoggingCheck) { ToLog -LogFile $LFName -Text ".NET1.1 was not found, and will install." }
			$CArgs = $NET11Check.Argument
			$BinName = $NET11Check.Name
			if ($CArgs) {
				$CLA = ""
				foreach ($argu in $CArgs) {
					$CoA = $argu
					if ($CoA -eq "/Package %:PACKAGELOCALPATH%") {
						$PakPath = Join-Path $TempFldrPath $BinName
						$CoA = $CoA.Replace("/Package %:PACKAGELOCALPATH%", "/Package `'$PakPath`'")
					}
					$CLA += $CoA + " "
				}
				$CLA = $CLA.TrimEnd(" ")
			}
			LaunchProcessAndWait -Destination $TempFldrPath -FileName $BinName -CommandLineArgs "$CLA"
		} else {
			if ($LoggingCheck) { ToLog -LogFile $LFName -Text ".NET 1.1 is already installed" }
		}
	}
#endregion
#region ServerManager
	#Add MS Features for includeAllSubFeature
	$FeatureList = $XMLParams.params.ServerManager.includeAllSubFeature.feature
	AddMSFeatures -FeatureList $FeatureList -IncludeAllSub
    
	
	#Add MS Individual Features
	AddMSFeatures -FeatureList $XMLParams.params.ServerManager.Single.feature

    ########################
    ## Feature Validation ##   
    ########################

    #MSMQ Directory Services check
    $MSMQ_DS_Check_Single = $XMLParams.params.ServerManager.Single.feature | ? {$_ -contains "MSMQ-Directory" }
    $MSMQ_DS_Check_All    = $XMLParams.params.ServerManager.includeAllSubFeature.feature | ? {$_ -contains "MSMQ" }
    if ( $MSMQ_DS_Check_Single -or $MSMQ_DS_Check_All ) {
        VerifyMSMQDS
    }
#endregion
#region IISAdvLogging
	#Check to see if IISAdvancedLogging.msi needs to be installed
	$IISAdvLog = $BinDepFiles | Where-Object {$_.Name -eq "AdvancedLogging64.msi"}
	if ($IISAdvLog) {
		if ($LoggingCheck) { ToLog -LogFile $LFName -EventID 2 -Text "IISAdvancedLogging.msi is requested to be installed" }
		if (!(gwmi Win32_Product | Where-Object {$_.name -like "*IIS Advanced Logging*"})) {
			if ($LoggingCheck) { ToLog -LogFile $LFName -Text "IISAdvancedLogging.msi was not found, and will install." }
			$CArgs = $IISAdvLog.Argument
			$BinName = $IISAdvLog.Name
			if ($CArgs) {
				$CLA = ""
				foreach ($argu in $CArgs) {
					$CoA = $argu
					if ($CoA -eq "/Package %:PACKAGELOCALPATH%") {
						$PakPath = Join-Path $TempFldrPath $BinName
						$CoA = $CoA.Replace("/Package %:PACKAGELOCALPATH%", "/Package `"$PakPath`"")
					}
					$CLA += $CoA + " "
				}
				$CLA = $CLA.TrimEnd(" ")
			}
			LaunchProcessAndWait -Destination $TempFldrPath -FileName $BinName -CommandLineArgs "$CLA"
		} else {
			if ($LoggingCheck) { ToLog -LogFile $LFName -Text "IISAdvancedLogging.msi is already installed" }
		}
	}
#endregion
#region WindowsFirewall.Form
	$WinFirewallStateCh = $XMLParams.params.WindowsFirewall.Form
	if ($WinFirewallStateCh) {
		foreach ($WFStateChange in $WinFirewallStateCh) {
			$WFEnabled = $WFStateChange.State
			$WFProfileContext = $WFStateChange.Profile
			try {
				IO-WinFW -State $WFEnabled -FWProfile $WFProfileContext
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "Made firewall changes (Enabled: $WFEnabled, Profile: $WFProfileContext)"
				}
			} catch [Exception] {
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: There was an issue setting the firewall. $_"
				}
			}
		}
	}
#endregion
#region Cluster
	$ClusterReqd = $XMLParams.params.Cluster
	if ($ClusterReqd) {
		$ClusName = $ClusterReqd.Name
		$ClusIP = $ClusterReqd.IP
		$ClusNodes = $ClusterReqd.Node.List

		if(CurrentNodeIsFirstNode -NodeList $ClusNodes){
			if(ClusterValidation -ClusterNodes $ClusNodes){
				CreateCluster
			} else {
				JoinCluster
			}
		}
	}
#endregion
#region FailoverClustering.Cluster
	#Windows failover clustering.
	$FOCluster_XML = $XMLParams.params.FailoverClustering.Cluster
	if ($FOCluster_XML) {
		Import-Module FailoverClusters
		$Cluster_Name = $FOCluster_XML.Name
		$Cluster_IP = $FOCluster_XML.ClusterIP		
		$ClusterSharedDisks = $FOCluster_XML.Disks.Disk
		
		try {
			if (Get-Service "ClusSvc") {
				$ClusSvc = Get-Service "ClusSvc"
				if ((($ClusSvc).Status) -eq "Running") {
					$ClusterCheck = get-cluster
				} else {
					$ClusterCheck = $null
				}
			} else {
				$ClusterCheck = $null
			}
		} catch [Exception] {
			$ClusterCheck = $null
		}
		
		$LCName = $Env:COMPUTERNAME
		$LXNode = $FOCluster_XML.Nodes.Node | ? {$_.NodeName -eq "$LCName"}
		if ($LXNode) {
			$LocalAction = $LXNode.Action
			switch ($LocalAction) {
				"Add" {
					if (!$ClusterCheck) {
						#The Cluster does not exist. Please create it! Magically.
						NewFOCluster -ClusterName "$Cluster_Name" -ClusterIP "$Cluster_IP"
						if ($ClusterSharedDisks) {
							foreach ($CSDisk in $ClusterSharedDisks) {
								$ImportDiskName = $CSDisk.Name
								$ImportDiskLetter = $CSDisk.DriveLetter
								AddDiskToFOCluster -DiskLetter $ImportDiskLetter -DiskName $ImportDiskName
							}
						}				
					} else {
						#We are running this on a cluster that already exists. Lets see if we need to join any nodes to this cluster.
						$JoiningNodes = $FOCluster_XML.Nodes.Node | ? {$_.Action -eq "Join"}
						if ($JoiningNodes) {
							$JoinA = @()
							$JoinA += $LCName
							foreach ($JNode in $JoiningNodes) {
								$JName = $JNode.NodeName
								$JoinA += $JName
							}
							
							TestFOCluster -Nodes $JoinA
							
							foreach ($JNode in $JoiningNodes) {
								$JName = $JNode.NodeName
								Write-Host "Attempting to join `'$JName`' to `'$Cluster_Name`' cluster."
								if ($LoggingCheck) {
									ToLog -LogFile $LFName -Text "Attempting to join `'$JName`' to `'$Cluster_Name`' cluster."
								}
								JoinFOCluster -ClusterName "$Cluster_Name" -NewNode "$JName"
							}
						}
						
					}
				}
				
				"Join" {
					#There doesnt appear to be anything that joining nodes need to do at this stage
					#We join new nodes to the cluster from the server that originally created the cluster.
				}
			}
		}
		
		Remove-Module FailoverClusters
	}
#endregion
#region DesiredStateConfiguration
	$DSC = $XMLParams.params.DSC
	if ($DSC) { Process-DSC $DSC }
#endregion
#region MSSQL
	#MS SQL Server
	$SQLNode = $XMLParams.params.MSSQL
	if ($SQLNode) {
		New-SQLInstall $SQLNode
	}
		
	$InstalledSQLProds = (gwmi Win32_Product | Where-Object {$_.name -Like "*SQL*2008*"}) #getting gwmi Win32_Product is time consuming; so just do it once to a variable
#region SQL 2008 SP1
	$SQL2008SP1Inst = $XMLParams.params.BinDependency.File | Where-Object {(($_.Name -like "*SQL*Server*2008*SP1*") -and ($_.Action -eq "Add"))}
	if ($SQL2008SP1Inst) {
		if ($LoggingCheck) {ToLog -LogFile $LFName -Text "MS SQL Server SP1 was requested to be installed."}

#       If SP1 (or later is *NOT* found)
		if (!(Test-IsSQLVersionInstalled -TestVersion "10.51.2500")) {
			if ($LoggingCheck) {ToLog -LogFile $LFName -Text "MS SQL Server SP1 was not found and will be installed."}
			$CArgs = $SQL2008SP1Inst.Argument
			$BinName = $SQL2008SP1Inst.Name
			If ($Cargs) {
				$CLA = ""
				ForEach ($argu in $CArgs) {
					$CLA += "$argu "
				}
			}
			LaunchProcessAndWait -Destination $TempFldrPath -FileName $BinName -CommandLineArgs $CLA
		} else {
			if ($LoggingCheck) {ToLog -LogFile $LFName -Text "MS SQL Server SP1 (or later) was already installed, and will not be reinstalled."}
		}
	}
#endregion
#region SQL 2008 SP2
	$SQL2008SP2Inst = $XMLParams.params.BinDependency.File | Where-Object {(($_.Name -like "*SQL*Server*2008*SP2*") -and ($_.Action -eq "Add"))}
	if ($SQL2008SP2Inst) {
		if ($LoggingCheck) {ToLog -LogFile $LFName -Text "MS SQL Server SP2 was requested to be installed."}
		#       If SP2 (or later is *NOT* found)
		if (!(Test-IsSQLVersionInstalled -TestVersion "10.51.4000")) {
				if ($LoggingCheck) {ToLog -LogFile $LFName -Text "MS SQL Server SP2 was not found and will be installed."}
				$CArgs = $SQL2008SP2Inst.Argument
				$BinName = $SQL2008SP2Inst.Name
				If ($Cargs) {
					$CLA = ""
					ForEach ($argu in $CArgs) {
						$CLA += "$argu "
					}
				}
				LaunchProcessAndWait -Destination $TempFldrPath -FileName $BinName -CommandLineArgs $CLA
		} else {
			if ($LoggingCheck) {ToLog -LogFile $LFName -Text "MS SQL Server SP2 was already installed, and will not be reinstalled."}
		}
	}
#endregion
    #MS SQL Server Management Objects
	#   SQL Server 2012+ only
	$SQLSMOS = $XMLParams.params.MSSQL.Management.SMO
    if ($SQLSMOS) {
        New-SQLManagedObjects $SQLSMOS
    } # end $SQLSMOS / MS SQL Server Management Objects
#endregion
#region Hosts
	$HostsUpd = $XMLParams.params.Hosts.Entry | Sort-Object -Property Action
	if ($HostsUpd) {
		$HostsData = Get-Content C:\Windows\System32\drivers\etc\hosts
		foreach ($HostsEntry in $HostsUpd) {
			$Action = $HostsEntry.Action
			$IP = $HostsEntry.IP
			$Name = $HostsEntry.Name
			if ($Action -eq "Delete") {
				$FindStr = $null #Clear it out just in case leftover from previous pass
				if ($IP) { $FindStr = $IP }
				if ($Name) { $FindStr = $Name }
				$HostsData = $HostsData | Select-String -Pattern $FindStr -notmatch
			}
			if ($Action -eq "Set") {
				$FindStr = "$IP\s*$Name"
				if (!($HostsData | Select-String -Pattern $FindStr)) {
					$HostsData += "$IP	$Name"
				}
			}
		}
		Set-Content C:\Windows\System32\drivers\etc\hosts $HostsData
	}
#endregion
#region GUIDataEntry
	$GUIDataEntry = ($XMLParams.params.GUIDataEntry | Sort-Object -Property Seq)
	if ($GUIDataEntry) {
		foreach ($FormInfo in $GUIDataEntry) {
			if ($LoggingCheck) {ToLog -LogFile $LFName -Text "Data Entry to Window $WindowName starting."}
			$WindowName = $FormInfo.FormName
			
			$KeyStreamObjArr = @()
			
			foreach ($Keystroke in $FormInfo.Key) {
				$KeyObj = New-Object PSObject
				$KeyObj | Add-Member -Type NoteProperty -Name Key -Value $Keystroke.Value
				$KeyObj | Add-Member -Type NoteProperty -Name TimeUnit -Value $Keystroke.TimeUnit
				$KeyObj | Add-Member -Type NoteProperty	-Name Delay -Value $Keystroke.DelayTime
				if ($Keystroke.Desc) {
					$KeyObj | Add-Member -Type NoteProperty	-Name Desc -Value $Keystroke.Desc
				}
				$KeyStreamObjArr += $KeyObj
			}
			if ($KeyStreamObjArr.count -gt 0) {
				#Launch the app but don't wait for it to terminate.
				#LaunchProcessAndWait -Destination $FormInfo.CmdPath -FileName $FormInfo.CmdExe -CommandLineArgs $FormInfo.CmdArgs
				$CmdExe = Join-Path $FormInfo.CmdPath $FormInfo.CmdExe
				$StartInfo = New-Object System.Diagnostics.ProcessStartInfo
				$StartInfo.Filename = "Powershell.exe"
	            $StartInfo.Arguments = $CmdExe
				$StartInfo.WorkingDirectory = "C:\"
				$StartInfo.LoaduserProfile = $false
				$StartInfo.UseShellExecute = $true
				$FormProcess = [System.Diagnostics.Process]::Start($StartInfo)

				#Send the keystrokes
				Start-Sleep -Seconds 10 #Give the form/app time to load
				$result = Enter-WindowsFormKeystrokes -WindowID $WindowName -KeyStreamObjectArr $KeyStreamObjArr
	            Start-Sleep -Seconds 10 #Give the form/app time to shutdown
	            if ($FormProcess.HasExited) {
					if ($LoggingCheck) {
		                if ($FormProcess.ExitCode -eq 0) {
		                    ToLog -LogFile $LFName -Text "Window $WindowName closed successfully."
		                } else {
							$ExitCodeStr = $FormProcess.ExitCode.ToString()
		                    ToLog -LogFile $LFName -Text "Window $WindowName closed with exit code: $ExitCodeStr."
		                }
		            } else {
		                ToLog -LogFile $LFName -Text "Window $WindowName failed to close. Terminating the window."
		                $FormProcess.Kill
		            }
				}
			} else {
				if ($LoggingCheck) {ToLog -LogFile $LFName -Text "There were no keystrokes to send to window."}
			}
			if ($LoggingCheck) {ToLog -LogFile $LFName -Text "Data Entry to Window $WindowName completed."}
		}
	}
#endregion
#region IIS
	$IISNodePres = $XMLParams.params.IIS
	if ($IISNodePres) {
		#Doing the IIS Configuration...
          # Register ASP .NET 4 in IIS, Only works with Windows 2008
		if ( ($($IISNodePres).RegDOTNETIIS -eq "True") -and ( ((Get-WmiObject -class Win32_OperatingSystem).Caption).tostring().contains("2008")) ) {
			
			try {
				Invoke-Expression "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\aspnet_regiis.exe -i -enable"
				Invoke-Expression "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\ServiceModelReg.exe -ia" 
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "Successfully registered DOTNET in IIS."
				}
			} catch [Exception] {
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: There was an issue registering DOTNET in IIS. $_"
				}
			}
		}

		#Ensure IIS has been properly installed.
		$WebAdminCheck = Get-Module -ListAvailable -Name WebAdministration
		if (!$WebAdminCheck) {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: IIS was not installed properly. Aborting script"
			}
			Throw "IIS needs to be installed prior to running this script!"
		} else {
			Import-Module -Name WebAdministration
		}
		
		#Create any underlying folder structure.

		$WWWROOT = $XMLParams.params.IIS.WWWROOT
		$FStructure = $XMLParams.params.IIS.CreateFolderStr.Dir
		if ($FStructure) { ProcessWWWROOT -FStructure $FStructure }

		#Delete any AppPools if needed.
		$DeletePool = $XMLParams.params.IIS.ManageAppPool.Pool | ? {$_.Action -eq "Delete"}
		if ($DeletePool) {
			foreach ($Pool in $DeletePool) {
				ProcessAppPoolDelete -Pool $Pool
			}
		}

		#App Pool Creation
		$AddPools = $XMLParams.params.IIS.ManageAppPool.Pool | ? {$_.Action -eq "Add"}
		if ($AddPools) {
			foreach ($Pool in $AddPools) {
				ProcessAppPoolAdd -Pool $Pool
			}
		}

		#Add SSL Certs
		$AddCerts = $XMLParams.params.IIS.SSL.Cert | ? {$_.Action -eq "Add"}
		if ($AddCerts) {
			$MakeCert = $BinDepFiles | ? {$_.Name -eq "makecert.exe"}
			foreach ($aCert in $AddCerts) {
				$CertN = $aCert.Name
				$MCName = $MakeCert.Name
				$MakeCertBin = Join-Path $TempFldrPath $MCName
				CreateIISCert -MakeCertPath $MakeCertBin -CertName $CertN
			}
		}
		
		#Copy SSL Certs
		$CopyCerts = $IISNodePres.SSL.Cert | ? {$_.Action -eq "Copy"}
		if ($CopyCerts) {
			foreach ($CCert in $CopyCerts) {
				$CCName = $CCert.Name
				$TF_CertLoc = Join-path $TempFldrPath $CCName
				if (!(Test-Path $TF_CertLoc)) {
					if (Test-Path $CCName) {
						$TF_CertLoc = $CCName
					}				
				}
				
				if (Test-Path $TF_CertLoc) {
					$CCertParams = @{}
					$CCertParams["CertPath"] = $TF_CertLoc
					
					$CertPW = $CCert.CertPW
					if ($CertPW) {
						$CCertParams["CertPass"] = $CertPW	
					}
					
					$CertSecPW = $CCert.SecurePW
					if ($CertSecPW) {
						$CCertParams["SecurePW"] = $CertSecPW
					}
					ImportECert @CCertParams
				}
			}
		}

		#Delete any Websites if needed.
		$DeleteSites = $XMLParams.params.IIS.Websites.Site | ? {$_.Action -eq "Delete"}
		if ($DeleteSites) {
			foreach ($Site in $DeleteSites) {
				ProcessSiteAction -Site $Site
			}
		}

		#Add Websites.
		$AddWSite = $XMLParams.params.IIS.Websites.Site | ? {$_.Action -eq "Add"}
		if ($AddWSite) {
			foreach ($Site in $AddWSite) {
				ProcessSiteAction -Site $Site
			}
		}

		#Delete WebApps
		$RMWebApps = $XMLParams.params.IIS.WebApp.App | ? {$_.Action -eq "Delete"}
		if ($RMWebApps) {
			foreach ($Removal in $RMWebApps) {
				$RMWPath = $Removal.Path
				$RMDelPhys = $Removal.DeletePhysical
				$RMObject = Get-ItemProperty -Path $RMWPath
				if ($RMObject) {
					$RMName = $RMObject.Name
					$RMPhysPath = $RMObject.PhysicalPath
					
					$RMParentPath = $RMObject.PSParentPath
					$PSplit = $RMParentPath.Split("\")
					$RMSite = $PSplit[$PSplit.Length - 1]
					try {
						Remove-WebApplication "$RMName" -site $RMSite
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "Successfully removed WebApp `'$RMName`'."
						}
					} catch [Exception] {
						Write-Host "There was an issue removing the Web App `'$RMName`'. $_"
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "FAILURE:: error removing Web App `'$RMName`'. $_"
						}
					}
					if ($RMDelPhys -eq "True") {
						if ($RMPhysPath) {
						if (Test-Path -Path $RMPhysPath) {
							try {
                                # $results = rm $RMPhysPath -Force -Recurse}
                                $results = start-job -ScriptBlock {param($p) rm $p -Force -Recurse} -Arg $RMPhysPath | Wait-Job
                                Receive-Job $results

								if ($LoggingCheck) {
									ToLog -LogFile $LFName -Text "Successfully removed `'$RMName`' physical path `'$RMPhysPath`'."
								}
							} catch [Exception] {
								if ($LoggingCheck) {
									ToLog -LogFile $LFName -Text "FAILURE:: There was an issue removing `'$RMName`' physical path `'$RMPhysPath`' Results: $results"
								}
							}
						}
						}
					}
				} else {
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "`'$RMWPath`' Does not already exist. no need to remove it."
					}
				}
			}
		}

		# Websites are done. Lets convert some WebApps.
		$WebApps = $XMLParams.params.IIS.WebApp.App | ? {$_.Action -ne "Delete"}
		if ($WebApps) {
			foreach ($App in $WebApps) {
				if ($LoggingCheck) {ToLog -LogFile $LFName -Text "Processing $($App | select *)."}
				$WAppPath = $App.Path
				$WAppPool = $App.AppPool
				$WappAction = $App.Action
				#Write-Host "WebApp Name: `"$WAppPath`""
				#Write-Host "Pool Name: `"$WAppPool`""
				
				if ($WappAction -eq "AddNew") {
					$WAppParentSite = $App.ParentSite
					$WAppName = $App.Name
					$WAppPath = $App.PhysPath
					$NewWebAppParam = @{}
					$NewWebAppParam["Site"] = $WAppParentSite
					$NewWebAppParam["AppName"] = $WAppName
					$NewWebAppParam["PhysicalPath"] = $WAppPath
					if ($WAppPool -ne $null) {
						$NewWebAppParam["AppPool"] = $WAppPool
					}
					#$NewWebAppParam
					AddNewWebApp @NewWebAppParam
				} else {
					try {
							$PoolArray = $WAppPath.Split("\")
							$WebAppName = $PoolArray[$PoolArray.Length - 1]
                            # most XMLs do not use the "addnew"
                            # if we deleted earlier, we need to re-add the physical path
                            $CPath = Join-Path $XMLParams.params.IIS.WWWROOT $WebAppName
                            if (!(Test-Path $CPath) ) {
                                New-Item -ItemType Directory -Path "$CPath" | Out-Null
					            if ($LoggingCheck) {
						            ToLog -LogFile $LFName -Text "Creating folder structure `'$CPath`'"
					            }
                             } 
							$AppCheck = $null
							Set-Location "IIS:\Sites"
							$AppCheck = Get-WebApplication -Name "$WebAppName"
							if (!$AppCheck) {
								ConvertTo-WebApplication "$WAppPath" -ApplicationPool $WAppPool
								if ($LoggingCheck) {
									ToLog -LogFile $LFName -Text "`'$WAppPath`' has been converted to a Web App Successfully"
								}
							} else {
								Set-ItemProperty $WAppPath -Name applicationPool -Value $WAppPool
							}
					} catch [Exception] {
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "Unable to convert `'$WAppPath`' to a Web Application. $_"
						}
						Write-Host "Unable to convert `'$WAppPath`' to a Web Application. `n $_"
					}
				}
			}
		}
		
		#Creation of virtual directories.
		$GotVD = $XMLParams.params.IIS.VirtDir.VD | ? {$_.Action -eq "Add"}
		if ($GotVD) {
			foreach ($VD in $GotVD) {
				$VDName = $VD.Name
				$VDPP = $VD.PhysPath
				$VDIP = $VD.IISPath
				
				CreateIIS_VD -VDName $VDName -PhysicalPath $VDPP -FullIISPath $VDIP
			}
		}

		#Install Web Deploy 2.0 using LaunchProcessAndWait Function.
		$Web2D = $BinDepFiles | ? {$_.Name -like "WebDeploy_2_10*"}
		if ($Web2D){
			if (!(gwmi Win32_Product | ? {$_.name -eq "Microsoft Web Deploy 2.0" })) {
				$CArgs = $Web2D.Argument
				$BinName = $Web2D.Name
				if ($CArgs) {
					$CLA = ""
					foreach ($argu in $CArgs) {
						$CoA = $argu
						if ($CoA -eq "/Package %:PACKAGELOCALPATH%") {
							$PakPath = Join-Path $TempFldrPath $BinName
							$CoA = $CoA.Replace("/Package %:PACKAGELOCALPATH%", "/Package `"$PakPath`"")
						}
						$CLA += $CoA + " "
					}
					$CLA = $CLA.TrimEnd(" ")
				}
				LaunchProcessAndWait -Destination $TempFldrPath -FileName $BinName -CommandLineArgs $CLA
			}			
		}
		#Any seperate enabled protocols need to be managed...
		$EnabledProtocolItems = $XMLParams.params.IIS.EnabledProto.Item
		if ($EnabledProtocolItems) {
			foreach ($ProtoItem in $EnabledProtocolItems) {
				$ProtoAction = $ProtoItem.Action
				$ProtocolSite = $ProtoItem.IISPath
				$Protocol = $ProtoItem.Proto
				
				alterEnabledProto -Action $ProtoAction -IISPath $ProtocolSite -Protocol $Protocol
			}
		}
		
		#Seperate Enabled auth processing
		$EnabledAuth = $XMLParams.params.IIS.EnabledAuth.Item
		if ($EnabledAuth) {
			foreach ($Auth in $EnabledAuth) {
				$AuthAction = $Auth.Action
				$AuthIISPath = $Auth.IISPath
				$AuthType = $Auth.AuthType
				
				alterEnabledAuth -IISPath $AuthIISPath -Action $AuthAction -AuthType $AuthType
			}
		}
		
		#CustomResponseHeaders
		$HTTP_CRS = $XMLParams.params.IIS.ClientCache.Item | ? {$_.Action -eq "Add"}
		if ($HTTP_CRS) {
			foreach ($Directive in $HTTP_CRS) {
				$CRS_Control = $Directive.Control
				$CRS_IISPath = $Directive.IISPath
				
				switch ($CRS_Control) {
					"NoControl" {
						CustomResponseHeader -IISPath "$CRS_IISPath" -DisableCache
					}
					
					"DisableCache" {
						CustomResponseHeader -IISPath "$CRS_IISPath" -ClientNoCache
					}
					
					"UseMaxAge" {
						$EDays = $Directive.ExpiresDays
						CustomResponseHeader -IISPath "$CRS_IISPath" -ExpireCacheInDays $EDays
					}
					
					"UseExpires" {
						$EDate = $Directive.ExpiresDate
						try {
							$FormDate = Get-Date $EDate
							CustomResponseHeader -IISPath "$CRS_IISPath" -ExpireCacheOnDate $FormDate
						} catch [Exception] {
							if ($LoggingCheck) {
								ToLog -LogFile $LFName -Text "There was an issue setting the custom Response Header to ExpireCacheOnDate `'$EDate`'."
							}
						}
					}
				}
			}
		}
		
		#IIS Compression
		$CompressionNodes = $XMLParams.params.IIS.Compression | ? {$_.Action -eq "Add"}
		if ($CompressionNodes) {
			foreach ($Node in $CompressionNodes) {
				$COM_IISP = $Node.IISPath
				$COM_Type = $Node.CompressionType
				$COM_State = $Node.State
				
				IISCompression -IISPath "$COM_IISP" -Type $COM_Type -State $COM_State
			}
		}
		
		#IISOutputCaching
		$OP_ClearAll = $XMLParams.params.IIS.OutputCaching.Ext | ? {$_.Action -eq "ClearAll"}
		if ($OP_ClearAll) {
			foreach ($ClearAll in $OP_ClearAll) {
				$ClearParams = @{}
				$ClearParams.Add("Action", $ClearAll.Action)
				$ClearParams.Add("IISPath", $ClearAll.IISPath)
				
				IISOutputCaching @ClearParams
			}
		}
		
		$AddWebConfig = $XMLParams.params.IIS.Config | ? {$_.Action -eq "Add"}
		if ($AddWebConfig){
			foreach($WebConfig in $AddWebConfig.Config){
				AddWebConfigParser -ConfigInfo $WebConfig
			}
		}
		
		$OP_Adds = $XMLParams.params.IIS.OutputCaching.Ext | ? {$_.Action -eq "Add"}
		if ($OP_Adds) {
			foreach ($Extension in $OP_Adds) {
				$OPAddParam = @{}
				$OP_Action = $Extension.Action
				if ($OP_Action) {
					$OPAddParam.Add("Action", $OP_Action)
				}
				$OP_IISPath = $Extension.IISPath
				if ($OP_IISPath) {
					$OPAddParam.Add("IISPath", $OP_IISPath)
				}
				$OP_Ext = $Extension.Extension
				if ($OP_Ext) {
					$OPAddParam.Add("Extension", $OP_Ext)
				}
				$OP_KC = $Extension.KernelCaching
				if ($OP_KC) {
					$OPAddParam.Add("KernCaching", $OP_KC)
				}
				$OP_UC = $Extension.UserCaching
				if ($OP_UC) {
					$OPAddParam.Add("CachePolicy", $OP_UC)
				}
				$OP_PD = $Extension.PeriodDurationSeconds
				if ($OP_PD) {
					$OPA_TimeSpan = New-TimeSpan -Seconds $OP_PD
					$OPAddParam.Add("Duration", $OPA_TimeSpan)
				}
				$OP_Loc = $Extension.Location
				if ($OP_Loc) {
					$OPAddParam.Add("Location", $OP_Loc)
				}
				
				IISOutputCaching @OPAddParam
			}
		}
	}
#endregion
#region Apache-Tomcat
	#Apache-Tomcat Install
	$TomcatCheck = $BinDepFiles | ? {$_.Name -like "apache-tomcat*"}
	if ($TomcatCheck){
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "`'apache-tomcat`' is requested to install."
		}
		
		if (!(gwmi Win32_Service | ? {$_.Name -eq "Tomcat7"})) {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "`'apache-tomcat`' was not found, and will install."
			}
			$CArgs = $TomcatCheck.Argument
			$BinName = $TomcatCheck.Name
			if ($CArgs) {
				$CLA = ""
				foreach ($argu in $CArgs) {
					$CoA = $argu
					if ($CoA -eq "/Package %:PACKAGELOCALPATH%") {
						$PakPath = Join-Path $TempFldrPath $BinName
						$CoA = $CoA.Replace("/Package %:PACKAGELOCALPATH%", "/Package `'$PakPath`'")
					}
					$CLA += $CoA + " "
				}
				$CLA = $CLA.TrimEnd(" ")
			}
			LaunchProcessAndWait -Destination $TempFldrPath -FileName $BinName -CommandLineArgs $CLA
		} else {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "`'apache-tomcat`' was already installed, and will not be reinstalled."
			}
		}
	}
#endregion
#region SpecialConf.SolrSpecial
	#Constellation Solr
	$SolrSpecial = $XMLParams.params.SpecialConf.SolrSpecial
	if ($SolrSpecial) {
		$SolrParams = @{}
		$SolrMS = $SolrSpecial.MasterSlave
		$SolrParams["MasterSlave"] = $SolrMS
		
		$TempApacheSolr = Join-Path $TempFldrPath "apache-solr-3.3.0"
		$SolrParams["ApacheSolrFolder"] = $TempApacheSolr
		
		$SolrTomcatRoot = $SolrSpecial.ApacheConf.TomcatRoot
		if ($SolrTomcatRoot) {
			$SolrParams["TomcatRoot"] = $SolrTomcatRoot
		}
		
		$SolrSvrXML = $SolrSpecial.ApacheConf.ServerXML
		if ($SolrSvrXML) {
			$SolrParams["ApacheServerXML"] = $SolrSvrXML
		}
		
		$SolrHttpSvcPort = $SolrSpecial.ApacheConf.ServicePort
		if ($SolrHttpSvcPort) {
			$SolrParams["HTTPServicePort"] = $SolrHttpSvcPort
		}
		
		$SolrHome = $SolrSpecial.ApacheConf.SolrHome
		if ($SolrHome) {
			$SolrParams["SolrHome"] = $SolrHome
		}
		
		$SolrJVMOpts = $SolrSpecial.ApacheConf.JavaOpts.Opt
		if ($SolrJVMOpts) {
			$JVOStr = ""
			foreach ($JVMOpt in $SolrJVMOpts) {
				$JVOStr = $JVOStr + $JVMOpt + ";"
			}
			$JVOStr = $JVOStr.Replace("%%SOLRHOME%%", $SolrHome)
			$JVOStr = $JVOStr.TrimEnd(";")
			$SolrParams["JavaOpts"] = $JVOStr
		}
		
		SolrConfig @SolrParams
	}
#endregion
#region Octopus
	#Octopus Install
	$OctopusInst = $XMLParams.params.BinDependency.File | ? {(($_.Name -like "Octopus.Tentacle*") -and ($_.Action -eq "Add"))}
	if ($OctopusInst) {
		$CArgs = $OctopusInst.Argument
		$BinName = $OctopusInst.Name
		if ($CArgs) {
			$CLA = ""
			foreach ($argu in $CArgs) {
				$CoA = $argu
				if ($CoA -eq "/Package %:PACKAGELOCALPATH%") {
					$PakPath = Join-Path $TempFldrPath $BinName
					$CoA = $CoA.Replace("/Package %:PACKAGELOCALPATH%", "/Package `"$PakPath`"")
				}
				$CLA += $CoA + " "
			}
			$CLA = $CLA.TrimEnd(" ")
		}
		LaunchProcessAndWait -Destination $TempFldrPath -FileName $BinName -CommandLineArgs $CLA
		
		$ConfigOctopus = $XMLParams.params.AppConfig.Octopus.Config | ? {$_.Action -eq "Add"}
		if ($ConfigOctopus) {
			$OAF = $ConfigOctopus.AgentFolder
			$OAD = $ConfigOctopus.AppDir
			$OctPort = $ConfigOctopus.Port
			$OTK = $ConfigOctopus.TrustKey
			$OTCD = $ConfigOctopus.TempCertDir
			
			Config-Octopus -AgentDir $OAF -AppDir $OAD -ComPort $OctPort -TrustKey $OTK -TempCertDir $OTCD
		}
	}
#endregion
#region Office 2007
	#######################################################################################################################
	#Office 2007 Install
	$Office2007Inst = $XMLParams.params.BinDependency.File | Where-Object {(($_.Name -like "OfficeSetup.exe") -and ($_.Action -eq "Add"))}
	If ($Office2007Inst) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "MS Office Server is requested to install."
		}
		if (!(gwmi Win32_Product | ? {$_.name -eq "Microsoft Office Enterprise 2007"})) {
			if ($LoggingCheck) {ToLog -LogFile $LFName -Text "Microsoft Office Enterprise 2007 was not found, and will install."}

			$CArgs = $Office2007Inst.Argument
			$BinName = $Office2007Inst.Name
			If ($Cargs) {
				$CLA = ""
				ForEach ($argu in $CArgs) {
					$CLA += "$argu "
				}
			}
			LaunchProcessAndWait -Destination $TempFldrPath -FileName $BinName -CommandLineArgs $CLA
		} else {
			if ($LoggingCheck) {ToLog -LogFile $LFName -Text "Microsoft Office Enterprise 2007 was already installed."}
		}
	}
#endregion
#region WebDeploy
	#######################################################################################################################
	#Install WebDeploy
	$WebDeployCheck = $BinDepFiles | ? {$_.Name -like "WebDeploy_*"}
	if ($WebDeployCheck){
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "WebDeploy is requested to install."
		}
		$WDVersion = $WebDeployCheck.CheckInstallPath
		if (!(Test-Path $WDVersion)) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "WebDeploy was not found, and will install."
		}
			$CArgs = $WebDeployCheck.Argument
			$BinName = $WebDeployCheck.Name
			if ($CArgs) {
				$CLA = ""
				foreach ($argu in $CArgs) {
					$CoA = $argu
					if ($CoA -eq "/Package %:PACKAGELOCALPATH%") {
						$PakPath = Join-Path $TempFldrPath $BinName
						$CoA = $CoA.Replace("/Package %:PACKAGELOCALPATH%", "/Package `"$PakPath`"")
					}
					$CLA += $CoA + " "
				}
				$CLA = $CLA.TrimEnd(" ")
			}
			LaunchProcessAndWait -Destination $TempFldrPath -FileName $BinName -CommandLineArgs $CLA
		} else {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "WebDeploy was already installed ($WDVersion), and will not be reinstalled."
			}
		}
	}
#endregion
#region MSDTC
	#Configure MSDTC Security
	$MSDTCParams = $XMLParams.params.MSDTC
	if ($MSDTCParams) {
		$NetDTCA = ($MSDTCParams.NetworkDTC).Action
		$XAT = ($MSDTCParams.XATransaction).Action
		$SNAT = ($MSDTCParams.SNALU62Trans).Action
		$RC = ($MSDTCParams.RemoteClients).Action
		$RA = ($MSDTCParams.RemoteAdmin).Action
		$AlIbCm = ($MSDTCParams.AllowInboundCom).Action
		$AlObCm = ($MSDTCParams.AllowOutboundCom).Action
		$MAReq = ($MSDTCParams.MutualAuthReq).Action
		$IAReq = ($MSDTCParams.IncomingAuthReq).Action
		$NAReq = ($MSDTCParams.NoAuthReq).Action
		$RestartAfter = ($MSDTCParams.RestartAfterConf).Action
		ConfigureDTCSec -XTimeOut $XTimeOut -NetDTCAccess $NetDTCA -XATrans $XAT -SNALUTrans $SNAT -AllowRemoteClient $RC -AllowRemoteAdmin $RA -AllowInbound $AlIbCm -AllowOutbound $AlObCm -MutualAuthReq $MAReq -IncomingAuthReq $IAReq -NoAuthReq $NAReq -Restart $RestartAfter
	}

	$MSDTCLocalParams = $XMLParams.params.MSDTC.LocalComputer
	if ($MSDTCLocalParams) {
		$TransactionTimeout = ($MSDTCLocalParams.TransactionTimeout).Value
		if (($MSDTCLocalParams.DCOMEnabled).Value -eq "True" ) {
			$DCOMEnabled = $true
		} else {
			$DCOMEnabled = $false
		}
		if (($MSDTCLocalParams.CISEnabled).Value -eq "True" ) {
			$CISEnabled = $true
		} else {
			$CISEnabled = $false
		}
		$DefaultAuthenticationLevel = ($MSDTCLocalParams.DefaultAuthenticationLevel).Value
		$DefaultImpersonationLevel = ($MSDTCLocalParams.DefaultImpersonationLevel).Value
		$RestartAfter = ($MSDTCLocalParams.RestartAfterConf).Action
		ConfigureDTCLocalComputer -TransactionTimeout $TransactionTimeout -DCOMEnabled $DCOMEnabled -CISEnabled $CISEnabled -DefaultAuthenticationLevel $DefaultAuthenticationLevel -DefaultImpersonationLevel $DefaultImpersonationLevel -RestartAfter $RestartAfter
	}

	$MSDTCPerms = $XMLParams.params.MSDTC.Perms
	if ($MSDTCPerms) {
		foreach ($Perm in $MSDTCPerms.Perm) {
			$RegKey = $Perm.RegKey
			$ACE = $Perm.ACE
			# Get any existing SDDL
			$SDDL = (GetTheDCOMSDDL $RegKey).SDDL
			# Append the requested ACE rights (you have to break down the incoming ACE to individual (paren-enclosed) ACEs and apply them one at a time
			$ArrayofACEs = $ACE -split "\)"
			foreach ($Element in $ArrayofACEs) {
                if ($Element.Length -gt 11) { # At a minimum and ACE must have (A;;;;;;BC) characters | and because split will have one empty element
				    $ReqACE = "$Element)" # Add the right paren back that got dropped doing the split
				    $SDDL = SDDLAddRights $SDDL $ReqACE
                }
			}
			if (!(SetTheDCOMSDDL $RegKey $SDDL)) {
				if ($LoggingCheck) {ToLog -LogFile $LFName -EventID 3 -Text "An error occured setting the DCOM SDDL for $RegKey."}
			}
		}
	}
    
#endregion
#region Component Services
	$ComSrvcs = $XMLParams.params.ComponentServices
	if ($ComSrvcs) {
		ProcessComponentServicesXML -XMLNode $ComSrvcs
	}
#endregion
#region MSMQ
	#MSMQ Queue Deletion
	$MSMQ_D_Job = $XMLParams.params.MSMQQueue.Queue | ? {$_.Action -eq "Delete"}
	if ($MSMQ_D_Job) {
		foreach ($DJob in $MSMQ_D_Job) {
			$QueueName = $DJob.Name
			$QueueIsPublic = $DJob.Public
			DeleteMSMQ -QueueName $QueueName -Public $QueueIsPublic
		}
	}

	#MSMQ Queue Creation
	$MSMQ_A_Job = $XMLParams.params.MSMQQueue.Queue | ? {$_.Action -eq "Add"}
	if ($MSMQ_A_Job) {
		foreach ($Queue in $MSMQ_A_Job) {
			$QueueName = $Queue.Name
			$QueueIsPublic = $Queue.Public
			$QueueIsTrans = $Queue.Transactional
			$QueueIsAuth = $Queue.Authenticated
			$QueueEncReq = $Queue.EncryptionReq
			$QueueEnableJourn = $Queue.EnableJournal
			$QueueMJS = $Queue.MaxJournalSizeKB
			$QueueMQS = $Queue.MaxQueueSizeKB
			
			CreateMSMQ -QueueName $QueueName -Public $QueueIsPublic -MaxJournalSize $QueueMJS -Transactional $QueueIsTrans -Authenticated $QueueIsAuth -EncryptionRequired $QueueEncReq -MaxQueueSize $QueueMQS -EnableJournal $QueueEnableJourn
			$PermsCheck = $Queue.Permissions.Perm
			if ($PermsCheck) {
				foreach ($Perms in $PermsCheck) {
					$PermUser = $Perms.User
					$PermACE = $Perms.ACE
					$PermRight = $Perms.Right
                    $PermPass = $Perms.Password 
					AlterMSMQPerms -User $PermUser -Queue $QueueName -Public $QueueIsPublic -ACE $PermACE -Rights $PermRight
                    # add certificate logic here
                    if ($QueueEncReq -and $PermPass){
                        AddMSMQCert -ADUsername $PermUser -Password $PermPass
                    }
				}
			}
		}
	}

	#MSMQ Seperate Permission Adjustment
	$MSMQ_P_Job = $XMLParams.params.MSMQQueue.PermAdjust
	if ($MSMQ_P_Job) {
		foreach ($PA in $MSMQ_P_Job) {
			$QueueName = $PA.Queue
			$QueueIsPublic = $PA.Public
			$PermUser = $PA.User
			$PermACE = $PA.ACE
			$PermRight = $PA.Right
			AlterMSMQPerms -User $PermUser -Queue $QueueName -Public $QueueIsPublic -ACE $PermACE -Rights $PermRight
		}
	}
	
	#Global MSMQ Queue permissions.
	$GlobalMSMQPerms = $XMLParams.params.MSMQQueue.AllQueues.Permissions.Perm
	if ($GlobalMSMQPerms) {
		$MSMQAllQueue = GetAllMSMQQueues
		if ($MSMQAllQueue) {
			foreach ($Queue in $MSMQAllQueue) {
				foreach ($GlbMSMQPerm in $GlobalMSMQPerms) {
					$PermOptions = @{}
					if ($Queue | Select-String "\" –SimpleMatch) {
						$QA = $Queue.Split("\")
						$QFirst = $QA[0]
						if ($QFirst | Select-String "private") {
							$PermOptions["Public"] = "False"
							$Name = $QA[1]
							$PermOptions["Queue"] = $Name
						} else {
							$PermOptions["Public"] = "True"
							$PermOptions["Queue"] = $Queue
						}
					} else {
						$PermOptions["Public"] = "True"
						$PermOptions["Queue"] = $Queue
					}
					$GlobalUser = $GlbMSMQPerm.User
					$PermOptions["User"] = $GlobalUser
					$GlobalACE = $GlbMSMQPerm.ACE
					$PermOptions["ACE"] = $GlobalACE
					$GlobalRight = $GlbMSMQPerm.Right
					$PermOptions["Rights"] = $GlobalRight
					
					AlterMSMQPerms @PermOptions
				}
			}
		}
	}

	#System MSMQ Queue permissions.
	$SystemMSMQPerms = $XMLParams.params.MSMQQueue.System.Permissions.Perm
	if ($SystemMSMQPerms) {
		foreach($PermSetting in $SystemMSMQPerms ) {
			$SMSMQUser = $PermSetting.user
			$SMSMACE = $PermSetting.ACE
			$SMSMRight = $PermSetting.Right
			$ParamHash = @{}
			If($SMSMQUser)   { $ParamHash.Add("-User","$SMSMQUser") }
			If($SMSMACE)  { $ParamHash.Add("-ACE","$SMSMACE") }
			If($SMSMRight) { $ParamHash.Add("-Right","$SMSMRight") }
	
			$serviceToRestart = AlterMSMQSystemPerms @ParamHash
		}
            # need to restart after permissions added
            if ($serviceToRestart) { ServiceOps -ServiceName $serviceToRestart -ServiceOp 'Restart' }
	}
#endregion
#region ServiceConfig
#region ServiceConfig.Service
	#Service Configuration
	$CServices = $XMLParams.params.ServiceConfig.Service
	if ($CServices) {
		foreach ($Service in $CServices) {
            ProcessServiceConfig -Service $Service
		}
	}
#endregion
#region ServiceConfig.ServicePerm
	#Logon As A Service Configuration
	$CServicePerms = $XMLParams.params.ServiceConfig.ServicePerm
	if ($CServicePerms) {
		foreach ($ServicePerm in $CServicePerms) {
            $SAction = $ServicePerm.Action
			$SName = $ServicePerm.Name
			if ($SAction -eq "Remove") {
				#They are using the default username. managing service without changing users
					RemoveAccountPolicy -account $SName -right "SeServiceLogonRight"
				}
            else {
				Write-host "Action ($SAction) not supported at this time"
			}
		}
    }
#endregion
#endregion
#region Filesystem
	#Filesystem changes (Permissions)
	$InheritActions = $XMLParams.params.Filesystem.PermInheritance.Object
	if ($InheritActions) {
		foreach ($IA in $InheritActions) {
			$iTarget = $IA.Target
			$AllowInherit = [System.Convert]::ToBoolean($IA.AllowInheritance)
			$PreservePI = [System.Convert]::ToBoolean($IA.PreserveInheritance)
			
			FSSetACEProtection -Target $iTarget -Protected $AllowInherit -PreserveInheritance $PreservePI
		}
	}

	#NTFS Permissions
	$AdjustPermissions = $XMLParams.params.Filesystem.Permissions.Perm
	if ($AdjustPermissions) { ProcessPerms -AdjustPermissions $AdjustPermissions }
#endregion
#region EVLogs
	#Changes to event logs:
	$EVTV_Act = $XMLParams.params.EVLogs.log
	if ($EVTV_Act) {
	#Additions
		$EVTV_Add = $EVTV_Act | ? { $_.Action -eq "Add" }
		if ($EVTV_Add) {
			foreach ($EVTV_Item in $EVTV_Add) {
				$LogName = $EVTV_Item.LogName
				$EventSource = $EVTV_Item.EventSource
				$EVTPhysPath = $EVTV_Item.Path
				if ($EVTPhysPath) {
					NewEVTLog -Name $LogName -Source $EventSource -FullPath $EVTPhysPath
				} else {
					NewEVTLog -Name $LogName -Source $EventSource
				}
			}
		}
	#Moves
		$EVTV_Move = $EVTV_Act | ? { $_.Action -eq "Move" }
		if ($EVTV_Move) {
			foreach ($EVTV_Item2 in $EVTV_Move) {
				$EVTPP = $EVTV_Item2.Path
				$EVTV_RegK = $EVTV_Item2.LogRegKey
				
				MoveEVTLog -RegSubKey $EVTV_RegK -NewLocation $EVTPP
			}
		}
	}
#endregion
#region reg
    # STIG-RegistryMod.ps1
    # New keys first
    # future to-do ensure all parent paths are created first
    $addNewKeys = $XMLParams.params.reg.SubKey | ? {$_.Action -eq "New"}
    if ($addNewKeys) {
        foreach ($newKey in $addNewKeys) {
            ProcessRegKeyConfig -SubKey $newKey

        }
    }
    # Set any Registry Keys
	$RegParams = $XMLParams.params.reg.SubKey | ? {$_.Action -ne "New"}
	if ($RegParams) {
		foreach ($SubKey in $RegParams) {
            ProcessRegKeyConfig -SubKey $SubKey
		}
	}
#endregion
#region SpecialConf.ConstellationSpecial.VMDDUpdate
	#Constellation special VM display driver update
	$ConstSpecialSauceDDUpdate = $XMLParams.params.SpecialConf.ConstellationSpecial.VMDDUpdate
	if ($ConstSpecialSauceDDUpdate -eq "True") {
		UpdateVMDisplayDriver
	}
#endregion
#region SearchAndReplace
	# Text file operations
	$ServicesToStop = @()
	$SARs = $XMLParams.params.SearchAndReplace
	$TextInserts = $XMLParams.params.TextInsert

    if ($SARs) {
		ForEach ($SAR in $SARs) {
            $ServiceToStop = $SAR.StopServices
            if($ServiceToStop){
                if( -not ($ServicesToStop | Select-String $ServiceToStop)){
			        $ServicesToStop += $ServiceToStop
                }
            }
		}
	}
	if($TextInserts) {
		ForEach ($Insert in $TextInserts) {
            $ServiceToStop = $Insert.StopServices
            if($ServiceToStop){
                if( -not ($ServicesToStop | Select-String $ServiceToStop)){
			        $ServicesToStop += $ServiceToStop
                }
            }
		}
    }
	if($ServicesToStop){
		foreach($service in $ServicesToStop){
			StopService -ServiceName $Service -Force
		}
	}

    if ($SARs) {
		ForEach ($SAR in $SARs) {
			SearchReplace($SAR)
		}
	}


#endregion
#region TextInsert
	$TextInserts = $XMLParams.params.TextInsert
	if($TextInserts) {
		ForEach ($Insert in $TextInserts) {
			InsertTextXMLNode($Insert)
		}
    }

	if($ServicesToStop){
		foreach($serviceToRestart in $ServicesToStop){
			StartService -ServiceName $serviceToRestart
		}
	}
#endregion
#region Local Group Policy
    $ntrights = $XMLParams.params.LocalUserRights
    if($ntrights) {
        foreach($UserRight in $ntrights){
            ProcessUserRights -UserRightParam $UserRight.UserRights
        }
    }
#endregion
#region User Tasks
	$useracts = $XMLParams.params.UserAccounts
	if($useracts){
		foreach($uact in $useracts.UserAction){
			if($uact.Action -eq "AddToGroup"){
				$tuser = $uact.User
				$tgrp = $uact.Group
				if($tuser -and $tgrp){
					LLToLog -EventID $LLINFO -Text "Adding $tuser to $tgrp."
					AddUserToLocalGroup -User $tuser -Group $tgrp
				} else {
					LLToLog -EventID $LLWARN -Text "You must provide both a user and a group when specifying AddToGroup."
				}
			}
		}
	}
#endregion
#region ScheduleTask
    $TaskElements = $XMLParams.params.TaskScheduler
    if ($TaskElements) {
        foreach($TaskElem in $TaskElements) {
		    TSScheduleTask -TaskNode $TaskElem
	    }
    }
#endregion
#region SetPageFile
    $PageFileConfig = $XMLParams.params.PageFile
    if($PageFileConfig){
        PageFileXMLParser -PageFileConfigNode $PageFileConfig
    }
#endregion
}