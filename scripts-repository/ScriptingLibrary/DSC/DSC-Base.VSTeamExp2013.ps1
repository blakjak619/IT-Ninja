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

Configuration VS_TeamExplorer
{
   param ([Parameter(Mandatory=$false)]
        [PSCredential]$Credential
        )

   # A Configuration block can have zero or more Node blocks
   Node "LocalHost" 
   {
#region Visual Studio 2013 Team Explorer

#region File 
      # temp directory
      File TempDir
      {
        Ensure = "Present" 
        Type = "Directory" 
        DestinationPath = "C:\temp" 
                
      }

#region Copy Source Files
      # Copy VS_TeamExplorer
       File VS_TeamExplorerFiles
      {
        SourcePath = "\\10.13.0.206\scratch\DML\Microsoft\Team Explorer\2013"
        DestinationPath = "C:\Temp\VS_TeamExplorer\2013"
        Ensure = "Present"
        Type = "Directory"
        Recurse = $true # Ensure presence of subdirectories, too
        Credential = $Credential
      }

      Package VS_TeamExplorer #ResourceName
      {
		  Name = "TeamExplorer"
		  Path = "C:\Temp\VS_TeamExplorer\2013\vs_teamexplorer.exe"
		  ProductID = "C9E7751E-88ED-36CF-B610-71A1D262E906"
          Arguments = "/passive /full /noweb"
		  Ensure = "Present"
      }
     
     
#endregion 
    
}# end Node

} 
#endregion
