﻿<#  
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


#region CVAPIConfig

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
Configuration CVTSConfigTLU
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

      WindowsFeature AS-Ent-Services
      {
          Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
          Name = "AS-Ent-Services"  
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
      
      WindowsFeature Remote-Desktop-Services
      {
          Ensure = "Present"
          Name = "Remote-Desktop-Services"
      }
      
      WindowsFeature RDS-RD-Server
      {
          Ensure = "Present"
          Name = "RDS-RD-Server"
      }
         
      WindowsFeature NET-Framework
      {
          Ensure = "Present"
          Name = "NET-Framework" 
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
        
      WindowsFeature RSAT-RDS
      {
          Ensure = "Present"
          Name = "RSAT-RDS"
      }
      
       WindowsFeature RSAT-RDS-RemoteApp
      {
          Ensure = "Present"
          Name = "RSAT-RDS-RemoteApp"
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
          IncludeAllSubFeature = "true"
      }
       
       WindowsFeature WAS
      {
          Ensure = "Present"
          Name = "WAS"
          IncludeAllSubFeature = "true"
      }
#endregion  
#region File 
      # temp directory
      File TempDir
      {
        Ensure = "Present" 
        Type = "Directory" 
        DestinationPath = "C:\temp" 
                
      }

      # Log directory
      File LogDir
      {
        SourcePath = "\\10.13.0.206\scratch\DML\CampusVue\ServerStandup\Logs"
        Ensure = "Present"  # You can also set Ensure to "Absent"
        Type = "Directory“ # Default is “File”
        DestinationPath = "c:\temp\cvstandup\Logs" # The path where we want to ensure the web files are present
        Credential = $Credential
      }
      
#region 3rd Party Install
      # Install 3rd Party Software: Copy Installer and Install Packages
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
      File RightFaxClientPrintProcessorFile
      {
        SourcePath = "\\10.13.0.206\scratch\DML\RightFax"
        DestinationPath = "C:\Temp\CVStandUp\RightFax"
        Ensure = "Present"
        Type = "Directory"
        Recurse = $true # Ensure presence of subdirectories, too
        Credential = $Credential
      }
      Package VS2012_vcredist_x86 #ResourceName
	  {
		  Name = "RightFaxPrintProcessorPrereq1"
		  Path = "C:\Temp\cvstandup\RightFax\RightFax10.6_Prereqs\VS2012_vcredist_x86.exe"
		  ProductID = "3D6AD258-61EA-35F5-812C-B7A02152996E"
		  Ensure = "Present"
          Arguments = "/q /norestart"
      }
      Package vstor_redist #ResourceName
	  {
		  Name = "RightFaxPrintProcessorPreReq2"
		  Path = "C:\Temp\cvstandup\RightFax\RightFax10.6_Prereqs\vstor_redist.exe"
		  ProductID = "B143BE44-8723-315E-9413-011C55873C0E"
		  Ensure = "Present"
          Arguments = "/q /norestart"
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
      File MSO2010File
      {
        SourcePath = "\\10.13.0.206\scratch\DML\Microsoft\Office2010"
        DestinationPath = "C:\Temp\CVStandUp\Office2010"
        Ensure = "Present"
        Type = "Directory"
        Recurse = $true # Ensure presence of subdirectories, too
        Credential = $Credential
      }
       Package MSO2010 #ResourceName
	  {
		  Name = "Microsoft Office 2010"
		  Path = "C:\Temp\CVStandUp\Office2010\setup.exe"
		  ProductID = "90140000-0011-0000-0000-0000000FF1CE"
		  Ensure = "Present"
          Arguments = "/AdminFile cvue.MSP"
      }
      File ImageNow6File
      {
        SourcePath = "\\10.13.0.206\scratch\DML\CampusVue\ServerStandup\TS\ImageNow6"
        DestinationPath = "C:\Temp\CVStandUp\ImageNow6"
        Ensure = "Present"
        Type = "Directory"
        Recurse = $true # Ensure presence of subdirectories, too
        Credential = $Credential
      }
      Package ImageNow6 #ResourceName
      {
          Name = "ImageNow6"
          Path = "C:\Temp\CVStandUp\ImageNow6\ClientSetup_6.6.0.exe"
          ProductID = "46A3962C-8AD3-4854-B6F8-5F2A7D683F1F"
          Ensure = "Present"
          Arguments = "/s /V`"/l*v C:\Temp\ImageNow.log /qb!- ADDLOCAL=Accusoft,AdminHelp,DemoImages,ImageNowClient,KeyView,LeadTools,OneDirectory,Pixtran,SystemFiles,UserHelp IN_PROFILENAME=DEV IN_SERVER_NAME=dev-inapp01 IN_PORT_NO=6000 STARTMENUICON=Yes DESKTOPICON=YES QUICKLANCHICON=YES REMOVEOLDERVERSIONS=YES"
      }
      File AdobeReaderFile
      {
        SourcePath = "\\10.13.0.206\scratch\DML\AdobeReader10.11"
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
      
      Package RightFaxPrintProcessor #ResourceName
	  {
		  Name = "RightFaxPrintProcessor"
		  Path = "`"C:\Temp\cvstandup\RightFax\RightFaxClientInstall_10.6\RightFax\Setup\RightFax Print Processor x64.msi`""
		  ProductID = "3E5E538D-D4B8-4553-860A-B09419F648BF"
		  Ensure = "Present"
          Arguments = "`"/qn /log `"C:/RFInst-PP.log`""
       }
      Package RightFaxPrintClient #ResourceName
	  {
		  Name = "RightFaxClient"
		  Path = "C:\Temp\cvstandup\RightFax\RightFaxClientInstall_10.6\RightFax Product Suite - Client.msi"
		  ProductID = "E60146B0-C083-47BE-BD6B-EFA57AC8D9B1"
		  Ensure = "Present"
          Arguments = "/qn /log `"C:\Temp\CVStandUp\Logs\RFInst.log`" REBOOT=ReallySuppress RUNBYRIGHTFAXSETUP=2 CONFIGUREFAXCTRL=1 CONFIGUREFAXUTIL=1 RFSERVERNAME=PUGBSSC1FAX001 ADDLOCAL=FaxUtil,FaxCtrl RFSERVERNAME=10.10.99.11"
      }
     
#endregion 
    
}# end Node

} 
#endregion
