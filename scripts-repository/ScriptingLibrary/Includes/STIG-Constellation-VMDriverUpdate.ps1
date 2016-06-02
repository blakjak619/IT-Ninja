$Usage = @"
#-------------------------------------------------------------------------
# Solution: Constellation-VMDriverUpdate
# Author: Sly Stewart
# Updated: 3/7/2013
# Version: 1.0
<#
# Description:
- Updates the display driver for VM Machines.
	All of this work is taken from Amit Budhu <Amitraj.Budhu@bpiedu.com>, 
	Im just repackaging it for use in this script.

#
# Usage: 
		UpdateVMDisplayDriver

#>
# Revision History
# Version 1.0 - Initial Commit -SS 3/7/2013
#-------------------------------------------------------------------------

"@
if ($Help) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	throw "Showing Help."
}

Function UpdateVMDisplayDriver {

	if (gwmi Win32_OperatingSystem | ? {$_.Name -like "Microsoft Windows Server 2008 R2 *" }) {
		if (gwmi Win32_ComputerSystem | ? {$_.Model -like "VMware*"}) {
			if (gwmi Win32_PnPSignedDriver | ? {(($_.DeviceClass -eq "DISPLAY") -and ($_.DeviceName -notlike "VMware SVGA 3D*"))}) {
			
				$DriverLoc1 = "C:\Program Files\Common Files\VMware\Drivers\wddm_video\vm3d.inf"
				$DriverLoc2 = "C:\Program Files\Common Files\VMware\Drivers\video_wddm\vm3d.inf"
				if (Test-Path $DriverLoc1) {
					try {
						Invoke-Expression "pnputil -i -a `"$DriverLoc1`""
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "Successfully updated VMDisplay drivers with `"$DriverLoc1`""
						}
					} catch [Exception] {
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "FAILURE:: There was an issue updating VMDisplay drivers with `"$DriverLoc1`""
						}
					}
				} elseif (Test-Path $DriverLoc2) {
					try {
						Invoke-Expression "pnputil -i -a `"$DriverLoc2`""
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "Successfully updated VMDisplay drivers with `"$DriverLoc2`""
						}
					} catch [Exception] {
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "FAILURE:: There was an issue updating VMDisplay drivers with `"$DriverLoc2`""
						}
					}
				}
				
			}
		} else {
			if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "Machine is not a vmware box. Skipping UpdateVMDisplayDriver"
		}
		}
	} else {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "Machine is not a windows 2008 R2 box. Skipping UpdateVMDisplayDriver"
		}
	}

}