param([String]$VCloud_Server, [Switch]$Help)
#.\VCloud_ExpiringVApps.ps1 -VCloud_Server "bpeca-aevcd01"

$Usage = @"
#-------------------------------------------------------------------------
# Solution: VCloud_ExpiringVApps.ps1
# Author: Sly Stewart
# Updated: 3/13/2013
# Version: 1.3
<#
# Description:
- Sends out an email to users of a vApp when expiration is near. 
	This script is supposed to be ran as a scheduled task once a day.
	There currently is a hard coded password due to the limitations of the Connect-CIServer cmdlet.

#
# Usage: 
		- VCloud_ExpiringVApps.ps1 -VCloud_Server <String> : Send an email out to owners of vApps who will expire in preset windows.
		- VCloud_ExpiringVApps.ps1 -Help : Show this help text.
		
# Detailed description:
	* Get a list of VMs which are set to expire in certain days.
	* Email the owners of said VM's letting them know the expiration date.


#>
# Revision History
# Version 1.0 - Initial Commit 
# Version 1.1 - Added Default logging.
# Version 1.2 - Determined that RuntimeLease was the incorrect property to use.
#				Instead, now using DeploymentLeaseExpiration from Get-CIView -SS 3/6/2013
# Version 1.3 - Found a bug when a group cant be found by regular search, but can be found my broad search.
#				The script was not adding the email addresses in. -SS 3/13/2013
#-------------------------------------------------------------------------

"@
if ($Help) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	throw "Showing usage."
}

function CheckReqSnapIn ($SnapIN) {
	if (!(Get-PSSnapin -Name "$SnapIN" -ErrorAction SilentlyContinue))
		{
			if (Get-PSSnapin -Registered -Name $SnapIN -ErrorAction SilentlyContinue) {
				Add-PSSnapin $SnapIN
			} else {
				Throw "Required snapin is not present"
			}
		}
}

Function ToLog ($LogFile, $LogText) {
    if (!(test-path $LogFile)) {
        new-item -force -path "$LogFile" -type file
    }
    #DateTime Stamp - "[4/22/12 17:33:24]" 
    $DS = get-date -uformat "[%D %T] "
    add-content $LogFile -value "$DS$LogText"

}

function CreateLocalADCache {
	$LocalC = @()
	$AllADGroups = (Get-QADGroup -SearchRoot "DC=bridgepoint,DC=local" -SizeLimit 0)
	Foreach ($ADGroup in $AllADGroups) {
		$Group = New-Object PSObject
		$GrName = $ADGroup.Name
		$GrDN = $ADGroup.DN
		
		$Group | Add-Member -MemberType NoteProperty -Name Name -Value $GrName
		$Group | Add-Member -MemberType NoteProperty -Name DN -Value $GrDN
		$LocalC += $Group
	}
	return $LocalC
}

function getMemberList () {
param($SecGroup)
	$MembersGroup = Get-QADGroupMember $SecGroup -UseGlobalCatalog
	if (!$MembersGroup) {
		ToLog $LFile "Attempting to use group-failsafe..."
		$MembersGroup = Get-QADGroupMember $SecGroup
		if ($MembersGroup) {
			ToLog $LFile "Group-Failsafe worked."
		}
	}
	$MemberList = @()
	if ($MembersGroup) {
		$MemberCount = $MembersGroup.Count
		ToLog $LFile "Returned $MemberCount user(s)."
	}
	foreach ($Member in $MembersGroup) {
		$User = New-Object -TypeName "PSObject"
		if ($TEST) {
			ToLog $LFile "Security Group Passed: $SecGroup"
			$MName = $Member.Name
			$MDn = $Member.DN
			$MMail = ((Get-QADUser ($Member.DN) -IncludeAllProperties).mail)
			ToLog $LFile "User: $MName; Mail: $MMail;"
		}
		$User | Add-Member -MemberType NoteProperty -Name "Name" -Value ($Member.Name)
		if ($Member.Type -eq "user") {
			$User | Add-Member -MemberType NoteProperty -Name "Mail" -Value ((Get-QADUser ($Member.DN) -IncludeAllProperties).mail)
		} elseif ($Member.Type -eq "group") {
			$User | Add-Member -MemberType NoteProperty -Name "Mail" -Value ((Get-QADGroup ($Member.DN) -IncludeAllProperties).mail)
		}
		$MemberList += $User
	}
	return $MemberList
}

$LogDate = Get-Date -UFormat "%Y%m"
$LFName = "ExpiringVApps_$LogDate.log"
$LogFolder = join-path $PWD "Logs"
$LFile = Join-Path $LogFolder $LFName

if (!(Test-Path $LogFolder)) {
	$Quiet = New-Item -ItemType Directory $LogFolder -Force
}

ToLog $LFile ""
ToLog $LFile "Starting..."

CheckReqSnapIn "VMware.VimAutomation.Core"
CheckReqSnapIn "VMware.VimAutomation.Cloud"
CheckReqSnapIn "Quest.ActiveRoles.ADManagement"
# CONVERT PW TO SECURE STRING
# Log in to script server AS the service account.
# $SecurePassword = Read-Host -Prompt "Enter password" -AsSecureString
# $SecureStringAsPlainText = $SecurePassword | ConvertFrom-SecureString
# $SecureStringAsPlainText > file.txt. Open and use the string in $SecureStringAsPlainText

#Sly
$SecureStringAsPlainText = "01000000d08c9ddf0115d1118c7a00c04fc297eb01000000028122480d712e4bb7b0820817a010440000000002000000000003660000c000000010000000753d2dc8ce55ae92752bf0d0d43dc28a0000000004800000a000000010000000b0c8197b9442bc4c26d93d8f27346059180000001f8d65805ec4d606658ceea08ef5e731b3160b242067a46414000000354e8440bef6226352e1008601820f4d70a2be3b"
$SecureString = $SecureStringAsPlainText  | ConvertTo-SecureString

###################################
# Use the correct Username for the above password!
###################################
$UserName = "svc_VMReports"
ToLog $LFile "User: `'$UserName`'"

$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $UserName, $SecureString
$PlainPassword = $Credentials.GetNetworkCredential().Password 

$VCloud_Server = "bpeca-aevcd01"
$AdminResponseEmail = "Lab@Bridgepointeducation.com"
$TESTMAILTO = "Sly.Stewart@bpiedu.com"
#$SMTPServer = "barracuda.bridgepoint.local"
$SMTPServer = "mail-tools.bridgepoint.local"
ToLog $LFile "SMTPServer: `'$SMTPServer`'"
ToLog $LFile "AdminEmail: `'$AdminResponseEmail`'"

ToLog $LFile "Attempting connection to `'$VCloud_Server`'."
$Quiet = Connect-CIServer $VCloud_Server -Credential $Credentials
if ($Quiet) {
	ToLog $LFile "Successfully connected to `'$VCloud_Server`'."
} else {
	ToLog $LFile "FAILED connection to `'$VCloud_Server`'."
	throw "Failed to connect to VCLoud Server!!"
}

###################################
# Notification intervals in days
###################################
$NotifyInterval = @(1, 2, 3, 6, 7, 14)


$vApps = Get-CIVApp

$Now = Get-Date

$ExpiringvApps = @{}
foreach ($vApp in $vApps) {
	$vAppDay = (($vApp.RuntimeLease).Days)
		if ($vAppDay -gt 0) {
			$NewAppView = $vApp | Get-CIView
			# Retrieve the Lease settings section (containing information about the storage/runtime leases)
			$LeaseSection = $NewAppView.Section | ? {$_ -is [VMWare.VimAutomation.Cloud.Views.LeaseSettingsSection]}
			
			$ExDate = $leaseSection.DeploymentLeaseExpiration
			if ($ExDate -eq $null) {
				$StorDelDate = $leaseSection.StorageLeaseExpiration
				$StorLeaseSec = $LeaseSection.StorageLeaseInSeconds
				$ExDate = $StorDelDate.AddSeconds(-$StorLeaseSec)
			}
			if ($ExDate) {
				$ExpireInTime = New-TimeSpan -Start $Now -End $ExDate
				$ExpireInDays = $ExpireInTime.Days
				if ($NotifyInterval -contains $ExpireInDays) {
					$ExpiringvApps.Add($vApp, $ExpireInTime)
				}
			}
		}
}

	#Load a new array with custom vApp objects.
	$vAppList = @()
	$LocalCacheCreated = $false
	$TotalCount = $ExpiringvApps.Count
	ToLog $LFile "A total of `'$TotalCount`' vApp(s) will expire soon."
	foreach ($vAppName in $ExpiringvApps.Keys) {
		$vApp = $vApps | ? {$_.Name -eq "$vAppName"}
		$App = New-Object -TypeName "PSObject"
		$App | Add-Member -MemberType NoteProperty -Name "Name" -Value ($vApp.Name)
		$TimeRemaining = $ExpiringvApps[$vAppName]
		$App | Add-Member -MemberType NoteProperty -Name "TimeLeft" -Value $TimeRemaining
		$vAppMembers = $vApp | Get-CIVM
		$aName = $App.Name
		$aTTL = ($App.TimeLeft).Days
		ToLog $LFile "----------------"
		ToLog $LFile "vApp `'$aName`' has $aTTL day(s) Remaining."
		#$vAppMembers[0] | gm
		if ($vAppMembers) {
			$VMS = @()
			$count = 0
			$ChildVMC = $vAppMembers.Length
			if ($ChildVMC -eq $null) {
				$ChildVMC = 1
			}
			ToLog $LFile "Children VMs: $ChildVMC"
			foreach ($guest in $vAppMembers) {
				$VMS += ($guest.Name)
				[String]$VMName = $VMS
				#I only need to pull these records for 1 server. They should be the same across all servers in a vApp
				if ($count -eq 0) {
					ToLog $LFile "VM Name: $VMName"
					$ComputerDN = (Get-QADComputer $VMName).DN
					if ($ComputerDN) {
						ToLog $LFile "Full DN: $ComputerDN"
						$DNSplit = $ComputerDN.Split(",")
						$vAppEnv = (($DNSplit[$DNSplit.Length - 4]).toString()).Replace("OU=", "")
						$App | Add-Member -MemberType NoteProperty -Name "Environment" -Value $vAppEnv
						ToLog $LFile "Environment: $vAppEnv"
					}
					$AppSplit = $VMName.Split("-")
					$AppName = $AppSplit[0]
					$count++
				}
			}
			$OrgName = $vApp.org
			$App | Add-Member -MemberType NoteProperty -Name "OrgName" -Value $OrgName
			ToLog $LFile "vApp Org: `'$OrgName`'"
			$App | Add-Member -MemberType NoteProperty -Name "AppName" -Value $AppName
			ToLog $LFile "vApp AppName: `'$AppName`'"
			#If we can find the app environment, lets try to use that. Otherwise, do a larger search.
			if ($($App.Environment)) {
				$SecGroup = ((Get-QADGroup -SearchRoot "OU=$vAppEnv,OU=AE - NONPROD,DC=bridgepoint,DC=local" | ? {$_.Name -like "*_$AppName" }).DN)
			} else {
				$SecGroup = ((Get-QADGroup -SearchRoot "OU=AE - NONPROD,DC=bridgepoint,DC=local" | ? {$_.Name -like "*_$AppName" }).DN)
			}
			if ($SecGroup -ne $null) {
				ToLog $LFile "Security Group Found. `'$SecGroup`'"
				#Get the users of the security group and the mail addresses.
				$ML = getMemberList -SecGroup "$SecGroup"
				$App | Add-Member -MemberType NoteProperty -Name "Members" -Value $ML
			} else {
				if ($LocalCacheCreated -eq $false) {
					ToLog $LFile "Setting up the local AD cache."
					$LocalADCache = CreateLocalADCache
					$LocalCacheCreated = $true
				}
				ToLog $LFile "Unable to find a security group. Attempting to find all possible choices."
				$FullSearch = (($LocalADCache | ? {$_.Name -like "*_$AppName" }).DN)
				if ($FullSearch -ne $null) {
					if (($FullSearch.GetType()).BaseType -eq "System.Array") {
						foreach ($FS in $FullSearch) {
							ToLog $LFile "$FS"
						}
					} else {
						ToLog $LFile "$FullSearch"
						$SecGroup = $FullSearch
						$ML = getMemberList -SecGroup "$SecGroup"
						$App | Add-Member -MemberType NoteProperty -Name "Members" -Value $ML
					}
				} else {
					ToLog $LFile "No security group was found ending in `'$AppName`' after a broad search."
				}	
				
			}

			$App | Add-Member -MemberType NoteProperty -Name "SecGroup" -Value $SecGroup
			$App | Add-Member -MemberType NoteProperty -Name "guests" -Value $VMS

		}
		$vAppList += $App
	}
	
if ($vAppList) {
$ErrorBody = @"
<HTML>
	<HEAD></HEAD>
		<BODY>
		The notification script was unable to determine an owner group for the following vApps which will expire soon.
		<Table border=1>
			<tr>
				<td><b>vApp Name:</b></td><td><b>Environment</b></td><td><b>Expires in Day(s):</b></td>
			</tr>
			<%TABLEDATA%>
		</Table>
		</BODY>
</HTML>
"@
$ErrorCount = 0
$ErrorsTable = ""
	foreach ($vAppObj in $vAppList) {
$eBody = @"
<HTML>
	<HEAD></HEAD>
		<BODY>
		Hello. Your vApp "<%VAPPNAME%>" in the "<%ENV%>" environment will expire in <%VDays%> day(s). <br /><br />
		If you need this vApp for longer, Please open up a ticket to have the vApp expiration date extended. Othewise,
		do nothing, and this vApp will expire on <%EXPDATE%>. <br /><br />
		Virtual machines within the "<%VAPPNAME%>" vApp: <br /><br />
		<Table border=1>
			<tr>
				<td><b>VM Name:</b></td>
			</tr>
			<%TABLEDATA%>
		</Table>
		</BODY>
</HTML>
"@
		if ((($vAppObj.SecGroup) -ne $null) -or (($vAppObj.SecGroup) -eq "")) {
			$vName = $vAppObj.Name
			$vDaysLeft = ($vAppObj.TimeLeft).Days
			$eBody = $eBody.Replace("<%VAPPNAME%>", $vAppObj.Name)
			$eBody = $eBody.Replace("<%VDays%>", $vDaysLeft)
			$TimeSpan = $vAppObj.TimeLeft
			$cDate = Get-Date
			$fDate = $cDate + $TimeSpan
			$ExpDate = (Get-Date $fDate -UFormat "%A, %b %d, %Y")
			$eBody = $eBody.Replace("<%EXPDATE%>", $ExpDate)
			
			$eBody = $eBody.Replace("<%ENV%>", $vAppObj.OrgName)
			
			$TD = ""
			foreach ($vm in ($vAppObj.Guests)) {
				$TD = $TD + "<tr><td>$vm</td></tr>"
			}
			$eBody = $eBody.Replace("<%TABLEDATA%>", $TD)
			
			$ToLine = ""
			$vMembers = $vAppObj.Members
			foreach ($User in $vMembers) {
				$User_Mail = $User.Mail
				if ($User_Mail) {
					if ($User_Mail -ne "") {
						[String]$ToLine += $User_Mail + ", "
					}
				}
			}
			$ToLine = $ToLine.TrimEnd(", ")
			
			$Subject = "Your vApp `"$vName`" will expire in $vDaysLeft day(s)!"
			if ($ToLine -ne "") {
				ToLog $LFile "Sending Email `'$Subject`' to `'$ToLine`'"
				#$MailCheck = Send-MailMessage -To "$ToLine" -Subject $Subject -BodyAsHtml $eBody -From $AdminResponseEmail -SmtpServer $SMTPServer -Priority Normal
				$MailCheck = Send-MailMessage -To "$TESTMAILTO" -Subject $Subject -BodyAsHtml $eBody -From $AdminResponseEmail -SmtpServer $SMTPServer -Priority Normal
				if ($?) {
					ToLog $LFile "Success."
				} else {
					ToLog $LFile "Failure."
				}
				$MailCheck = $null
			} else {
				$Subject = "[Could not find a user to send mail to] Your vApp `"$vName`" will expire in $vDaysLeft day(s)! "
				ToLog $LFile "Sending Email `'$Subject`' to `'$AdminResponseEmail`'"
				#$MailCheck = Send-MailMessage -To $AdminResponseEmail -Subject $Subject -BodyAsHtml $eBody -From $AdminResponseEmail -SmtpServer $SMTPServer -Priority Normal
				$MailCheck = Send-MailMessage -To "$TESTMAILTO" -Subject $Subject -BodyAsHtml $eBody -From $AdminResponseEmail -SmtpServer $SMTPServer -Priority Normal
				if ($?) {
					ToLog $LFile "Success."
				} else {
					ToLog $LFile "Failure."
				}
				$MailCheck = $null
			}
		} else {
			$vAppName = $vAppObj.Name
			$vDaysLeft = ($vAppObj.TimeLeft).Days
			$vOrg = $vAppObj.OrgName
			$ErrorsTable = $ErrorsTable + "<tr><td>$vAppName</td><td>$vOrg</td><td>$vDaysLeft</td></tr>"
			$ErrorCount++
		}
	}
	if ($ErrorCount -gt 0) {
		$Subject = "The following vApps could not be matched to an owner."
		$ErrorBody = $ErrorBody.Replace("<%TABLEDATA%>", $ErrorsTable)
		ToLog $LFile "Sending Email `'$Subject`' to `'$AdminResponseEmail`'"
		#$MailCheck = Send-MailMessage -To $AdminResponseEmail -Subject $Subject -BodyAsHtml $ErrorBody -From $AdminResponseEmail -SmtpServer $SMTPServer -Priority Normal
		$MailCheck = Send-MailMessage -To "$TESTMAILTO" -Subject $Subject -BodyAsHtml $ErrorBody -From $AdminResponseEmail -SmtpServer $SMTPServer -Priority Normal
		if ($?) {
			ToLog $LFile "Success."	
		} else {
			ToLog $LFile "Failure."
		}
		$MailCheck = $null
	}
}
