function ProcessFolderActions {
param( [System.Xml.XmlElement]$FolderInfo )

	switch($FolderInfo.Action){
		"Add" {
			$FolderPBR = $FolderInfo.PathFromBinRoot

			if ($FolderInfo.AbsolutePath) {
				$FolderFullPath = $FolderInfo.AbsolutePath
			} else {
				$FolderFullPath = Join-Path $BinServer $FolderPBR
			}
			if ($FolderInfo.ReqDestination) {
				$DestFolder = $FolderInfo.ReqDestination
			} else {
				$DestFolder = $TempFldrPath
			}
			$Filter = ""
			if ($FolderInfo.Filter) { $Filter = $FolderInfo.Filter }
			try {
				try {
			    	robocopy "$FolderFullPath" "$DestFolder" $Filter /E /Z /NP /MT /R:1 /Log+:$LLLogFilePath
				} catch {
					copy -Path "$FolderFullPath" -Recurse -Destination "$DestFolder"
				}
				if ($LoggingCheck) {
					LLToLog -EventID $LLINFO -Text "Copied folder `'$FolderFullPath`'"
				}
			} catch [Exception] {
				LLToLog -EventID $LLFATAL "FAILURE:: There is an issue copying a required file! `n $_"
			}
			
			continue
		}
		default {
			LLToLog -EventID $LLWARN -Text "Folder action $($FolderInfo.Action) not recognized for xml element $($FolderInfo). Action skipped."
		}
	}
}
function ParseFileXML {
param (
	[System.Xml.XmlElement]$FileNode
)
	$FileAction = $FileNode.Action
	$FileSrc = $FileNode.Source
	$FileDest = $FileNode.Destination
	$FileCrit = $FileNode.Critical
	
	$ParamHash = @{}
	
	if($FileSrc){
		$ParamHash.Add("-Source","$FileSrc")
	} else {
		$errmsg = "No source specified for file activity $FileNode"
		LLToLog -EventID $LLWARN -Text $errmsg 
		if($FileCrit){
			throw $errmsg
		}
	}
	
	If($FileDest){
		$ParamHash.Add("-Destination","$FileDest")
	} else {
		$errmsg = "No destination specified for file activity $($FileNode.OuterXml)"
		LLToLog -EventID $LLWARN -Text $errmsg
		if($FileCrit){
			throw $errmsg
		}
	}

	If($FileCrit){
		$ParamHash.Add("-Critical",$true)
	}

	switch($FileAction){
		"Copy" { $result = FileCopy @ParamHash }
		"Move" { $result = FileMove @ParamHash }
        "Link" { $result = CreateSymlink @ParamHash }
		Default {
			$errmsg = "No known action for file activity $FileNode"
			LLToLog -EventID $LLWARN -Text $errmsg
			if($FileCrit){
				throw $errmsg
			}
		}
	}
}
function FileCopy {
param(
	[string]$Source,
	[string]$Destination,
	[switch]$Critical
)

	$retval = $true
	
	if(-not (Test-Path $Source)){
		$errmsg = "Couldn't find file $Source."
		LLToLog -EventID $LLERROR -Text $errmsg
		$retval = $false
		if($Critical){
			throw $errmsg
		}
	}
	
	#Assumption: the Destination is a full file specification.
	
	if($retval){
		try{
			Copy-Item -Path $Source -Destination $Destination -Force -ErrorAction Stop
		} catch {
			$errmsg = "Failed to copy file $Source to $Destination. The error was $_.Exception"
			$retval = $false
			LLToLog -EventID $LLERROR -Text $errmsg
			if($Critical){
				throw $errmsg
			}
		}
	}
	
	return $retval
}
function FileMove {
param(
	[string]$Source,
	[string]$Destination,
	[switch]$Critical
)

	$retval = $true
	
	if(-not (Test-Path $Source)){
		$errmsg = "Couldn't find file $Source."
		LLToLog -EventID $LLERROR -Text $errmsg
		$retval = $false
		if($Critical){
			throw $errmsg
		}
	}
	
	#Assumption: the Destination is a full file specification.
	
	if($retval){
		try{
			Move-Item -Path $Source -Destination $Destination -Force -ErrorAction Stop
		} catch {
			$errmsg = "Failed to copy file $Source to $Destination. The error was $_.Exception"
			$retval = $false
			LLToLog -EventID $LLERROR -Text $errmsg
			if($Critical){
				throw $errmsg
			}
		}
	}
	
	return $retval
}
#region symlink (soft links)
# test soft link
# credit: http://stackoverflow.com/questions/817794/find-out-whether-a-file-is-a-symbolic-link-in-powershell
# return true/false if the path provided is a soft (symbolic) link
function Test-ReparsePoint {
param(
    [string]$path
) 
  $file = Get-Item $path -Force -ErrorAction SilentlyContinue
  return [bool]($file.Attributes -band [IO.FileAttributes]::ReparsePoint)
}


function CreateSymlink {
param(
	[string]$Source,  # LinkName
	[string]$Destination, # Target
	[switch]$Critical
)

	$retval = $true
	
	if(Test-ReparsePoint -path $Source){
		$errmsg = "$Source is already a softlink"
		LLToLog -EventID $LLERROR -Text $errmsg
		$retval = $false
		if($Critical){
			throw $errmsg
		}
	}
	
	#Assumption: the source path will be deleted if already existing, prior to creating link.
	if($retval){
     
        if (Test-Path $Source -PathType Any) { 
            try{
			    Remove-Item -Path $Source -Force -Recurse -ErrorAction Stop
		    } catch {
			    $errmsg = "Failed to remove existing object $Source. The error was $_.Exception"
			    $retval = $false
			    LLToLog -EventID $LLERROR -Text $errmsg
			    if($Critical){
				    throw $errmsg
			    }
		    }
        }# end if exists

        # create link
		try{
		   if ((Test-Path $Destination -PathType leaf) ){ 
    	        cmd /c mklink $Source $Destination
           } else {
                cmd /c mklink /d $Source $Destination
           }
		} catch {
			$errmsg = "Failed to create Link $Source to $Destination. The error was $_.Exception"
			$retval = $false
			LLToLog -EventID $LLERROR -Text $errmsg
			if($Critical){
				throw $errmsg
			}
		}
	}
	
	return $retval
}
#endregion

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
	$TempFileName = "c:\temp\FileTest.dat"
    $TempLinkDir = "C:\temp\FileTestLinkDestination"
	Add-Content $TempFileName "stuff" -Encoding Ascii
    mkdir $TempLinkDir
	[xml]$TestXML=@"
	<XMLRoot>
	<File Action="Copy" Source="C:\Temp\FileTest.dat" Destination="C:\Temp\FileTest.txt" />
	<File Action="Move" Source="C:\Temp\FileTest.dat" Destination="C:\Temp\FileTest.stf" />
	<File Action="Copy" Source="C:\Temp\File" Destination="C:\Temp\FileTest.txt" />
    <File Action="Link" Source="C:\Temp\FileTestLink" Destination="C:\Temp\FileTestLinkDestination" />
    <File Action="Link" Source="C:\temp\FileTestLink.txt" Destination="C:\Temp\FileTest.txt" />
	</XMLRoot>
"@
	foreach($FileXML in $TestXML.XMLRoot.File) {
		ParseFileXML -FileNode $FileXML
        Start-Sleep -Seconds 2
	}
   
    Compare-Object C:\Temp\FileTest.txt C:\Temp\FileTestLink.txt -IncludeEqual
    Remove-Item c:\temp\FileTest* -Force -Confirm:$false -Recurse
    Get-EventLog -After $StartTime -LogName Application
	# End GetCredential Tests --------------------------------------------------------------------------
}
#endregion