﻿<#  
  .SYNOPSIS   
    Template and for Desired State Configuration (DSC) 
  .DESCRIPTION
    This is a template file for DSC that provides examples of various resources.

    Process:
        Create the Powershell Configuration script 
        Generate the Managed Object Format (MOF) file
        Start DSC with the MOF file generated

    To generate a MOF (folder/file):
        Dot-source the .ps1 script created (This will create a "Configuration" type function named after the Configuration specfied; i.e
        Configuration MakeItSo will create the "MakeItSo" function)
        Call the function (e.g. "MakeItSo"), and pass any optional configuration data / credentials (credentials are required for the DML)
    To to start DSC and execute with the MOF file previously generated:
        Start-DscConfiguration -Wait -Verbose -Path .\<MOF path>

    Note: For DML (Definitive Media Library / SMB share) access, use the "bridgepoint\svc_dsc_ro" AD account

    
    The links provided, in order, are:
        DSC overview
        Built-In DSC Configuration Resources
        Creating Custom DSC Configuratin Resources
   .LINK
    https://technet.microsoft.com/en-us/library/dn249912.aspx
    https://technet.microsoft.com/en-us/library/dn249921.aspx
    https://technet.microsoft.com/en-us/library/dn249927.aspx
  .EXAMPLE  
   . .\DSC-Template.ps1
   Start-DscConfiguration -Wait -Verbose -Path .\HelloWorldConfig

   MakeItSo -ConfigurationData $ConfigurationData -Credential (Get-Credential)
   Start-DscConfiguration -Wait -Verbose -Path .\MakeItSo

#> 
## http://technet.microsoft.com/en-us/library/dn249918.aspx
$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName="*"
            PSDscAllowPlainTextPassword=$true
         }
         @{
            NodeName="localhost"
         }
    )
} #end $ConfigurationData
Configuration SVNConfig

{
   # A Configuration block can have zero or more Node blocks
   Node "localhost"
   {
#region D-Drive Setup
        Script MoveCDROM
        {
            SetScript = {
                $Drive = Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'd:'"
                if($Drive.DriveType -eq 5){
                    $NextAvailable = ls function:[e-z]: -n | ?{ !(test-path $_) } | select -first 1
                    Set-WmiInstance -input $Drive -Arguments @{DriveLetter=$NextAvailable}
                }
            }
            TestScript = { 
                $Drive = Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'd:'"
                if($Drive.DriveType -eq 3){
                    $true
                } else {
                    $false
                }
            }
            GetScript = { 
                Get-WmiObject -Class win32_volume -Filter "DriveLetter = 'd:'"
            }
        }

        Script OnlineDisk1
        {
            DependsOn = "[Script]MoveCDROM"
            SetScript = {
                Set-Disk -Number 1 -IsOffline $false
            }
            TestScript = {
                if((Get-Disk -Number 1).IsOffline){
                    $false
                } else {
                    $true
                }
            }
            GetScript = { Get-Disk -Number 1 }
        }

        Script InitDisk1
        {
            DependsOn = "[Script]OnlineDisk1"
            SetScript = {
                Initialize-Disk -Number 1
            }
            TestScript = {
                $Disk = Get-Disk -Number 1
                if($Disk.PartitionStyle -eq "GPT"){
                    $true
                } else {
                    $false
                }
            }
            GetScript = {
                (Get-Disk -Number 1).PartitionStyle
            }
        }

        Script FormatDisk1
        {
            DependsOn = "[Script]InitDisk1"
            SetScript = {
                New-Partition -DiskNumber 1 -DriveLetter "D" -UseMaximumSize | Format-Volume -FileSystem NTFS -Confirm:$false
            }
            TestScript = {
                $DetectedFileSystem = $null
                $part_query = 'ASSOCIATORS OF {Win32_DiskDrive.DeviceID="\\\\.\\PHYSICALDRIVE1"} WHERE AssocClass=Win32_DiskDriveToDiskPartition'
                $partitions = @( get-wmiobject -query $part_query | sort StartingOffset )
                if($partitions.Count -gt 0){
                    $vol_query = 'ASSOCIATORS OF {Win32_DiskPartition.DeviceID="' + $partitions[0].DeviceID + '"} WHERE AssocClass=Win32_LogicalDiskToPartition'
                    $volumes   = @(get-wmiobject -query $vol_query)
                    if($volumes.Count -gt 0){
                        $DetectedFileSystem = $volumes[0].FileSystem
                    }
                }

                if((Get-Disk -Number 1).FileSystem -eq "NTFS" -or $DetectedFileSystem -eq "NTFS"){
                    $true
                } else {
                    $false
                }
            }
            GetScript = {
                (Get-Disk -Number 1).FileSystem
            }
        }
#endregion

#region PlaceholderForAddlLogic
		File InstallerDir{
			Ensure = "Present"
			Type = "Directory"
			DestinationPath = "D:\Installers"
			DependsOn = "[Script]FormatDisk1"
		}
		File SVNInstaller{
			SourcePath = "\\10.13.0.206\scratch\DML\svn\Setup-Subversion-1.8.14.msi"
			DestinationPath = "D:\Installers\Setup-Subversion-1.8.14.msi"
			Ensure = "Present"
			Type = "File"
			Credential = $Credential
			DependsOn = "[File]InstallerDir"
		}
		Package SVN{
			Name = "Subversion"
			ProductID = "248E68E3-2971-42CD-B1BC-51CE24BED831"
			Path = "D:\Installers\Setup-Subversion-1.8.14.msi"
			Arguments = "INSTALLDIR=D:\Subversion"
			DependsOn = "[File]SVNInstaller"
		}
#endregion
#region CreateTempFolder
      # temp
      File TempDir{
        Ensure = "Present" 
        Type = "Directory" 
        DestinationPath = "C:\temp" 
      }
#endregion
#region CreateLogFile
      # Log dir
      File LogDir{
         Ensure = "Present"  # You can also set Ensure to "Absent"
         Type = "Directory" # Default is “File”
         DestinationPath = "D:\Logs" # The path where we want to ensure the web files are present
        # DependsOn = "[WindowsFeature]webserver"  # This ensures that MyRoleExample completes successfully before this block runs
      }
#endregion
   }
} 
