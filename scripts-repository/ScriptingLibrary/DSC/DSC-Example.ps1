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

#region todo
<# 
split this into a "readme/examples" and a true template for usage
#>
#endregion

#region HelloWorldConfig
<# 
A "simple" DSC example
end state: file named C:\temp\HelloWorld.txt, contents: HelloWorld!
of note: each configuration resource needs a unique name
#>

Configuration HelloWorldConfig 
{
    Node localhost 
    {
        # create the temp directory
        File TempDir
        {
            Ensure = "Present" 
            Type = "Directory" 
            DestinationPath = "C:\temp" 
                
        }
        # create the file only AFTER the temp directory (DependsOn)
        File TestFile 
        {
            Ensure = "Present"
            DestinationPath = "c:\temp\HelloWorld.txt"
            Contents = "Hello World!"
            DependsOn = "[File]TempDir"  # note that the resource type [File] must precede the resource name TempDir
        }

    }
} 
#endregion HelloWorldConfig

#region MakeItSo
<# 
Description: This is a more complex DSC that has many more resources specified
End state: a basic IIS web server 
Overview
$ConfigurationData - a parameter to pass ConfigurationData to the Configuration (e.g. credentials)

Note that individual file resources that copy (source/destination single files) must have the source and destination full paths specified

#>

<# 
Parameter: $ConfigurationData 
Of note:
  passing credentials and node information
credit:
http://www.powershellmagazine.com/2013/09/26/using-the-credential-attribute-of-dsc-file-resource/
http://stackoverflow.com/questions/23346901/powershell-dsc-how-to-pass-configuration-parameters-to-scriptresources
#>

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName="*"
            PSDscAllowPlainTextPassword=$true
         }
         @{
            NodeName="localhost"
         }
         <#
         @{
            NodeName="dsbxucdapp02"
         }
         @{
            NodeName="dsbxucdapp01"
         }
         #>


    )
} #end $ConfigurationData

Configuration MakeItSo
{
   param ([Parameter(Mandatory=$false)]
        [PSCredential]$Credential
        )

   # A Configuration block can have zero or more Node blocks
   Node $AllNodes.NodeName 
   {
#region WindowsFeature
      # This example ensures the Web Server (IIS) role is installed
      WindowsFeature webserver
      {
        Ensure = "Present" # To uninstall the role, set Ensure to "Absent"
        Name = "Web-WebServer"  
        IncludeAllSubFeature = "true"
      }
      
      WindowsFeature webmgmt
      {
        Ensure = "Present" 
        Name = "Web-Mgmt-Tools"  
        IncludeAllSubFeature = "true"
      }

      WindowsFeature WAS
      {
        Ensure = "Present" 
        Name = "WAS"  
        IncludeAllSubFeature = "true"
      }
      
      WindowsFeature Net-Framework-Features
      {
        Ensure = "Present" 
        Name = "Net-Framework-Features"  
        IncludeAllSubFeature = "true"
      }

      WindowsFeature NET-Framework-45-Features
      {
        Ensure = "Present"
        Name = "NET-Framework-45-Features"  
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
        Ensure = "Present"  # You can also set Ensure to "Absent"
        Type = "Directory“ # Default is “File”
        DestinationPath = "D:\Logs" # The path where we want to ensure the web files are present
      }

      # Server Standup Scripts
      File ServerStandupScripts
      { 
        Ensure = "Present"  # You can also set Ensure to "Absent"
        Type = "Directory“ # Default is “File”
        SourcePath = "\\10.13.0.206\scratch\DML\scripts"
        DestinationPath = "C:\Scripts\BridgepointScriptingLibrary"
        MatchSource = $True
        Recurse = $True
        Credential = $Credential
      }
      Log AfterServerStandupScriptsCopy
      {
        # The message below gets written to the Microsoft-Windows-Desired State Configuration/Analytic log
        Message = "Finished running the file resource with ID ServerStandupScripts"
        DependsOn = "[File]ServerStandupScripts" # This means run "ServerStandupScripts" first.
      }

#endregion 

#region Services
    Service WindowsActivation
    {
        Name = "WAS"
        StartupType = "Automatic"
        State = "Running"
    }
    Service MSDistributedTransactionCoordinator
    {
        Name = "MSDTC"
        StartupType = "Automatic"
        State = "Running"
    }
    Service WebService
    {
        Name = "W3SVC"
        StartupType = "Automatic"
        State = "Running"
    }
#endregion

#region MS Webdeploy install
      # install webdeploy: copy msi file locally, and install
      File WebDeployFile
      {
        SourcePath = "\\10.13.0.206\scratch\DML\Microsoft\Webdeploy\V3.0\WebDeploy_amd64_en-US.msi"
        DestinationPath = "C:\temp\WebDeploy_amd64_en-US.msi"
        Ensure = "Present"
        Type = "File"
        Credential = $Credential
      }

      Package WebDeploy
      { 
        Ensure = "Present"
        Path = "C:\temp\WebDeploy_amd64_en-US.msi"
        Name = "Microsoft Web Deploy 3.0"
        ProductId = "AA72C306-30BE-4BB1-9E42-59552BAD2CDF"
        Arguments = "/q log c:\temp\WebDeploy.log ADDLOCAL=MSDeployFeature,MSDeployAgentFeature,MSDeployUIFeature,DelegationUIFeature,MSDeployWMSVCHandlerFeature"
        DependsOn = "[File]WebDeployFile" # ensure the file exists from the copy
      }

      # check webeploySnapIn, requires msdeploy 3.0
      Script WebDeploySnapIn
      {
        # nothing really to set, so just write-verbose
        SetScript = {
            write-verbose "running WebDeploySnapIn.SetScript";
        }
        TestScript = {
            write-verbose "running WebDeploySnapIn.TestScript";
            $registered = $false; # set false, the following logic will change to true if found
            if ( $null -ne (Get-PSSnapIn -Registered | where { $_.Name -eq "WebDeploySnapIn3.0" } ) )
              {
                $registered = $true;
              }
            return ($registered)

        }
        GetScript = {
            write-verbose "running WebDeploySnapIn.GetScript";
            $registeredInfo = Get-PSSnapIn -Registered | where { $_.Name -eq "WDeploySnapin3.0" } 
            return @{ 
                WebDeploySnapInName = $registeredInfo.Name
                WebDeploySnapInDescription = $registeredInfo.Description
                WebDeploySnapInApplicationBase = $registeredInfo.ApplicationBase
                WebDeploySnapInModuleName = $registeredInfo.ModuleName
            }

        }
        DependsOn = "[Package]WebDeploy"
      }
#endregion

#region install Notepad++ (executable)
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
#endregion 
#region Archive
# Note: ideally, use the .zip and archive provider, however, extraction for large (100MB+ .zip with many files will take a long time (e.g. 1 hour for 9000+files)
      File DSCArchiveTestFile
      {
        SourcePath = "\\10.13.0.206\scratch\DML\Microsoft\Powershell\DSCArchiveTest.zip"
        DestinationPath = "C:\temp\DSCArchiveTest.zip"
        Ensure = "Present"
        Type = "File"
        Credential = $Credential
      }

      Archive DSCArchiveTest 
      {
        Ensure = "Present"  # You can also set Ensure to "Absent"
        Path = "C:\temp\DSCArchiveTest.zip"
        Destination = "C:\temp\"
        DependsOn = "[File]DSCArchiveTestFile"
      } 

#endregion      
   }# end Node

} 
#endregion
