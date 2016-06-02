#CreateIIS_VD -VDName UWF2_3 -PhysicalPath "C:\www\WebApp1\WebFolder2\UWF2_5" -FullIISPath "IIS:\Sites\WebApp1\WebFolder2\UFW2_5"

Function FindIISParent {
param([String]$IISFullPath)

	try {
		if (!(Get-Module -Name Webadministration)) {
			Import-Module Webadministration
		}
	} catch [Exception] {
		throw "`"WebAdministration`" module could not be loaded!"
	}


		$PathSplit = $IISFullPath.Split("\")
		$top = ($PathSplit.Length - 1)
		$Last = $PathSplit[$top]
		
		$FParentPath = $IISFullPath.Replace($Last, "")
		$FParentPath = $FParentPath.TrimEnd("\")
		
		$PathFromSites = $IISFullPath.Replace("IIS:\Sites\", "")
		$PathFromSites = $PathFromSites.Replace($Last, "")
		$PathFromSites = $PathFromSites.TrimEnd("\")
		if ($PathFromSites -eq "") {
			$PathFromSites = $Last
		}
		
		$PathObj = New-Object PSObject
		$PathObj | Add-Member -MemberType NoteProperty -Name Name -Value $Last
		$PathObj | Add-Member -MemberType NoteProperty -Name FullPath -Value $IISFullPath
		$PathObj | Add-Member -MemberType NoteProperty -Name ParentPathFromSite -Value $PathFromSites
		$PathObj | Add-Member -MemberType NoteProperty -Name ParentFullPath -Value $FParentPath
		
		
		Return $PathObj
		
}

Function CreateIIS_VD {
param([String]$VDName, [String]$PhysicalPath, [String]$FullIISPath )
$Usage = @"
#-------------------------------------------------------------------------
# Solution: CreateIIS_VD
# Author: Sly Stewart 
# Updated: 2/12/2013
# Version: 1.0
<#
# Description: Create IIS Virtual Directory

- Mandatory Parameters
	[String]-VDName <String>: The new virtual directory to create
	[String]-PhysicalPath <String>: The full physical path to the directory. 
		The script will create the path if it does not currently exist.
	[String]-FullIISPath <String>: The Full IIS Path where this folder will reside

#
# Usage:
# - CreateIIS_VD -VDName "Site3" -PhysicalPath "C:\SlySre" -FullIISPath "IIS:\Sites\Default Web Site\Site3"
#	## Create the virtual directory "Site 3" under the "Default Website".

# - CreateIIS_VD -VDName "Params" -PhysicalPath "D:\inetpub\www\Web2\Vdir1" -FullIISPath "IIS:\Sites\Web2\Params"
#	## Create the virtual directory "Params" under the "Web2" website.

#>
# Revision History
# Version 1.0 - Initial Commit 2/12/2013
#-------------------------------------------------------------------------

"@

	if ($PSBoundParameters.Count -ne 3) {
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Required parameters were not passed to CreateIIS_VD. Exiting"
		}
		throw "Missing parameters!"
	}
	try {
		if (!(Get-Module -Name Webadministration)) {
			Import-Module Webadministration
		}
	} catch [Exception] {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: IIS is not installed."
		}
		throw "`"WebAdministration`" module could not be loaded!"
	}
	
	if (Get-WebVirtualDirectory -Name "$VDName") {
		$PhysVD = (Get-WebVirtualDirectory -Name "$VDName")
		$VDBaseType = (($PhysVD.GetType()).BaseType)
		$ThrowCheck = 0
		if ($VDBaseType -eq "System.Array") {
			foreach ($PhP in ($PhysVD.PhysicalPath)) {
				if ($PhP -eq $PhysicalPath) {
					$ThrowCheck++
				}
			}
		}
		if ($VDBaseType -eq "System.Object") {
			$PhP = $PhysVD.PhysicalPath
			if ($PhP -eq $PhysicalPath) {
					$ThrowCheck++
			}
		}
		if ($ThrowCheck -gt 0) {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "This virtual directory `'$VDName`' already exists. Exiting."
			}
			Throw "Failed. Attempting to create a duplicate object"
		}
	}

	if ($PhysicalPath -match [regex]'^\\\\.*') {
		if ($LoggingCheck) { ToLog -LogFile $LFName -EventID 3 -Text "`'$PhysicalPath`' is in UNC format. That format is unsupported. No action taken." }
	} else {
		if (!(Test-Path $PhysicalPath)) {
			try {
				$Quiet = New-Item -ItemType directory "$PhysicalPath"
				if ($LoggingCheck) {ToLog -LogFile $LFName -Text "Created `'$PhysicalPath`' Directory."	}
			} catch [Exception] {
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "Directory `'$PhysicalPath`' does not Exist and can not be created!"
				}
				throw "Directory `'$PhysicalPath`' does not Exist and can not be created!"
			}
		}
	}
			try {
				$PS = FindIISParent -IISFullPath $FullIISPath
				$ParentSite = $PS.ParentPathFromSite
				if ($PS) {
					$Quiet = New-WebVirtualDirectory -Name "$VDName" -PhysicalPath "$PhysicalPath" -Site "$ParentSite"
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "Created `'$VDName`' Web Virtual Directory successfully."
					}
				} else {
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: Unable to create `'$VDName`' Web Virtual Directory. Unable to determine Parent Site."
					}
					throw "Unable to determine Parent Site!"
				}
			} catch [Exception] {
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: Unable to create `'$VDName`' Web Virtual Directory."
				}
				throw "There was an error creating the virtual directory `'$VDName`'. $_ "
			}
}

#
#	This is commented out because i could not find a good way to determine 
#	what was the site and parent application in a nested environment
#	and it was failing on the Remove-WebVirtualDirectory
#
#Function DeleteIIS_VD {
#param([String]$VDName, [String]$FullIISParent, [String]$RemovePhysical)
#$Usage = @"
##-------------------------------------------------------------------------
## Solution: DeleteIIS_VD
## Author: Sly Stewart 
## Updated: 2/12/2013
## Version: 1.0
#
## Description: Delete IIS Virtual Directory
#
#- Mandatory Parameters
#	[String]-VDName <String>: The new virtual directory to delete.
#	[String]-FullIISParent <String>: The full IIS path to the directory. 
#		The script will delete the Virtual Directory at that path.
#	[String]-RemovePhysical "True" | "False": When deleting the Virtual Directory,
#		Do we want to remove the physical path?
#
##
## Usage:
## - DeleteIIS_VD -VDName "Site3" -PhysicalPath "C:\SlySre" -FullIISPath "IIS:\Sites\Default Web Site\Site3"
##	## Create the virtual directory "Site 3" under the "Default Website".
#
## - DeleteIIS_VD -VDName "Params" -PhysicalPath "D:\inetpub\www\Web2\Vdir1" -FullIISPath "IIS:\Sites\Web2\Params"
##	## Create the virtual directory "Params" under the "Web2" website.
#
#
## Revision History
## Version 1.0 - Initial Commit 2/12/2013
##-------------------------------------------------------------------------
#
#"@
#
#if ($PSBoundParameters.Count -ne 3) {
#		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
#		throw "Missing parameters!"
#}
#	
#try {
#		if (!(Get-Module -Name Webadministration)) {
#		Import-Module Webadministration
#		}
#} catch [Exception] {
#	throw "`"WebAdministration`" module could not be loaded!"
#}
#$PS = FindIISParent $FullIISParent
#$ParentPath = $PS.ParentFullPath
#if (Test-Path $ParentPath) {
#	$CWD = $PWD
#	cd "$ParentPath"
#	if (get-WebVirtualDirectory -Name "$VDName") {
#		$PhysPath = (get-WebVirtualDirectory -Name "$VDName").PhysicalPath
#		try {
#				Remove-WebVirtualDirectory $VDName
#				if ($RemovePhysical -eq "True") {
#					$Quiet = rm $PhysPath -Force -Recurse
#				}
#		} catch [Exception] {
#			throw "There was an issue removing the Virtual Directory `'$VDName`'"
#		}
#		
#	}
#	cd $CWD
#}
#}
