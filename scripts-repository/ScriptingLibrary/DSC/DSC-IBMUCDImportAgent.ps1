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
            NodeName="toolucdbld02"
         }
         @{
            NodeName="toolucdbld01"
         }
         #>


    )
}

# used in conjunction with Stig-serverStandup.ps1 -xmlfile UCD.ImportAgent.xml

Configuration BaseUCDImportAgent
{
   param ([Parameter(Mandatory=$false)]
        [PSCredential]$Credential
        )

   # A Configuration block can have zero or more Node blocks
   Node $AllNodes.NodeName 
   {
#region VS2010

      Package VS2010
      { 
        Ensure = "Present"
        Path = "\\10.13.0.206\scratch\DML\Microsoft\Visual_Studio\2010\Visual Studio 2010 Professional\Setup\setup.exe"
        Name = "Microsoft Visual Studio 2010 Professional - ENU"
        ProductId = ''
        Arguments = '/q msipassthru=BEGIN"PIDKEY=D23HKF9CWVVXMY27KPY9WYFDP"END'
        Credential = $Credential
      }

#endregion
#region VS2013 (not needed at this time) 
<#      Package VS2013
        # Issues with installing
        #    From the Event log: Product: Microsoft Visual Studio Professional 2013 -- Error 26403.Failed to add user to group.  (-2147463168   SYSTEM   Performance Log Users   )
        #    This is a known issue with DSC and SCCM:
        #      https://social.msdn.microsoft.com/Forums/vstudio/en-US/60f57470-ac4e-4d40-8900-6599b4dca66f/visual-studio-2013-unattended-installation-fails-when-deployed-via-sccm-2012?forum=vssetup
        #      https://connect.microsoft.com/VisualStudio/feedbackdetail/view/978236/visual-studio-2013-is-not-deployable-with-system-center-configuration-manager-2012-r2
      { 
        Ensure = "Present"
        Path ="\\10.13.0.206\scratch\DML\Microsoft\Visual_Studio\2013\VS2013ULTIMATE_u4\InstallFiles\vs_ultimate.exe"
        Path = "\\10.13.0.206\scratch\DML\Microsoft\Visual_Studio\2013\VS2013\InstallFiles\vs_ultimate.exe"
        Name = "Microsoft Visual Studio Ultimate 2013 - ENU"
        ProductId = ''
        # Arguments = '/AdminFile "\\10.13.0.206\scratch\DML\Microsoft\Visual_Studio\2013\VS2013\InstallFiles\AdminDeployment.xml" /Norestart /quiet'
        Arguments = '/noweb /full /quiet /norestart /ProductKey BQDDDTT9D6PYWRVX8YFBJHRWV'
        Credential = $Credential
      }
#>
#endregion

#region TortoiseSVN
    Package TortoiseSVN
      { 
        Ensure = "Present"
        Path = "\\10.13.0.206\scratch\DML\TortoiseSVN\TortoiseSVN-1.8.6.25419-x64-svn-1.8.8.msi"
        Name = "TortoiseSVN 1.8.6.25419 (64 bit)"
        ProductId = '0DD7C466-163D-4901-AD4B-E78EEFD7FE01'
        Arguments = '/q ADDLOCAL=ALL /log c:\temp\tortoiseSVNSetup.log'
        Credential = $Credential
      }
#endregion


   }
} 

# to generate MOF
# execute script in powershell ISE
# call with: BaseUCDImportAgent -ConfigurationData $ConfigurationData -Credential (Get-Credential)