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


#region CMCSecurityConfig

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
Configuration CMCSecurityConfigME1D
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
#region Windows Features
        WindowsFeature EntServices
        {
            Ensure = "Present"
            Name = "AS-Ent-Services"
        }
        WindowsFeature NETFramework
        {
            Ensure = "Present"
            Name = "AS-NET-Framework"
        }
        WindowsFeature WAS-Support
        {
            Ensure = "Present"
            Name = "AS-WAS-Support"
        }
        WindowsFeature HTTP-Activation
        {
            Ensure = "Present"
            Name = "AS-HTTP-Activation"
        }
        WindowsFeature MSMQ-Activation
        {
            Ensure = "Present"
            Name = "AS-MSMQ-Activation"
        }
        WindowsFeature TCP-Activation
        {
            Ensure = "Present"
            Name = "AS-TCP-Activation"
        }
        WindowsFeature Named-Pipes
        {
            Ensure = "Present"
            Name = "AS-Named-Pipes"
        }
        WindowsFeature Incoming-Trans
        {
            Ensure = "Present"
            Name = "AS-Incoming-Trans"
        }
        WindowsFeature Outgoing-Trans
        {
            Ensure = "Present"
            Name = "AS-Outgoing-Trans"
        }
        WindowsFeature WAS
        {
            Ensure = "Present"
            Name = "WAS"
        }
        WindowsFeature WAS-Process-Model
        {
            Ensure = "Present"
            Name = "WAS-Process-Model"
        }
        WindowsFeature WAS-NET-Environment
        {
            Ensure = "Present"
            Name = "WAS-NET-Environment"
        }
        WindowsFeature WAS-Config-APIs
        {
            Ensure = "Present"
            Name = "WAS-Config-APIs"
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
        WindowsFeature Web-ISAPI-Filtercc
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
            Name = "Web-Url-Auth"
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
        WindowsFeature NET-Framework-Core
        {
            Ensure = "Present"
            Name = "NET-Framework-Core"
        }
        WindowsFeature XPS-Viewer
        {
            Ensure = "Present"
            Name = "XPS-Viewer"
        }
        WindowsFeature NET-HTTP-Activation
        {
            Ensure = "Present"
            Name = "NET-HTTP-Activation"
        }
        WindowsFeature NET-Non-HTTP-Activ
        {
            Ensure = "Present"
            Name = "NET-Non-HTTP-Activ"
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
        WindowsFeature SNMP-Service
        {
            Ensure = "Present"
            Name = "SNMP-Service"
        }
        WindowsFeature SNMP-WMI-Provider
        {
            Ensure = "Present"
            Name = "SNMP-WMI-Provider"
        }
        WindowsFeature Telnet-Client
        {
            Ensure = "Present"
            Name = "Telnet-Client"
        }
        WindowsFeature windows-server-backup
        {
            Ensure = "Present"
            Name = "windows-server-backup"
        }
#endregion
#region Hotfixes
# KB2545479 - COM+ running on 2008 R2
# KB2554746-v2 = MSMQ fails to start after reboot on Windows 2008 R2
#endregion
#region IIS
        File CMCSecurityServiceDir
        {
            DependsOn = "[Script]FormatDisk1"
            Ensure = "Present"
            Type = "Directory"
            SourcePath = "\\10.13.0.206\scratch\DML\CampusVue\SecurityServer\CampusVue Security Server\CampusVue_Security_Server_Standup\Source-ME1D"
            Credential = $Credential
            DestinationPath = "d:\inetpub\wwwroot\campusportal\cmcsecurityservice"
            Recurse = $true
        }
        Script CreateCMCSecurityServiceAppPool
        {
            DependsOn = "[WindowsFeature]Web-WebServer"
            SetScript = 
            {
                Import-Module WebAdministration
                cd IIS:/AppPools

                $appPool = New-Item "CMCSecurityService"
                $appPool | Set-ItemProperty -Name "managedRuntimeVersion" -Value "v2.0"
                $appPool | Set-ItemProperty -Name "managedPipelineMode" -Value "Integrated"
                $appPool | Set-ItemProperty -Name processModel -Value @{identityType="NetworkService"}
            }
            TestScript =
            {
                Import-Module WebAdministration

                if((ls IIS:\AppPools\ | Where-Object {$_.Name -eq "CMCSecurityService"}).Name -eq "CMCSecurityService") {
                    return $true
                } else {
                    return $false
                }
            }
            GetScript =
            {
                Import-Module WebAdministration
                (ls IIS:\AppPools\ | Where-Object {$_.Name -eq "CMCSecurityService"}).Name
            }
        }
        Script CreateCMCSecurityServiceWebSite
        {
            DependsOn = @("[WindowsFeature]Web-WebServer","[File]CMCSecurityServiceDir")
            SetScript = 
            {
                Import-Module WebAdministration
                cd IIS:/Sites
                $webSite = New-Item "CMCSecurityService" -binding @{protocol="http";bindingInformation=":80:"} -physicalPath "d:\inetpub\wwwroot\campusportal\cmcsecurityservice"
            }
            TestScript =
            {
                Import-Module WebAdministration
                if((ls IIS:\Sites\ | Where-Object {$_.Name -eq "CMCSecurityService"}).Name -eq "CMCSecurityService") {
                    return $true
                } else {
                    return $false
                }
            }
            GetScript =
            {
                Import-Module WebAdministration
                (ls IIS:\Sites\ | Where-Object {$_.Name -eq "CMCSecurityService"}).Name
            }
        }
        Script CreateCMCSecurityServiceApp
        {
            DependsOn = @("[Script]CreateCMCSecurityServiceWebSite","[Script]CreateCMCSecurityServiceAppPool")
            SetScript = 
            {
                Import-Module WebAdministration
                New-WebApplication -Name CMCSecurityService -Site CMCSecurityService -applicationPool "CMCSecurityService" -physicalPath "d:\inetpub\wwwroot\campusportal\cmcsecurityservice"
            }
            TestScript =
            {
                Import-Module WebAdministration
                #if((ls iis:\Sites | ?{$_.Name -eq "CMCSecurityService"} | Select ApplicationPool).ApplicationPool -eq "CMCSecurityService"){
                if((ls IIS:\Sites\CMCSecurityService | ?{$_.NodeType -eq "application"}).Name -eq "CMCSecurityService"){
                    return $true
                } else {
                    return $false
                }
            }
            GetScript =
            {
                Import-Module WebAdministration
                (ls iis:\Sites | ?{$_.Name -eq "CMCSecurityService"} | Select ApplicationPool).ApplicationPool
            }
        }

#endregion
    }
} 
#endregion CMCSecurityConfig