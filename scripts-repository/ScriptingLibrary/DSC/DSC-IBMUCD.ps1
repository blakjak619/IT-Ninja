<# credit
http://www.powershellmagazine.com/2013/09/26/using-the-credential-attribute-of-dsc-file-resource/
https://technet.microsoft.com/en-us/library/dn249925.aspx

script
http://blog.cosmoskey.com/uncategorized/a-look-at-the-dsc-script-resource/
http://stackoverflow.com/questions/23346901/powershell-dsc-how-to-pass-configuration-parameters-to-scriptresources
http://serverfault.com/questions/617031/desired-state-config-script-resource
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
}


Configuration BaseUCDServer
{
   param ([Parameter(Mandatory=$false)]
        [PSCredential]$Credential
        )

   # A Configuration block can have zero or more Node blocks
   Node $AllNodes.NodeName 
   {
#region iControlSnapIn
      File iControlFiles
      {
        SourcePath = "\\10.13.0.206\scratch\DML\Microsoft\Powershell\PSSnapIn\F5\iControlSnapInSetup.msi"
        DestinationPath = "C:\temp\iControlSnapInSetup.msi"
        Ensure = "Present"
        Type = "File"
        Credential = $Credential
      }

      # http://technet.microsoft.com/en-us/library/dn282132.aspx
      Package iControlSnapIn
      { 
        Ensure = "Present"
        Path = "C:\scripts\tmp\iControlSnapInSetup.msi"
        Name = "iControlSnapIn"
        ProductId = "8D6D104F-B72F-4968-BAE9-04B157BE2C36"
        Arguments = "/q /log c:\temp\F5iControlSnapInSetup.log"
        DependsOn = "[File]iControlFiles"
      }

      Script f5setupSnapIn 
      {
        SetScript = {
            write-verbose "running f5setupSnapIn.SetScript";
            # pulled directly from setupSnapIn.ps1
             $assembly = "C:\Program Files (x86)\F5 Networks\iControlSnapIn\iControlSnapin.dll"
             <#
             $installUtil = "$env:windir\Microsoft.Net\Framework\v2.0.50727\installUtil.exe";
             Set-Alias installUtil $installUtil;
             installUtil $assembly /LogToConsole=false /LogFile=;
             $installUtil = "$env:windir\Microsoft.Net\Framework64\v2.0.50727\installUtil.exe";
             Set-Alias installUtil $installUtil;
             installUtil $assembly /LogToConsole=false /LogFile=;
             #>
             foreach ($platform in ("", "64") )
              {
                write-verbose "Registering $assembly on platform '$platform'";
                $installUtil = "$env:windir\Microsoft.Net\Framework${platform}\v2.0.50727\installUtil.exe";
                if ( [System.IO.File]::Exists($installUtil) )
                {
                  Set-Alias installUtil $installUtil;
                  installUtil $assembly /LogToConsole=false /LogFile=;
                }
              }
             }
        TestScript = {
            # pulled directly from setupSnapIn.ps1
            write-verbose "running f5setupSnapIn.TestScript";
            $registered = $false;
            if ( $null -ne (Get-PSSnapIn -Registered | where { $_.Name -eq "iControlSnapIn" } ) )
              {
                $registered = $true;
              }
            return ($registered)

        }
        GetScript = {
            write-verbose "running f5setupSnapIn.GetScript";
            $registeredInfo = Get-PSSnapIn -Registered | where { $_.Name -eq "iControlSnapIn" } 
            return @{ 
                iControlName = $registeredInfo.Name
                iControlDescription = $registeredInfo.Description
                iControlPath = $registeredInfo.ApplicationBase
                iControlModule = $registeredInfo.ModuleName
            }

        }
        DependsOn = "[Package]iControlSnapIn"  

      }#
#endregion
#region IBM UrbanCode Deploy installer files  
      
      # copy locally first then extract, so not to extract across the network
      File IBMUCD
      {
        SourcePath = "\\10.13.0.206\scratch\DML\Urbancode\uDeploy\6.1\IBM_UCD_SERVER_6.1.1.3.zip"
        DestinationPath = "C:\temp\IBM_UCD_SERVER_6.1.1.3.zip"
        Ensure = "Present"
        Type = "File"
        Credential = $Credential
      }
      <#
      # ideally, use the .zip and archive provider, however, extraction is taking a long time (1 hour for 9000+files) 
      # more than likely due to default checksum
      Archive IBMUCD {
        Ensure = "Present"  # You can also set Ensure to "Absent"
        Path = "C:\temp\IBM_UCD_SERVER_6.1.0.4.zip"
        Destination = "C:\temp\ucd6.1"
        DependsOn = "[File]IBMUCD"
      } 
      #>
      # copy udclient
      File IBMUDClient
      {
        SourcePath = "\\10.13.0.206\scratch\DML\Urbancode\uDeploy\6.1\udclient"
        DestinationPath = "C:\udclient\"
        Ensure = "Present"
        Type = "Directory"
        Recurse = $True
        Credential = $Credential
      }
      File UCDReadme 
      {
         Ensure = "Present"
         DestinationPath = "c:\temp\README_UCD.txt"
         Contents = "Please extract the IBM Deploy c:\temp\IBM_UCD*.zip to c:\temp\ibm-ucd-server"
      }
      File SQLJDBC
      {
        SourcePath = "\\10.13.0.206\scratch\DML\Java\JDBC\Microsoft JDBC Driver 4.1 for SQL Server\sqljdbc_4.1\enu\sqljdbc41.jar"
        DestinationPath = "C:\temp\ibm-ucd-install\lib\ext\sqljdbc41.jar"
        Ensure = "Present"
        Type = "File"
        Credential = $Credential
        # DependsOn = "[Archive]IBMUCD" # if the archive ever speeds up
        DependsOn = "[File]UCDReadme"
      }
      # 
      # add the svc_udeploy account to admin group
      Group UCDAdmins
      {
        GroupName = "Administrators"
        MembersToInclude = "bridgepoint\svc_udeploy"
        Credential = $Credential
      }
      # grant svc_udeploy log on as a service
      Script SeServiceLogonRight 
      {
        SetScript = {
            write-verbose "running SeServiceLogonRight.SetScript";
            $right="SeServiceLogonRight" 
            $account="bridgepoint\svc_udeploy"
            $sidstr = $account
             try {
	                $ntprincipal = new-object System.Security.Principal.NTAccount "$account"
	                $sid = $ntprincipal.Translate([System.Security.Principal.SecurityIdentifier])
	                $sidstr = $sid.Value.ToString()
                    $sidstr = "*$($sidstr)"   # sids always start with *
                } catch {
	                $sidstr = $null
                }

            $tmp = [System.IO.Path]::GetTempFileName()
            secedit.exe /export /cfg "$($tmp)" 
            $c = Get-Content -Path $tmp 
            Remove-Item $tmp -Force
            $currentSetting = ""
            foreach($s in $c) {
	            if( $s -like "$right*") {
		            $x = $s.split("=",[System.StringSplitOptions]::RemoveEmptyEntries)
		            $currentSetting = $x[1].Trim()
	            }
            }

            if( $currentSetting -notlike "$($sidstr)*" ) {
	            if( [string]::IsNullOrEmpty($currentSetting) ) {
		            $currentSetting = "$($sidstr)"
	            } else {
		            $currentSetting = "$($sidstr),$($currentSetting)"
	            }

                # Signature: http://msdn.microsoft.com/en-us/library/windows/hardware/ff547502(v=vs.85).aspx	
	            $outfile = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
$right = $($currentSetting)
"@

	        $tmp2 = [System.IO.Path]::GetTempFileName()
	        $outfile | Set-Content -Path $tmp2 -Encoding Unicode -Force
	        Push-Location (Split-Path $tmp2)
	
	        try {
		        secedit.exe /configure /db "secedit.sdb" /cfg "$($tmp2)" /areas USER_RIGHTS 
                Remove-Item $tmp2  -Force
	            } finally {	
		        Pop-Location
	            }
        
            }
        } #end setScript
        TestScript = {
            write-verbose "running SeServiceLogonRight.TestScript";
            $right="SeServiceLogonRight" 
            $account="bridgepoint\svc_udeploy"
            $sidstr = $null
            try {
	            $ntprincipal = new-object System.Security.Principal.NTAccount "$account"
	            $sid = $ntprincipal.Translate([System.Security.Principal.SecurityIdentifier])
	            $sidstr = $sid.Value.ToString()
                $sidstr = "*$($sidstr)"   # sids always start with *
            } catch {
	            $sidstr = $null
            }
            $registered = $false;
            $tmp = [System.IO.Path]::GetTempFileName()
            # export security policy and check
            secedit.exe /export /cfg "$($tmp)" 
            $c = Get-Content -Path $tmp 
            Remove-Item $tmp -Force
            foreach($s in $c) {
	        if( $s -like "$right*") {
		        $x = $s.split("=",[System.StringSplitOptions]::RemoveEmptyEntries)
		        $currentSetting = $x[1].Trim()
	            }
            }
            # check if user 
            $registered = $false;
            if( $currentSetting -like "$($sidstr)*" ) {
                    $registered = $true;
                  }
            return ($registered)

        }
        GetScript = {
            write-verbose "running SeServiceLogonRight.GetScript";
            $right="SeServiceLogonRight" 
            $account="bridgepoint\svc_udeploy"
            $sidstr = $null
            try {
	            $ntprincipal = new-object System.Security.Principal.NTAccount "$account"
	            $sid = $ntprincipal.Translate([System.Security.Principal.SecurityIdentifier])
	            $sidstr = $sid.Value.ToString()
                $sidstr = "*$($sidstr)"   # sids always start with *
            } catch {
	            $sidstr = $null
            }
            $registered = $false;
            $tmp = [System.IO.Path]::GetTempFileName()
            # export security policy and check
            secedit.exe /export /cfg "$($tmp)" 
            $c = Get-Content -Path $tmp 
            Remove-Item $tmp -Force
            foreach($s in $c) {
	        if( $s -like "$right*") {
		        $x = $s.split("=",[System.StringSplitOptions]::RemoveEmptyEntries)
		        $currentSetting = $x[1].Trim()
	            }
            }
            return @{ 
                PolicyRight = $right
                CurrentSetting = $currentSetting
            }

        }

      }#
#endregion
#region IBM licensing server files
      File RationalLicenseKeyServer
      {
        SourcePath = "\\10.13.0.206\scratch\DML\Urbancode\uDeploy\LicenseServer\ibm-urbancode-LKS_FOR_UC_8.1.3.zip"
        DestinationPath = "C:\temp\ibm-urbancode-LKS_FOR_UC_8.1.3.zip"
        Ensure = "Present"
        Type = "File"
        Credential = $Credential
      }
      File RationalLicenseKeyAdmin
      {
        SourcePath = "\\10.13.0.206\scratch\DML\Urbancode\uDeploy\LicenseServer\ibm-urbancode-LKAD_FOR_UC_8.1.3.zip"
        DestinationPath = "C:\temp\ibm-urbancode-LKAD_FOR_UC_8.1.3.zip"
        Ensure = "Present"
        Type = "File"
        Credential = $Credential
      }
      File RationalLicenses
      {
        SourcePath = "\\10.13.0.206\scratch\DML\Urbancode\uDeploy\LicenseServer\Licenses"
        DestinationPath = "C:\temp\RationalLicenses"
        Ensure = "Present"
        Type = "Directory"
        Recurse = $true
        Credential = $Credential
      } 

#endregion
   }
} 

# to generate MOF
# execute script in powershell ISE
# call with: BaseUCDServer -ConfigurationData $ConfigurationData -Credential (Get-Credential)