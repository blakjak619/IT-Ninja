<#  
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

$pswdSecure = ConvertTo-SecureString -String "boost-PrkiT" -AsPlainText -Force
$Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "BRIDGEPOINT\svc_dsc_ro",$pswdSecure

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

Configuration WAPStack

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
#region Windows features
# sub: all sub-features
     foreach ($Feature in @()) 
     {    
      WindowsFeature $Feature
      {
          Ensure = "Present" 
          Name = $Feature 
          IncludeAllSubFeature = "true"
      }
     } # end loop
 # sub: single feature
     foreach ($Feature in @()) 
     {    
      WindowsFeature $Feature
      {
          Ensure = "Present" 
          Name = $Feature 
          IncludeAllSubFeature = "false"
      }
     } # end loop

#endregion 

 
#region PlaceholderForAddlLogic

	# VisualC Redistributable
      File VCRedist2012 {
          SourcePath = "\\10.13.0.206\scratch\DML\Microsoft\vcredist\2012\vcredist_x64.exe"
          DestinationPath = "C:\Temp\vcredist_x64.exe"
          Ensure = "Present"
          Type = "File"
          Credential = $Credential
      }
      Package VCRedist2012 {
		  Name = "VCRedist2012"
		  Path = "C:\Temp\vcredist_x64.exe"
		  ProductID = "37B8F9C7-03FB-3253-8781-2517C99D7C00"
		  Ensure = "Present"
          Arguments = "/install /passive /norestart"
          DependsOn = "[File]VCRedist2012"
      }

      File VCRedist2015 {
          SourcePath = "\\10.13.0.206\scratch\DML\Microsoft\vcredist\2015\vc_redist.x64.exe"
          DestinationPath = "C:\Temp\vc_redist.x64.exe"
          Ensure = "Present"
          Type = "File"
          Credential = $Credential
      }
      Package VCRedist2015 {
		  Name = "VCRedist2015"
		  Path = "C:\Temp\vc_redist.x64.exe"
		  ProductID = "BC958BD2-5DAC-3862-BB1A-C1BE0790438D"
		  Ensure = "Present"
         Arguments = "/install /passive /norestart"
         DependsOn = "[File]VCRedist2015"
      }

	# Apache 2.4
	  File Apache2_4Installer {
          SourcePath = "\\10.13.0.206\scratch\DML\Apache\httpd-2.4.17-win64-VC14.zip"
          DestinationPath = "D:\httpd-2.4.17-win64-VC14.zip"
          Ensure = "Present"
          Type = "File"
          Credential = $Credential
	  }

	  Archive Apache {
	    Path = "D:\httpd-2.4.17-win64-VC14.zip"
		Destination = "D:\Apache24Install"
        Ensure = "Present" 
		DependsOn = "[File]Apache2_4Installer"
      }

	  File Apache2_4 {
          SourcePath = "D:\Apache24Install\Apache24"
          DestinationPath = "D:\Apache24"
          Ensure = "Present"
          Type = "Directory"
		  Recurse = $true
          DependsOn = "[Archive]Apache"
	  }

	#PHP 5.5.14
	  File PHPInstaller {
          SourcePath = "\\10.13.0.206\scratch\DML\PHP\5.5.14\php-5.5.14-Win32-VC11-x64.zip"
          DestinationPath = "D:\php-5.5.14-Win32-VC11-x64.zip"
          Ensure = "Present"
          Type = "File"
          Credential = $Credential
	  }

	  Archive PHP {
	    Path = "D:\php-5.5.14-Win32-VC11-x64.zip"
		Destination = "D:\php"
        Ensure = "Present" 
		DependsOn = "[File]PHPInstaller"
      }

#	  File vHosts {
#		SourcePath = "\\10.13.0.206\scratch\DML\scripts\WAMP\httpd-vhosts.conf"
#		DestinationPath = "D:\Apache24\conf\extra\httpd-vhosts.conf"
#		Ensure = "Present"
#		MatchSource = $true
#		DependsOn = @("[File]Apache2_4","[Archive]PHP")
#	}

	  File httpdConf {
		SourcePath = "\\10.13.0.206\scratch\DML\scripts\WAMP\httpd.conf"
		DestinationPath = "D:\Apache24\conf\httpd.conf"
		Ensure = "Present"
		MatchSource = $true
		#DependsOn = @("[File]Apache2_4","[Archive]PHP","[File]vHosts")
		DependsOn = @("[File]Apache2_4","[Archive]PHP")
	  }

	  Environment Apache {
		Name = "PATH"
		Ensure = "Present"
		Path = $true
		Value = ";d:\php;d:\Apache24;d:\Apache24\bin;"
	  }

    Script InstallApache
    {
		DependsOn = @("[Environment]Apache","[File]httpdConf")
        SetScript = {
		    try{
				$Quiet = Invoke-Expression "d:\Apache24\bin\httpd.exe -k install"
			} catch {
				$true
			}
        }
		TestScript = {
			if(Get-Service | Where-Object {$_.Name -eq "Apache2.4"}) {
				$true
			} else {
				$false
			}
        }
        GetScript = { 
            Get-Service | Where-Object {$_.Name -eq "Apache2.4"}
		}
    }
#   Package RegisterApache
#   {
#       DependsOn = "[File]httpdConf"
#		Ensure = "Present"
#		Path = "d:\Apache24\bin\httpd.exe"
#		Name = "Apache2.4"
#		ProductID = ""
#		Arguments = "-k install"
#		ReturnCode = 1
#   }

    Service Apache
	{
		Name = "Apache2.4"
        Credential = $Credential1
		StartupType = "Automatic"
		State = "Running"
		DependsOn = @("[Script]InstallApache","[Package]VCRedist2012","[Package]VCRedist2015")
	}
#endregion

#region CreateLogFile
      # Log dir
      File LogDir
      {
         Ensure = "Present"  # You can also set Ensure to "Absent"
         Type = "Directory" # Default is “File”
         DestinationPath = "D:\Logs" # The path where we want to ensure the web files are present
      }
   }
} 
