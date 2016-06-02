

Function IO-WinFW {
param([parameter(Mandatory=$true)][String]$State, `
[parameter(Mandatory=$true)][ValidateSet("allprofiles", "currentprofile", "domainprofile", "global", "privateprofile", "publicprofile")][String]$FWProfile)
$Usage = @"
#-------------------------------------------------------------------------
# Solution: IO-WinFW
# Author: Sly Stewart
# Updated: 2/22/2013
# Version: 1.0
<#
# Description:
- Enable or Disable the windows firewall.

# Mandatory Parameters:
	[Boolean]-State: 
		`$True: Enable the firewall
		`$False: Disable the firewall
	
	[String]$FWProfile <String>: Profile on which to make the change.
		"allprofiles", "currentprofile", "domainprofile", "global", "privateprofile", "publicprofile"

#
# Usage: 



#>
# Revision History
# Version 1.0 - Initial Commit 
# Version 1.1 - Added Default logging.
#-------------------------------------------------------------------------

"@

	
	if ($State -eq "Enable") {
		$Switch = "on"
	} elseif ($State -eq "Disable") {
		$Switch = "off"
	}
	Invoke-Expression "Netsh advfirewall set $FWProfile state $Switch"
}