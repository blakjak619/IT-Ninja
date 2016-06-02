<#  
  .SYNOPSIS   
    Script to build Secure (SSL) FTP server 
  .DESCRIPTION
    This script brings the D: drive online
    Installs Windows features required for FTP
    Removes the default web site
    Creates the ftp root folder on the D: drive (should be on CIFS share)
    Configures FTP
    Adds local users
  .EXAMPLE
    cls
    remove-item \\TSClient\H\BPIFTPConfig -Force -Recurse -Confirm:$False
    cd c:\scripts
    . .\DSC-SFTP.ps1
    $pswdSecure = ConvertTo-SecureString -String "boost-PrkiT" -AsPlainText -Force
    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "BRIDGEPOINT\svc_dsc_ro",$pswdSecure
    BPIFTPConfig -ConfigurationData $ConfigurationData -Credential $cred
    Copy-Item -Path BPIFTPConfig -Destination \\TSClient\H\ -Force -Recurse
    ls \\TSClient\H\BPIFTPConfig
#> 


#region BPIFTPConfig

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
Configuration BPIFTPConfig 
{
    param ([Parameter(Mandatory=$false)]
        [PSCredential]$Credential,
		[PSCredential]$CIFSCredential
        )


    Node localhost 
    {
#region Setup D Drive
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
        Script RemoveDefWebSite
        {
            DependsOn = "[WindowsFeature]webmgmt"
            SetScript = { 
                Import-Module WebAdministration
                Remove-Website "Default Web Site" 
            }
            TestScript = { 
                Import-Module WebAdministration
                if(ls IIS:\Sites | Where-Object {$_.Name -eq "Default Web Site"}) {
                    $true
                } else {
                    $false
                }
            }
            GetScript = { 
                Import-Module WebAdministration
                (ls IIS:\Sites | Where-Object {$_.Name -eq "Default Web Site"})
            }
        }
#region Setup FTP
        WindowsFeature ftp
        {
            Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
            Name = "Web-Ftp-Server"  
            IncludeAllSubFeature = "true"
        }
        WindowsFeature webmgmt
        {
            Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
            Name = "Web-Mgmt-Tools"  
            IncludeAllSubFeature = "true"
        }

        File CreateFTPFolder
        {
            #DependsOn = "[Script]FormatDisk1" #No longer depends on local disk, uses remote share
            Ensure = "Present" 
            Type = "Directory" 
            DestinationPath = "\\bpe-aesd-cifs.bridgepoint.local\ftp_np_dev\LocalUser"
			Credential = $CIFSCredential    
        }

        Script SetupFTP
        {
            DependsOn = @("[WindowsFeature]ftp","[File]CreateFTPFolder")
            SetScript = {
                        Import-Module WebAdministration

                        New-WebFtpSite -Name "SecureFTP" -PhysicalPath "\\bpe-aesd-cifs.bridgepoint.local\ftp_np_dev" -Port "21" -Force
                          ## Allow SSL connections 
                        Set-ItemProperty "IIS:\Sites\SecureFTP" -Name ftpServer.security.ssl.controlChannelPolicy -Value 0
                        Set-ItemProperty "IIS:\Sites\SecureFTP" -Name ftpServer.security.ssl.dataChannelPolicy -Value 0 
                             ## Enable Basic Authentication
                        Set-ItemProperty "IIS:\Sites\SecureFTP" -Name ftpServer.security.authentication.basicAuthentication.enabled -Value $true
                        ## Set USer Isolation
                        Set-ItemProperty "IIS:\Sites\SecureFTP" -Name ftpserver.userisolation.mode -Value 3

                             ## Give Authorization to All Users and grant "read"/"write" privileges
                        Add-WebConfiguration "/system.ftpServer/security/authorization" -value @{accessType="Allow";roles="";permissions="Read,Write";users="*"} -PSPath IIS:\ -location "SecureFTP"
                             ## Restart the FTP site for all changes to take effect
                        Restart-WebItem "IIS:\Sites\SecureFTP"
                        }
            TestScript = { 
                            Import-Module WebAdministration
                            if(ls IIS:\Sites | Where-Object {$_.Name -eq "SecureFTP"}) {
                                $true
                            } else {
                                $false
                            } 
                        }
            GetScript = { 
                            Import-Module WebAdministration
                            (Get-ChildItem IIS:\Sites | Where-Object {$_.Name -eq "SecureFTP"})
                        }
        }
#endregion
#region Setup Local Users

#endregion
    }
} 
#endregion BPIFTPConfig