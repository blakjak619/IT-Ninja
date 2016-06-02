<#  
  .SYNOPSIS   
    Template and examples for Desired State Configuration (DSC) 
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
   HelloWorldConfig
   Start-DscConfiguration -Wait -Verbose -Path .\HelloWorldConfig

   MakeItSo -ConfigurationData $ConfigurationData -Credential (Get-Credential)
   Start-DscConfiguration -Wait -Verbose -Path .\MakeItSo

#> 


#region CVPortalConfig

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
Configuration CVPortalConfigCMC
{
    param ([Parameter(Mandatory=$false)]
        [PSCredential]$Credential,
        [PSCredential]$StudevDomainCred
        )


    Node localhost 
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
#region Registry Settings
        Registry EnableLUA
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            ValueName = "EnableLUA"
            ValueType = "DWord"
            ValueData = "0"
        }
        Registry FilterAdministratorToken
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            ValueName = "FilterAdministratorToken"
            ValueType = "DWord"
            ValueData = "1"
        }
        Registry EnableUIADesktopToggle
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            ValueName = "EnableUIADesktopToggle"
            ValueType = "DWord"
            ValueData = "0"
        }
        Registry ConsentPromptBehaviorAdmin
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            ValueName = "ConsentPromptBehaviorAdmin"
            ValueType = "DWord"
            ValueData = "0"
        }
        Registry ConsentPromptBehaviorUser
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            ValueName = "ConsentPromptBehaviorUser"
            ValueType = "DWord"
            ValueData = "3"
        }
        Registry EnableInstallerDetection
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            ValueName = "EnableInstallerDetection"
            ValueType = "DWord"
            ValueData = "0"
        }
        Registry ValidateAdminCodeSignatures
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            ValueName = "ValidateAdminCodeSignatures"
            ValueType = "DWord"
            ValueData = "0"
        }
        Registry EnableSecureUIAPaths
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            ValueName = "EnableSecureUIAPaths"
            ValueType = "DWord"
            ValueData = "0"
        }
        Registry PromptOnSecureDesktop
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            ValueName = "PromptOnSecureDesktop"
            ValueType = "DWord"
            ValueData = "0"
        }
        Registry EnableVirtualization
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
            ValueName = "EnableVirtualization"
            ValueType = "DWord"
            ValueData = "1"
        }
#endregion
#region Firewall Settings
        Script FWDomainProfile
        {
            SetScript = {
                netsh advfirewall set Domainprofile state off
            }
            TestScript = { 
                $StatusStr = (netsh advfirewall show domainprofile | Select-String "State").ToString()
                while ($StatusStr.Contains("  ")){
                    $StatusStr = $StatusStr -replace "  "," "
                }
                $ProfileState = ($StatusStr -split " ")[1]
                if($ProfileState -eq "OFF"){
                    $true
                } else {
                    $false
                }
            }
            GetScript = {
                $StatusStr = (netsh advfirewall show domainprofile | Select-String "State").ToString()
                while ($StatusStr.Contains("  ")){
                    $StatusStr = $StatusStr -replace "  "," "
                }
                ($StatusStr -split " ")[1]
            }
        }
        Script FWPrivateProfile
        {
            SetScript = {
                netsh advfirewall set Privateprofile state off
            }
            TestScript = { 
                $StatusStr = (netsh advfirewall show privateprofile | Select-String "State").ToString()
                while ($StatusStr.Contains("  ")){
                    $StatusStr = $StatusStr -replace "  "," "
                }
                $ProfileState = ($StatusStr -split " ")[1]
                if($ProfileState -eq "OFF"){
                    $true
                } else {
                    $false
                }
            }
            GetScript = {
                $StatusStr = (netsh advfirewall show privateprofile | Select-String "State").ToString()
                while ($StatusStr.Contains("  ")){
                    $StatusStr = $StatusStr -replace "  "," "
                }
                ($StatusStr -split " ")[1]
            }
        }
        Script FWPublicProfile
        {
            SetScript = {
                netsh advfirewall set Publicprofile state off
            }
            TestScript = { 
                $StatusStr = (netsh advfirewall show Publicprofile | Select-String "State").ToString()
                while ($StatusStr.Contains("  ")){
                    $StatusStr = $StatusStr -replace "  "," "
                }
                $ProfileState = ($StatusStr -split " ")[1]
                if($ProfileState -eq "OFF"){
                    $true
                } else {
                    $false
                }
            }
            GetScript = {
                $StatusStr = (netsh advfirewall show Publicprofile | Select-String "State").ToString()
                while ($StatusStr.Contains("  ")){
                    $StatusStr = $StatusStr -replace "  "," "
                }
                ($StatusStr -split " ")[1]
            }
        }
#endregion
#region .Net Installs
<#
################ .Net 1.1
# It is not possible to manually install the .NET Framework 1.1 on Windows 8, Windows 8.1, Windows Server 2012, or Windows Server 2012 R2. It is no longer supported. 
# If you try to install the package, the following error message is displayed: "Setup cannot continue because this version of the .NET Framework is incompatible with a previously installed one." 
# To solve this problem, install the .NET Framework 3.5 SP1. This version includes the .NET Framework 2.0 (the release that follows the .NET Framework 1.1), which is supported on Windows 8 and Windows 8.1. 
# You should always try to install the application first to determine if it will automatically be updated to a later version of the .NET Framework. If it does not, contact your ISV for an application update.
# See https://msdn.microsoft.com/en-us/library/hh925570%28v=vs.110%29.aspx
        File DotNet1_1
        {
            Ensure = "Present"
            SourcePath = "\\10.13.0.206\scratch\DML\Microsoft\DotNet_Framework\v1.1\dotnetfx.exe"
            Type = "File"
            DestinationPath = "C:\Temp\dotnetfx.exe"
            Credential = $Credential
        }
        Package DotNet1_1
        {
            DependsOn = "[File]DotNet1_1"
            Ensure = "Present"
            Path = "C:\Temp\dotnetfx.exe"
            Name = "dotnetfx"
            ProductID = "CB2F7EDD-9D1F-43C1-90FC-4F52EAE172A1"
        }
        Script RegIIS1_1
        {
            DependsOn = "[Package]DotNet1_1"
            SetScript =
            {
                cd c:\windows\microsoft.net\framework\v1.1.4322
                aspnet_regiis -1
            }
            GetScript =
            {
                $false
            }
            TestScript =
            {
                $false
            }
        }
################ .Net 1.1 SP1
        File DotNet1_SP1
        {
            DependsOn = "[Package]DotNet1_1"
            Ensure = "Present"
            SourcePath = "\\10.13.0.206\scratch\DML\Microsoft\DotNet_Framework\v1.1\NDP1.1sp1-KB867460-X86"
            Type = "File"
            DestinationPath = "C:\Temp\NDP1.1sp1-KB867460-X86"
            Credential = $Credential
        }
        Package DotNet1_SP1
        {
            DependsOn = "[File]DotNet1_SP1"
            Ensure = "Present"
            Path = "C:\Temp\NDP1.1sp1-KB867460-X86.exe"
            Name = "NDP1.1sp1-KB867460-X86"
            ProductID = ""
        }

################ .Net 4.0
# Trying to install the .Net Framework 4.0 Full package on Windows 8 or Windows Server 2012 will fail with the following error message - Microsoft .NET Framework 4 is already part of this 
# operating system and Same or higher version of .NET Framework 4 has already been installed on this computer.
# See https://support.microsoft.com/en-us/kb/2765375
        File DotNet4
        {
            Ensure = "Present"
            SourcePath = "\\10.13.0.206\scratch\DML\Microsoft\DotNet_Framework\v4.0\dotNetFx40_Full_x86_x64.exe"
            Type = "File"
            DestinationPath = "C:\Temp\dotNetFx40_Full_x86_x64.exe"
            Credential = $Credential
        }
        Package DotNet4
        {
            DependsOn = "[File]DotNet4"
            Ensure = "Present"
            Path = "C:\Temp\dotNetFx40_Full_x86_x64.exe"
            Name = "NDP1.1sp1-KB867460-X86"
            ProductID = "8E34682C-8118-31F1-BC4C-98CD9675E1C2"
        }
        Script RegIIS4
        {
            SetScript =
            {
                cd c:\windows\microsoft.net\framework\v4.0.30319
                aspnet_regiis -1
            }
            GetScript =
            {
                $false
            }
            TestScript =
            {
                $false
            }
        }
#>
#endregion
#region WindowsFeature
      # This example ensures the Web Server (IIS) role is installed
      WindowsFeature Application-Server
      {
          Ensure = "Present"
          Name = "Application-Server"
      }
      
      WindowsFeature AS-NET-Framework
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "AS-NET-Framework"  
      }

      WindowsFeature AS-Web-Support
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "AS-Web-Support"  
      }
      
      WindowsFeature AS-Ent-Services
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "AS-Ent-Services"  
      }
      WindowsFeature AS-TCP-Port-Sharing
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "AS-TCP-Port-Sharing"  
      }
      WindowsFeature AS-WAS-Support
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "AS-WAS-Support"  
      }
       
      WindowsFeature AS-HTTP-Activation
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "AS-HTTP-Activation"  
      }
      WindowsFeature AS-TCP-Activation
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "AS-TCP-Activation"  
      }
      
       WindowsFeature AS-Named-Pipes
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "AS-Named-Pipes"  
      }
      
       WindowsFeature AS-Dist-Transaction
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "AS-Dist-Transaction"  
      }
       
       WindowsFeature AS-Incoming-Trans
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "AS-Incoming-Trans"  
      }
      
      WindowsFeature AS-Outgoing-Trans
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "AS-Outgoing-Trans"
      }
          
      WindowsFeature File-Services
      {
          Ensure = "Present"
          Name = "File-Services"
      }
        
      WindowsFeature FS-FileServerr
      {
          Ensure = "Present"
          Name = "FS-FileServer"
      }
      
      WindowsFeature Web-Server
      {
          Ensure = "Present"
          Name = "Web-Server"
      }
       WindowsFeature Web-WebServer
      {
          Ensure = "Present"
          Name = "Web-WebServer"
      }
       WindowsFeature Web-Common-Http
      {
          Ensure = "Present"
          Name = "Web-Common-Http"
      }
       WindowsFeature Web-Static-Content
      {
          Ensure = "Present"
          Name = "Web-Static-Content"
      }
       WindowsFeature Web-Default-Doc
      {
          Ensure = "Present"
          Name = "Web-Default-Doc"
      }
      WindowsFeature Web-Dir-Browsing
      {
          Ensure = "Present"
          Name = "Web-Dir-Browsing"
      }
      WindowsFeature Web-Http-Errors
      {
          Ensure = "Present"
          Name = "Web-Http-Errors"
      } 
      WindowsFeature Web-Http-Redirect
      {
          Ensure = "Present"
          Name = "Web-Http-Redirect"
      } 
      WindowsFeature Web-App-Dev
      {
          Ensure = "Present"
          Name = "Web-App-Dev"
      } 
      WindowsFeature Web-Asp-Net
      {
          Ensure = "Present"
          Name = "Web-Asp-Net"
      } 
      WindowsFeature Web-Net-Ext
      {
          Ensure = "Present"
          Name = "Web-Net-Ext"
      } 
      WindowsFeature Web-ASP
      {
          Ensure = "Present"
          Name = "Web-ASP"
      } 
      WindowsFeature Web-CGI
      {
          Ensure = "Present"
          Name = "Web-CGI"
      } 
      WindowsFeature Web-ISAPI-Ext
      {
          Ensure = "Present"
          Name = "Web-ISAPI-Ext"
      } 
      WindowsFeature Web-ISAPI-Filter
      {
          Ensure = "Present"
          Name = "Web-ISAPI-Filter"
      } 
      WindowsFeature Web-Includes
      {
          Ensure = "Present"
          Name = "Web-Includes"
      }
       WindowsFeature Web-Health
      {
          Ensure = "Present"
          Name = "Web-Health"
      }
      WindowsFeature Web-Http-Logging
      {
          Ensure = "Present"
          Name = "Web-Http-Logging"
      }
      WindowsFeature Web-Log-Libraries
      {
          Ensure = "Present"
          Name = "Web-Log-Libraries"
      }
      WindowsFeature Web-Request-Monitor
      {
          Ensure = "Present"
          Name = "Web-Request-Monitor"
      }
      WindowsFeature Web-Http-Tracing
      {
          Ensure = "Present"
          Name = "Web-Http-Tracing"
      }
      WindowsFeature Web-Custom-Logging
      {
          Ensure = "Present"
          Name = "Web-Custom-Logging"
      }
      WindowsFeature Web-Security
      {
          Ensure = "Present"
          Name = "Web-Security"
      }
      WindowsFeature Web-Basic-Auth
      {
          Ensure = "Present"
          Name = "Web-Basic-Auth"
      }
      WindowsFeature Web-Windows-Auth
      {
          Ensure = "Present"
          Name = "Web-Windows-Auth"
      }
      WindowsFeature Web-Digest-Auth
      {
          Ensure = "Present"
          Name = "Web-Digest-Auth"
      }
      WindowsFeature Web-Client-Auth
      {
          Ensure = "Present"
          Name = "Web-Client-Auth"
      }
      WindowsFeature Web-Cert-Auth
      {
          Ensure = "Present"
          Name = "Web-Cert-Auth"
      }
      WindowsFeature Web-Url-Auth
      {
          Ensure = "Present"
          Name = "Web-url-Auth"
      }
      WindowsFeature Web-Filtering
      {
          Ensure = "Present"
          Name = "Web-Filtering"
      }
      WindowsFeature Web-IP-Security
      {
          Ensure = "Present"
          Name = "Web-IP-Security"
      }
      WindowsFeature Web-Performance
      {
          Ensure = "Present"
          Name = "Web-Performance"
      }
      WindowsFeature Web-Stat-Compression
      {
          Ensure = "Present"
          Name = "Web-Stat-Compression"
      }
      WindowsFeature Web-Dyn-Compression
      {
          Ensure = "Present"
          Name = "Web-Dyn-Compression"
      }
      WindowsFeature Web-Mgmt-Tools
      {
          Ensure = "Present"
          Name = "Web-Mgmt-Tools"
      }
      WindowsFeature Web-Mgmt-Console
      {
          Ensure = "Present"
          Name = "Web-Mgmt-Console"
      }
      WindowsFeature Web-Scripting-Tools
      {
          Ensure = "Present"
          Name = "Web-Scripting-Tools"
      }
      WindowsFeature Web-Mgmt-Service
      {
          Ensure = "Present"
          Name = "Web-Mgmt-Service"
      }
      WindowsFeature Web-Mgmt-Compat
      {
          Ensure = "Present"
          Name = "Web-Mgmt-Compat"
      }
      WindowsFeature Web-Metabase
      {
          Ensure = "Present"
          Name = "Web-Metabase"
      }
      WindowsFeature Web-WMI
      {
          Ensure = "Present"
          Name = "Web-WMI"
      }
      WindowsFeature Web-Lgcy-Scripting
      {
          Ensure = "Present"
          Name = "Web-Lgcy-Scripting"
      }
      WindowsFeature Web-Lgcy-Mgmt-Console
      {
          Ensure = "Present"
          Name = "Web-Lgcy-Mgmt-Console"
      }
      
      WindowsFeature NET-Framework
      {
          Ensure = "Present"
          Name = "NET-Framework" 
          IncludeAllSubFeature = "$true"
      }
      WindowsFeature MSMQ
      {
          Ensure = "Present"
          Name = "MSMQ"
      }
      WindowsFeature MSMQ-Services
      {
          Ensure = "Present"
          Name = "MSMQ-Services"
      }
      WindowsFeature MSMQ-Server
      {
          Ensure = "Present"
          Name = "MSMQ-Server"
      }
      WindowsFeature RSAT
      {
          Ensure = "Present"
          Name = "RSAT"
      }
              
      WindowsFeature RSAT-Role-Tools
      {
           Ensure = "Present"
           Name = "RSAT-Role-Tools"
      }
        
      WindowsFeature RSAT-Web-Server
      {
          Ensure = "Present"
          Name = "RSAT-Web-Server"
      }
        
      WindowsFeature Telnet-Client
      {
          Ensure = "Present"
          Name = "Telnet-Client"
      }
        
      WindowsFeature SNMP-Services
      {
          Ensure = "Present"
          Name = "SNMP-Services"
          IncludeAllSubFeature = "$true"
      }
       
       WindowsFeature WAS
      {
          Ensure = "Present"
          Name = "WAS"
          IncludeAllSubFeature = "$true"
      }
      WindowsFeature PowerShell-ISE
      {
          Ensure = "Present"
          Name = "PowerShell-ISE"
      }
      WindowsFeature Backup-Features
      {
          Ensure = "Present"
          Name = "Backup-Features"
      }
      WindowsFeature Backup
      {
          Ensure = "Present"
          Name = "Backup"
      }
       WindowsFeature Backup-Tools
      {
          Ensure = "Present"
          Name = "Backup-Tools"
      }
       
         
      
      File DotNet1_1File
      {
          SourcePath = "\\10.13.0.206\scratch\DML\CampusVue\ServerStandup\TS\PreReqs\dotnet\v1.1"
          DestinationPath = "C:\Temp\CVStandUp\PreReqs\dotnet\v1.1"
          Ensure = "Present"
          Type = "Directory"
          Recurse = $true # Ensure presence of subdirectories, too
          Credential = $Credential
      }

      Package DotNet1_1 #ResourceName
      {
		  Name = "dotnetfx"
		  Path = "C:\Temp\CVStandUp\PreReqs\dotnet\v1.1\dotnetfx.exe"
		  ProductID = "CB2F7EDD-9D1F-43C1-90FC-4F52EAE172A1"
          Arguments = "/q"
		  Ensure = "Present"
      }
      File EntInstFile
      {
          SourcePath = "\\10.13.0.206\scratch\DML\CampusVue\ServerStandup\TS\PreReqs\EnterpriseInstrumentation"
          DestinationPath = "C:\Temp\CVStandUp\PreReqs\EnterpriseInstrumentation"
          Ensure = "Present"
          Type = "Directory"
          Recurse = $true # Ensure presence of subdirectories, too
          Credential = $Credential
      }
      Package EnterpriseInstrumentation #ResourceName
	  {
		  Name = "EnterpriseInstrumentation"
		  Path = "C:\Temp\CVStandUp\PreReqs\EnterpriseInstrumentation\EnterpriseInstrumentation.msi"
		  ProductID = "9E8A483C-BE5B-4EDC-B649-63E0A47FB779"
		  Ensure = "Present"
          Arguments = "/qn"
          DependsOn = "[Package]DotNet1_1"
      }
     
      File NotepadPlusPlusFile
      {
          SourcePath = "\\10.13.0.206\scratch\DML\Notepad++\npp.6.5.4.Installer.exe"
          DestinationPath = "C:\temp\npp.6.5.4.Installer.exe"
          Ensure = "Present"
          Type = "File"
          Credential = $Credential
      }

      Package NotepadPlusPlus
      { 
          Ensure = "Present"
          Path = "C:\temp\npp.6.5.4.Installer.exe"
          Name ="Notepad++"
          ProductId = ""
          Arguments ="/S"
          DependsOn = "[File]NotepadPlusPlusFile" # ensure the file exists from the copy
      }
      File AdobeReaderFile
      {
        SourcePath = "\\10.13.0.206\scratch\DML\Adobe\AdobeReader11\Reader11.10"
        DestinationPath = "C:\Temp\CVStandUp\Adobe\Reader11"
        Ensure = "Present"
        Type = "Directory"
        Recurse = $true # Ensure presence of subdirectories, too
        Credential = $Credential
      }

      Package AdobeReader #ResourceName
	  {
		  Name = "Adobe Reader 11"
		  Path = "C:\Temp\CVStandUp\Adobe\Reader11\AdbeRdr11010_en_US.exe"
		  ProductID = "AC76BA86-7AD7-1033-7B44-AB0000000001"
		  Ensure = "Present"
          Arguments = "/sAll /rs /msi EULA_ACCEPT=YES"
      }  
      File CrystalReportFiles
      {
        SourcePath = "\\10.13.0.206\scratch\DML\CrystalReports"
        DestinationPath = "C:\temp\CVStandUp\CrystalReports"
        Ensure = "Present"
        Type = "Directory"
        Recurse = $true
        Credential = $Credential
      }
      Package CrystalReportsBasicRuntimeVS #ResourceName
	  {
		  Name = "CR Runtime VS"
		  Path = "C:\Temp\CVStandUp\CrystalReports\CrystalReportsBasicRuntime_VisualStudio2008\CRRedist2008_x64.msi"
		  ProductID = "2BFA9B05-7418-4EDE-A6FC-620427BAAAA3"
		  Ensure = "Present"
          Arguments = "/passive /norestart"
      }
      Package CrystalReportsDotNetFramework #ResourceName
	  {
		  Name = "CR Framework"
		  Path = "C:\Temp\CVStandUp\CrystalReports\CrystalReports_NetFramework\CRRedist2005_x64.msi"
		  ProductID = "E679FCFF-4429-40CC-A7BF-0602261969ED"
		  Ensure = "Present"
          Arguments = "/passive /norestart"
      }
      File CampusInstaller
      {
        SourcePath = "\\10.13.0.206\scratch\CampusVue\CampusVue Releases\16\UpgradePackage"
        DestinationPath = "C:\temp\CVStandUp\CVUE16_Installers"
        Ensure = "Present"
        Type = "Directory"
        Recurse = $true
        Credential = $Credential
      }     
#endregion 
    
}# end Node

} 
#endregion
