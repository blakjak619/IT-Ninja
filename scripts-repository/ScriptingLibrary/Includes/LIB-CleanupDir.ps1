<#  
  .SYNOPSIS   
    Function to remove all empty directories under the given path.
  .DESCRIPTION
    If -DeletePathIfEmpty is provided the given Path directory will also be deleted if it is empty.
    If -OnlyDeleteDirectoriesCreatedBeforeDate is provided, empty folders will only be deleted if they were created before the given date.
    If -OnlyDeleteDirectoriesNotModifiedAfterDate is provided, empty folders will only be deleted if they have not been written to after the given date.
  .LINK  
    http://blog.danskingdom.com/powershell-functions-to-delete-old-files-and-empty-directories/
  .EXAMPLE  
   Remove-EmptyDirectories -Path "C:\SomePath\Temp" -DeletePathIfEmpty
  .EXAMPLE  
   Remove-EmptyDirectories -Path "C:\SomePath\WithEmpty\Directories" -OnlyDeleteDirectoriesCreatedBeforeDate ([DateTime]::Parse("Jan 1, 2014 15:00:00"))

#> 
function Remove-EmptyDirectories(
[parameter(Mandatory)][ValidateScript({Test-Path $_})][string] $Path, 
[switch] $DeletePathIfEmpty, 
[DateTime] $OnlyDeleteDirectoriesCreatedBeforeDate = [DateTime]::MaxValue, 
[DateTime] $OnlyDeleteDirectoriesNotModifiedAfterDate = [DateTime]::MaxValue
)
{
    try {
        Get-ChildItem -Path $Path -Recurse -Force -Directory | Where-Object { (Get-ChildItem -Path $_.FullName -Recurse -Force -File) -eq $null } | 
            Where-Object { $_.CreationTime -lt $OnlyDeleteDirectoriesCreatedBeforeDate -and $_.LastWriteTime -lt $OnlyDeleteDirectoriesNotModifiedAfterDate } | 
            Remove-Item -Force -Recurse
    } catch {
        $errmsg = "(Remove-EmptyDirectories) Could not remove empty directories within $Path. The error was $_.Exception"
	    LLToLog -EventID $LLERROR -Text $errmsg 
    }
       
    # If we should delete the given path when it is empty, and it is a directory, and it is empty, and it meets the date requirements, then delete it.
    if ($DeletePathIfEmpty -and (Test-Path -Path $Path -PathType Container) -and (Get-ChildItem -Path $Path -Force) -eq $null -and
        ((Get-Item $Path).CreationTime -lt $OnlyDeleteDirectoriesCreatedBeforeDate) -and ((Get-Item $Path).LastWriteTime -lt $OnlyDeleteDirectoriesNotModifiedAfterDate))
    { 
        try { 
            Remove-Item -Path $Path -Force 
        } catch {
            $errmsg = "(Remove-EmptyDirectories) Could not remove empty directory: $Path. The error was $_.Exception"
	        LLToLog -EventID $LLERROR -Text $errmsg
        }
    }
}

 
<#  
  .SYNOPSIS   
   Function to remove all files in the given Path that were created before the given date, as well as any empty directories that may be left behind.
  .LINK  
    http://blog.danskingdom.com/powershell-functions-to-delete-old-files-and-empty-directories/
  .EXAMPLE  
   Remove-FilesCreatedBeforeDate -Path "C:\Another\Directory\SomeFile.txt" -DateTime ((Get-Date).AddMinutes(-30))
  .EXAMPLE  
   Remove-FilesCreatedBeforeDate -Path "C:\Some\Directory" -DateTime ((Get-Date).AddDays(-2)) -DeletePathIfEmpty

#> 
function Remove-FilesCreatedBeforeDate(
[parameter(Mandatory)][ValidateScript({Test-Path $_})][string] $Path,
[parameter(Mandatory)][DateTime] $DateTime, 
[switch] $DeletePathIfEmpty)
{
    try {
        Get-ChildItem -Path $Path -Recurse -Force -File | Where-Object { $_.CreationTime -lt $DateTime } | Remove-Item -Force
    } catch {
        $errmsg = "(Remove-FilesCreatedBeforeDate) Could not remove files within $Path older than $DateTime. The error was $_.Exception"
	    LLToLog -EventID $LLERROR -Text $errmsg 
    }
        Remove-EmptyDirectories -Path $Path -DeletePathIfEmpty:$DeletePathIfEmpty -OnlyDeleteDirectoriesCreatedBeforeDate $DateTime
}

<#  
  .SYNOPSIS   
   Function to remove all files in the given Path that have not been modified after the given date, as well as any empty directories that may be left behind.
  .LINK  
    http://blog.danskingdom.com/powershell-functions-to-delete-old-files-and-empty-directories/
  .EXAMPLE  
   Remove-FilesNotModifiedAfterDate -Path "C:\Another\Directory" -DateTime ((Get-Date).AddHours(-8))
#> 
function Remove-FilesNotModifiedAfterDate(
[parameter(Mandatory)][ValidateScript({Test-Path $_})][string] $Path,
[parameter(Mandatory)][DateTime] $DateTime, 
[switch] $DeletePathIfEmpty)
{
    try {
        Get-ChildItem -Path $Path -Recurse -Force -File | Where-Object { $_.LastWriteTime -lt $DateTime } | Remove-Item -Force
    } catch {
        $errmsg = "(Remove-FilesNotModifiedAfterDate) Could not remove files within $Path not modified after $DateTime. The error was $_.Exception"
	    LLToLog -EventID $LLERROR -Text $errmsg 
    }
    Remove-EmptyDirectories -Path $Path -DeletePathIfEmpty:$DeletePathIfEmpty -OnlyDeleteDirectoriesNotModifiedAfterDate $DateTime
}

<#  
  .SYNOPSIS   
   Function to parse XML Node and call related functions for file removal based on specified criteria
  .NOTES  
    File Name  : LIB-CleanupDir.ps1  
	Author  : Todd Pluciennik
    Date	: 4/24/2015 
 .EXAMPLE  
   $RemoveFileDateNode = $XMLParams.params.RemoveFile; ProcessRemoveFileDateXML $RemoveFileDateNode
#> 
function ProcessRemoveFileDateXML {
param (
	[System.Xml.XmlElement]$RemoveFileDateNode
)

    #region module load
    # load all modules required for path cleanup
    Import-Module WebAdministration
    #endregion

    #region init logging
    LLTraceMsg -InvocationInfo $MyInvocation

    if ($LoggingCheck) {
	    ToLog -LogFile $LFName -EventID $LLINFO -Text "ProcessRemoveFileDateXML"
    }
    #endregion init logging

    #region process XML nodes
    foreach ($File in $RemoveFileDateNode.File) {
        
        $Path = $File.Path
        # passing the DateTime as a string to be executed, so need to convert to DateTime object
        $DateTime = Invoke-Expression $File.DateTime
        $DeletePathIfEmpty = $false
        if ($File.DeletePathIfEmpty -eq "True") {
                $DeletePathIfEmpty = $true
        }
        $Criteria = $File.Criteria 
        if ($LoggingCheck) {
	        ToLog -LogFile $LFName -EventID $LLINFO -Text "Delete all files within $Path $Criteria $DateTime, DeletePathIfEmpty($DeletePathIfEmpty)"
        }
        switch ($Criteria) {
            "CreatedBefore" {Remove-FilesCreatedBeforeDate -Path $Path -DateTime $DateTime -DeletePathIfEmpty:$DeletePathIfEmpty}
            "NotModifiedAfter" {Remove-FilesNotModifiedAfterDate -Path $Path -DateTime $DateTime -DeletePathIfEmpty:$DeletePathIfEmpty} 
            default  { if ($LoggingCheck) {ToLog -LogFile $LFName -EventID $WARNING -Text "(ProcessRemoveFileDateXML) Remove File Date Criteria $Criteria not supported."} }
            }
   }
   #endregion process XML nodes
}


#region Unit Tests
if (($MyInvocation.Line -eq $null) -or ($MyInvocation.Line -notmatch "\. ")) {
	$LIBPATH = $env:ScriptLibraryPath
	if(-not $LIBPATH) {
		$DefaultPath = "\\10.13.0.206\scratch\DML\Scripts"
		Write-Host "No '$env:ScriptLibraryPath' environment variable found. Defaulting to $DefaultPath"
		$LIBPATH = $DefaultPath
	}
	. $LIBPATH\Includes\LIB-Logging.ps1

	LLInitializeLogging -LogLevel $LLTRACE
	
	#Test(s) for isElevated -------------------------------------------------------------------------
	$StartTime = Get-Date
    $TempName = [System.Guid]::NewGuid().ToString()
    $TempPath = "C:\temp\$TempName"
    $quiet = New-Item -Type Directory -Path "$TempPath" -force
	$TempFileNameBase = "$TempPath\FileTest.txt"
    # create 5 files
    for($i=1; $i -le 5; $i++){
    $TempFileName = "$TempFileNameBase.$i"
    Add-Content $TempFileName "stuff" -Encoding Ascii
    }
    Write-Host "Files within ${TempPath}:" -ForegroundColor Cyan
    Get-ChildItem ${TempPath}
	[xml]$TestXML=@"
	<RemoveFile>
	<File Path="$TempPath" DateTime="(Get-Date)" DeletePathIfEmpty="False" Criteria="CreatedBefore" />
    <File Path="C:\badpath" DateTime="((Get-Date).AddDays(-365)) " DeletePathIfEmpty="False" Criteria="CreatedBefore" />
	</RemoveFile>
"@
    #Sleep 30
    $RemoveFileDateNode = $TestXML.RemoveFile
	ProcessRemoveFileDateXML $RemoveFileDateNode
    Write-Host "Files within ${TempPath}:" -ForegroundColor Cyan
    Get-ChildItem ${TempPath}
    Remove-Item -Path $TempPath -Force
    Get-EventLog -After $StartTime -LogName Application
	# End  Tests --------------------------------------------------------------------------
}
#endregion
