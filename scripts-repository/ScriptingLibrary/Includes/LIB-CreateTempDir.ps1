function CreateTempDir {
$Usage = @"
#-------------------------------------------------------------------------
# Solution: CreateTempDir
# Last Updated By: Todd Pluciennik
# Updated: 5/8/2014
# Credit: http://joelangley.blogspot.fr/2009/06/temp-directory-in-powershell.html
# Version: 1.0
<#
# Description: Create temp dir


#-------------------------------------------------------------------------

"@	
   $tmpDir = [System.IO.Path]::GetTempPath()
   $tmpDir = [System.IO.Path]::Combine($tmpDir, [System.IO.Path]::GetRandomFileName())
   [System.IO.Directory]::CreateDirectory($tmpDir) | Out-Null
   $tmpDir

   <# alternate
   # Create temp dir
    $tmpDir = [System.Guid]::NewGuid().ToString()
    # Now we can create our temporary folder
    New-Item -Type Directory -Name $tmpDir
    #>
}