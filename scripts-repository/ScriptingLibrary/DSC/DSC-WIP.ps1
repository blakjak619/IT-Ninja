<#  
  .SYNOPSIS   
    Template for Desired State Configuration (DSC) for Web Server
  .DESCRIPTION
    This is a template file for DSC that can be used for WebServer
    Note: For DML (Definitive Media Library / SMB share) access, use the "bridgepoint\svc_dsc_ro" AD account

   .LINK
    http://technet.microsoft.com/en-us/library/dn249918.aspx
  .EXAMPLE  
   . .\DSC-BaseWebServer.ps1
   BaseWebServer -ConfigurationData $ConfigurationData -Credential (Get-Credential)
   Start-DscConfiguration -Wait -Verbose -Path .\BaseWebServer
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
Configuration BaseWIPServer
{
    param ([Parameter(Mandatory=$false)]
        [PSCredential]$Credential
        )

   Node $AllNodes.NodeName 
   {
		LocalConfigurationManager {
			RebootNodeIfNeeded  = $True
		}
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
#region Folders
      # Log dir
      File LogDir
      {
         Ensure = "Present"  # You can also set Ensure to "Absent"
         Type = "Directory" # Default is “File”
         DestinationPath = "D:\Logs" # The path where we want to ensure the web files are present
        # DependsOn = "[WindowsFeature]webserver"  # This ensures that MyRoleExample completes successfully before this block runs
      }
#endregion
#region PHP
	#PHP 7.0.2
	  File PHPInstaller {
          SourcePath = "\\10.13.0.206\scratch\DML\PHP\7.0.2\php-7.0.2-nts-Win32-VC14-x64.zip"
          DestinationPath = "D:\php-7.0.2-nts-Win32-VC14-x64.zip"
          Ensure = "Present"
          Type = "File"
          Credential = $Credential
	  }

	Archive PHP {
	    Path = "D:\php-7.0.2-nts-Win32-VC14-x64.zip"
		Destination = "D:\php"
        Ensure = "Present" 
		DependsOn = "[File]PHPInstaller"
	}

	script GrantPHPAccess {
		SetScript = {
			$cmd = "c:\windows\system32\icacls.exe --% d:\php /grant IIS_IUSRS:(OI)(CI)F"
			Invoke-Expression $cmd
		}
		TestScript = {
			#Form a comparison string
			$TestString = "*IIS_IUSRS Allow FullControl"

			#Get the object's permissions
			$permArray = (Get-Item "d:\php").GetAccessControl().AccessToString -split "`n"

			# Loop thru the array, trimming multiple spaces and comparing to test string. If you have a match then that permission is set, stop checking
			foreach($permSet in $permArray){
				if($permSet -replace '\s+', ' ' -like $TestSTring){
					return $true
				}
			}

			return $false
		}
		GetScript = {
			#Form a comparison string
			$TestString = "*IIS_IUSRS Allow FullControl"

			#Get the object's permissions
			$permArray = (Get-Item "d:\php").GetAccessControl().AccessToString -split "`n"

			# Loop thru the array, trimming multiple spaces and comparing to test string. If you have a match then that permission is set, stop checking
			foreach($permSet in $permArray){
				if($permSet -replace '\s+', ' ' -like $TestSTring){
					return $permSet
				}
			}

			return $false
		}
	}
#end region
#region features
# sub: all sub-features
     foreach ($Feature in @("Web-Server","Web-Mgmt-Tools","WAS","Net-Framework-Features","NET-Framework-45-Features")) 
     {    
      WindowsFeature $Feature
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = $Feature 
          IncludeAllSubFeature = "true"
      }
     } # end loop
#endregion 
#region VC++ 2015
      File VCRedist201564 {
          SourcePath = "\\10.13.0.206\scratch\DML\Microsoft\vcredist\2015\vc_redist.x64.exe"
          DestinationPath = "C:\Temp\vc_redist.x64.exe"
          Ensure = "Present"
          Type = "File"
          Credential = $Credential
      }
      Package VCRedist201564 {
		  Name = "VCRedist201564"
		  Path = "C:\Temp\vc_redist.x64.exe"
		  ProductID = "BC958BD2-5DAC-3862-BB1A-C1BE0790438D"
		  Ensure = "Present"
         Arguments = "/install /passive /norestart /Reboot=ReallySuppress"
         DependsOn = "[File]VCRedist201564"
      }

      File VCRedist201532 {
          SourcePath = "\\10.13.0.206\scratch\DML\Microsoft\vcredist\2015\vc_redist.x86.exe"
          DestinationPath = "C:\Temp\vc_redist.x86.exe"
          Ensure = "Present"
          Type = "File"
          Credential = $Credential
      }
      Package VCRedist201532 {
		  Name = "VCRedist201532"
		  Path = "C:\Temp\vc_redist.x86.exe"
		  ProductID = "BE960C1C-7BAD-3DE6-8B1A-2616FE532845"
		  Ensure = "Present"
         Arguments = "/install /passive /norestart /Reboot=ReallySuppress"
         DependsOn = "[File]VCRedist201532"
      }
#endredgion
#region IIS Configuration
        Script bpiIISModule
        {
            SetScript = {
                New-WebHandler -Name "PHP_via_FastCGI" -Path "*.php" -Verb "*" -Modules "FastCgiModule" -ScriptProcessor "D:\php\php-cgi.exe" -ResourceType "Either" -RequiredAccess "Script"
				$ValueObj = @{"fullPath" = "d:\php\php-cgi.exe"}

				Add-WebConfiguration -Filter //system.webServer/fastCGI -Value $ValueObj
            }
            TestScript = { 
                $webhand = Get-WebHandler -Name "PHP_via_FastCGI"
				if($webhand){
					$TestResult = $true
				} else {
					$TestResult = $false
				}
				$TestResult
            }
            GetScript = { 
                Get-WebHandler -Name "PHP_via_FastCGI"
            }
        }
#endregion

   }
} 