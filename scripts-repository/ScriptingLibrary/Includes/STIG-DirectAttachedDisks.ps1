$Usage = @"
#-------------------------------------------------------------------------
# Solution: STIG-DirectAttachedDisks
# Author: Sly Stewart
# Updated: 5/6/2013
# Version: 1.0
<#
# Description:
- Format, partition, and label ALL blank attached disks. Labels disks Disk0/1/2/3/etc. based on disk index.

# Revision History
# Version 1.0 - Initial Commit SS - 5/6/2013
#-------------------------------------------------------------------------

"@

$CurrentDir = pwd
$DiskpartScriptFile = Join-Path $CurrentDir "DiskpartScript"

function FormatAndPartitionAllBlankDisks {
param([int]$Alignment, $BlockSize)

	LLTraceMsg -InvocationInfo $MyInvocation

	$PotentialDisks = gwmi Win32_DiskDrive | ? {$_.Partitions -eq 0}
	if ($PotentialDisks) {
        if (Test-Path $DiskpartScriptFile ) { rm $DiskpartScriptFile -Force }
		foreach ($Disk in $PotentialDisks) {
			$DiskIndex = $Disk.Index
			$DiskLabel = "Disk" + $DiskIndex

			Add-Content $DiskpartScriptFile -Value "select disk $DiskIndex"
			Add-Content $DiskpartScriptFile -Value "online disk noerr"
			Add-Content $DiskpartScriptFile -Value "attributes disk clear readonly noerr"
			Add-Content $DiskpartScriptFile -Value "convert gpt noerr"


			if (!$Alignment) {
				Add-Content $DiskpartScriptFile -Value "create partition primary noerr"
			} else {
				Add-Content $DiskpartScriptFile -Value "create partition primary align=$Alignment noerr"
			}

			if (!$BlockSize) {
				Add-Content $DiskpartScriptFile -Value "format quick Label=`"$DiskLabel`" noerr"
			} else {
				Add-Content $DiskpartScriptFile -Value "format quick Label=`"$DiskLabel`" unit=$BlockSize noerr"
			}
		}
		DPCommit
	}
}
function DPCommit {
	LLTraceMsg -InvocationInfo $MyInvocation
	if (Test-Path $DiskpartScriptFile) {
		Invoke-Expression "Diskpart /s `'$DiskpartScriptFile`'"
	}
}
function InitializeDisk {
param( $DiskID )

	LLTraceMsg -InvocationInfo $MyInvocation

	try{
		Initialize-Disk $DiskID -ErrorAction SilentlyContinue
		LLToLog -EventID $LLINFO -Text "Disk $DiskID has been initialized."
	} catch {
		LLToLog -EventID $LLWARN -Text "Disk $DiskID couldn't be initialized."
		LLToLog -EventID $LLINFO -Text "$_"

	}
}
function PartitionAndFormatDisk {
param( $DiskID )

	LLTraceMsg -InvocationInfo $MyInvocation

    $PartitionTotal = 0
	try{
		$PartList = Get-Partition $DiskID -ErrorAction "Stop"
	} catch {
		$PartList = $null
	}
	ForEach($PartObj in $PartList) {
		$PartitionTotal += $PartObj.Size
	}

	$TotalUnpartitioned = (Get-Disk $DiskID).Size - $PartitionTotal
    [double]$PctUnpartitioned = $TotalUnpartitioned / $(Get-Disk $DiskID).Size
    if($PctUnpartitioned -gt 0.01){
		New-Partition –DiskNumber $DiskID -UseMaximumSize -AssignDriveLetter | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Disk$DiskID" -Confirm:$false
		LLToLog -EventID $LLINFO -Text "Disk $DiskID has been partitioned and formatted."
    } else {
		RelocDisk -ILabel "Disk$DiskID" -NewLetter (NextOpenDL -StartWith "N")
        Get-Volume -FileSystemLabel "Disk$DiskID" | Format-Volume -FileSystem NTFS -NewFileSystemLabel "Disk$DiskID" -Confirm:$false
		LLToLog -EventID $LLINFO -Text "Disk $DiskID has been formatted."
    }
}