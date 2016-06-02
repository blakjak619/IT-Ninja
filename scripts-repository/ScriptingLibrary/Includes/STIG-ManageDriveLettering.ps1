
Function ReLocDisk {
Param(`
[Parameter(parameterSetName="A", Mandatory=$true)][string]$ILabel, `
[Parameter(parameterSetName="B", Mandatory=$true)][string]$DriveLetter, `
[string]$NewLetter)
$Usage = @"
#-------------------------------------------------------------------------
# Solution: ReLocDisk
# Author: Sly Stewart
# Updated: 12/17/2012
# Version: 1.0
<#
# Description:
- Change a drive to a new drive letter. Drive can be identified by either drive label or drive letter.

#
# Usage:
# - ReLocDisk [-ILabel <string>] [-DriveLetter <string>] -NewLetter
#
# - ReLocDisk -ILabel "Data" -NewLetter "S:"
#	Change the drive with Label "Data" to "S:\"
#
# - ReLocDisk -DriveLetter "F:" -NewLetter "Z:"
#	Change the drive with Drive Letter F: to "Z:"


#>
# Revision History
# Version 1.0 - Initial Commit 
#-------------------------------------------------------------------------

"@
#Change a drive to a new drive letter. Drive can be identified by either drive label or drive letter.
	

	if ($ILabel) {
	$SDrive = gwmi Win32_Volume | ? {$_.Label -eq "$ILabel"} 
		} elseif ($DriveLetter) {
			if (!($DriveLetter | Select-String ":")) {
				$DriveLetter = $DriveLetter + ":"
			}
			if ($DriveLetter.Length -ne 2) {
				Write-Host "DriveLetter param should be formatted as `"Letter:`" e.g `"T:`""
				Write-Host $Usage
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: DriveLetter param should be formatted as `"Letter:`" e.g `"T:`""
				}
				throw
			}
			$SDrive = gwmi Win32_Volume | ? {$_.DriveLetter -eq "$DriveLetter"} 
		}
		
	if ($SDrive) {
		if (!($($SDrive.DriveLetter) -eq $NewLetter)) {
			try {
				Set-WmiInstance -InputObject $SDrive -Arguments @{DriveLetter="$NewLetter";} | Out-Null
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "Successfully moved drive to `'$NewLetter`'"
				}
			} catch [Exception] {
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: There was a problem setting `"$ILabel`" Drive. $_"
				}
				Write-Host "There was a problem setting `"$ILabel`" Drive. ERROR: `n $_"
			}
		}
	} else {
		if ($ILabel) {
			Write-Host "Drive `"$ILabel`" Not found."
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: Drive `"$ILabel`" Not found."
			}
		} elseif ($DriveLetter) {
			Write-Host "Drive `"$DriveLetter`" Not found."
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: Drive `"$DriveLetter`" Not found."
			}
		}
	}
}

function NextOpenDL {
param([String]$StartWith)
$Usage = @"
#-------------------------------------------------------------------------
# Solution: NextOpenDL
# Author: Sly Stewart
# Updated: 12/17/2012
# Version: 1.0
<#
# Description:
- Returns [String] Next available Drive Letter, or $Null if one is not available.

#
# Usage:
# - NextOpenDL 

#>
# Revision History
# Version 1.0 - Initial Commit 
#-------------------------------------------------------------------------

"@
#Returns [String] Next available Drive Letter, or $Null if one is not available.
#Using #68 starts us out with "D".
if ($StartWith) {
	$StartWith = $StartWith.ToUpper()
	if (($StartWith.Length) -gt 1) {
		$Array = $StartWith.ToCharArray()
		[Char]$Char = $Array[0]
		$Le = [int]$Char
	} else {
		$Le = [int][char]$StartWith
	}
} else {
	$Le = 68
}
	$startPos = $Le
do {
	[string]$NextLetter = [char]$Le + ":"
	$Check = gwmi Win32_LogicalDisk | ? {$_.DeviceID -eq "$NextLetter" }
	$Le++
	if ($Le -eq (65+26)) {
		if ($StartWith) {
			$Le = 68
		}
	}
	if ($startPos -eq $Le) {
		$Check = $null
	}
} until (!$Check)
return $NextLetter
}