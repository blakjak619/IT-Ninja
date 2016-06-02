$HKLM = 2147483650

# Setup the Standard Registry Provider class to get access to the class methods
$Reg = [WMIClass]"\\.\root\default:StdRegProv"
# Get the SystemSecurity class (I probably only need to do this once, not for each reg)
$security = Get-WmiObject -Namespace root/cimv2 -Class __SystemSecurity
# Make a converter object (I probably only need to do this once, not for each reg)
$converter = new-object system.management.ManagementClass Win32_SecurityDescriptorHelper

<#
.SYNOPSIS
	ConfigureDTCLocalComputer sets localcomputer-wide Distributed Transaction COM settings.
.DESCRIPTION
	ConfigureDTCLocalComputer sets localcomputer-wide Distributed Transaction COM settings like:
	Transaction Timeout time
	DCOM enabled
	COM Internet Services enabled
	Default Authentication Level
	Default Impersonation level
.NOTES  
    File Name  : STIG-ConfigureDTC.ps1  
	Author  : Dan Meier
    Date	: 12/31/2013 
.LINK  
	http://msdn.microsoft.com/en-us/library/windows/desktop/ms687763(v=vs.85).aspx
	http://msdn.microsoft.com/en-us/library/windows/desktop/ms682790(v=vs.85).aspx
.EXAMPLE
	ConfigureDTCLocalComputer -TransactionTimeout 0 -DCOMEnabled $true -CISEnabled $true -DefaultAuthenticationLevel "Connect" -DefaultImpersonationLevel "Identify" -Restart "Enabled"
.EXAMPLE
	ConfigureDTCLocalComputer -TransactionTimeout 20
.PARAMETER TransactionTimeout
	integer value 0 to 3600. Time in minutes to wait transactions to timeout. A value of zero means to wait forever (no timeout). Maximum time is six hours.
.PARAMETER DCOMEnabled
	bool value Set to True to enable DCOM on the computer.
.PARAMETER CISEnabled
	bool value Indicates whether COM Internet Services is enabled.
.PARAMETER DefaultAuthenticationLevel
	string value Authentication level used by applications that have Authentication set to Default. Values correspond to the Remote Procedure Call (RPC) authentication settings. 
	Expected values are: "Default","None","Connect","Call","Packet","Integrity","Privacy"
.PARAMETER DefaultImpersonationLevel
	string value Impersonation level to allow if one is not set.
	Expected values are: "Anonymous","Identify","Impersonate","Delegate"
.PARAMETER Restart
	string value Indicates whether the script can restart the MSDTC service if such a restart is required.
	Expected values are "Enabled","Disabled","Ignore"
#>
Function ConfigureDTCLocalComputer {
	param (
		[ValidateRange(0,3600)]	[int]$TransactionTimout, #Setting to 0 disables timeouts.
		[bool]$DCOMEnabled,
		[bool]$CISEnabled, # COM Internet Services
		[ValidateSet("Default","None","Connect","Call","Packet","Integrity","Privacy")] [string]$DefaultAuthenticationLevel,
		[ValidateSet("Anonymous","Identify","Impersonate","Delegate")] [string]$DefaultImpersonationLevel,
		[ValidateSet("Enabled","Disabled","Ignore")] [string]$Restart
		)
		
	LLTraceMsg -InvocationInfo $MyInvocation
	
	$comAdmin = New-Object -ComObject ("COMAdmin.COMAdminCatalog")
	$LocalCollection = $comAdmin.Connect("localhost")
	$LocalComputer = $LocalCollection.GetCollection("LocalComputer","$LocalCollection.Name")
	$LocalComputer.Populate()
	
	$LocalComputerItem = $LocalComputer.Item(0)
	
	if ($TransactionTimeout) {
		$LocalComputerItem.Value("TransactionTimeout") = $TransactionTimout
	}
	
	if (! ($DCOMEnabled -eq $null)) { #If a parameter was provided
		if ($DCOMEnabled) {
			$LocalComputerItem.Value("DCOMEnabled") = 1
		} else {
			$LocalComputerItem.Value("DCOMEnabled") = 0
		}
	}
	
	if (! ($CISEnabled -eq $null)) { #If a parameter was provided
		if ($CISEnabled) {
			$LocalComputerItem.Value("CISEnabled") = 1
		} else {
			$LocalComputerItem.Value("CISEnabled") = 0
		}
	}
	
	if ($DefaultAuthenticationLevel) {

		switch ($DefaultAuthenticationLevel) {
			"Default"	{ $setting = 0 }
			"None"		{ $setting = 1 }
			"Connect"	{ $setting = 2 }
			"Call"		{ $setting = 3 }
			"Packet"	{ $setting = 4 }
			"Integrity"	{ $setting = 5 }
			"Privacy"	{ $setting = 6 }
		}
		
		$LocalComputerItem.Value("DefaultAuthenticationLevel") = $setting
	}
	
	if ($DefaultImpersonationLevel) {
	
		switch ($DefaultImpersonationLevel) {
			"Anonymous" { $setting = 1 }
			"Identify"	{ $setting = 2 }
			"Impersonate" { $setting = 3 }
			"Delegate"	{ $setting = 4 }
		}
		
		$LocalComputerItem.Value("DefaultImpersonationLevel") = $setting
	}
	
	try {
		$LocalComputer.SaveChanges()
	} catch {
		Write-Host "Unable to configure MSDTC Settings!! `n`n $_" -ForegroundColor Red -BackgroundColor White
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "Unable to configure MSDTC Settings!! $_"
		}
	}
#This should be the last thing...
	if ($Restart -eq "Enabled") {
		try {
			Restart-Service -Name "MSDTC"
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Successfully restarted MSDTC service."
			}
		} catch [Exception] {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Unable to restart MSDTC Service! $_"
			}
		}
	}
}
Function ConfigureDTCSec {
	param ([String]$NetDTCAccess, `
	[String]$XATrans, `
	[String]$SNALUTrans, `
	[String]$AllowRemoteClient, `
	[String]$AllowRemoteAdmin, `
	[String]$AllowInbound, `
	[String]$AllowOutbound, `
	[String]$MutualAuthReq, `
	[String]$IncomingAuthReq, `
	[String]$NoAuthReq, `
	[String]$Restart)
	
	LLTraceMsg -InvocationInfo $MyInvocation
	
$Usage = @"
#-------------------------------------------------------------------------
# Solution: ConfigureDTCSec
# Author: Sly Stewart
# Updated: 12/04/2012
# Version: 1.01
<#
# Description:
- Configures DTC based on passed parameters

#
# Usage:
# - ConfigureDTCSec -StringParameter "Enabled" | "Disabled" | "Ignore"
#
# - ConfigureDTCSec -NetDTCAccess "Enabled" -AllowRemoteClient "Enabled" -AllowRemoteAdmin "Disabled" -Restart "Enabled"
#	#Configure DTC with the following parameters:
	# Enable DTC Access
	# Allow Remote Clients
	# Disable Remote Administration
	# Restart the MSDTC Service when all other configurations have been made.
#
# - ConfigureDTCSec -NetDTCAccess "Enabled" -XATrans "Enabled" -AllowInbound "Enabled" -NoAuthReq "Enabled" -Restart "Enabled"
#	#Configure DTC with the following parameters:
	# Enable DTC Access
	# Enable XA Transactions
	# Allow Inbound Connections
	# Allow No Authentication Required
	# Restart the MSDTC Service when all other configurations have been made.

#>
# Revision History
# Version 1.0 - Initial Commit 
# Version 1.01 - Added in Ignore as a possible valuse to make automated script processing easier.
#-------------------------------------------------------------------------

"@

	if ($PSBoundParameters.Count -eq 0) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ConfigureDTCSec"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
	}
	#Creative ways to do input validation...
	$PossibleValues = @{"Enabled"=0; "Disabled"=0; "Ignore"=0}
	if ($NetDTCAccess) {
		if (!($PossibleValues.ContainsKey($NetDTCAccess))) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ConfigureDTCSec (NetDTCAccess)"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
		}
	}
	if ($XATrans) {
		if (!($PossibleValues.ContainsKey($XATrans))) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ConfigureDTCSec (XATrans)"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
		}
	}
	if ($SNALUTrans) {
		if (!($PossibleValues.ContainsKey($SNALUTrans))) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ConfigureDTCSec (SNALUTrans)"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
		}
	}
	if ($AllowRemoteClient) {
		if (!($PossibleValues.ContainsKey($AllowRemoteClient))) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ConfigureDTCSec (AllowRemoteClient)"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
		}
	}
	if ($AllowRemoteAdmin) {
		if (!($PossibleValues.ContainsKey($AllowRemoteAdmin))) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ConfigureDTCSec (AllowRemoteAdmin)"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
		}
	}
	if ($AllowInbound) {
		if (!($PossibleValues.ContainsKey($AllowInbound))) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ConfigureDTCSec (AllowInbound)"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
		}
	}
	if ($AllowOutbound) {
		if (!($PossibleValues.ContainsKey($AllowOutbound))) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ConfigureDTCSec (AllowOutbound)"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
		}
	}
	
	if ($MutualAuthReq) {
		if (!($PossibleValues.ContainsKey($MutualAuthReq))) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ConfigureDTCSec (MutualAuthReq)"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
		}
	}
	if ($IncomingAuthReq) {
		if (!($PossibleValues.ContainsKey($IncomingAuthReq))) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ConfigureDTCSec (IncomingAuthReq)"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
		}
	}
	if ($NoAuthReq) {
		if (!($PossibleValues.ContainsKey($NoAuthReq))) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ConfigureDTCSec (NoAuthReq)"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
		}
	}
	if ($Restart) {
		if (!($PossibleValues.ContainsKey($Restart))) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ConfigureDTCSec (Restart)"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
		}
	}

	$DTCBaseKey = "HKLM:\Software\Microsoft\MSDTC"
	try {
#Enable Network DTC Access
		if ($NetDTCAccess) {
			if ($NetDTCAccess -eq "Enabled") {
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "NetworkDtcAccess" -Value 1
			} elseif ($NetDTCAccess -eq "Disabled") {
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "NetworkDtcAccess" -Value 0
			}
		}
#Enable XA Transactions
		if ($XATrans) {
			if ($XATrans -eq "Enabled") {
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "XaTransactions" -Value 1
			} elseif ($XATrans -eq "Disabled") {
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "XaTransactions" -Value 0
			}
		}
#Enable SNA LU 6.2 Transactions
		if ($SNALUTrans) {
			if ($SNALUTrans -eq "Enabled") {
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "LuTransactions" -Value 1
			} elseif ($SNALUTrans -eq "Disabled") {
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "LuTransactions" -Value 0
			}
		}
# Client and Administration
#Allow Remote Clients
		if ($AllowRemoteClient) {
			if ($AllowRemoteClient -eq "Enabled") {
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "NetworkDtcAccessClients" -Value 1
			} elseif ($AllowRemoteClient -eq "Disabled") {
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "NetworkDtcAccessClients" -Value 0
			}
		}
#Enable Remote Administration
		if ($AllowRemoteAdmin) {
			if ($AllowRemoteAdmin -eq "Enabled") {
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "NetworkDtcAccessAdmin" -Value 1
			} elseif ($AllowRemoteAdmin -eq "Disabled") {
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "NetworkDtcAccessAdmin" -Value 0
			}
		}
# Transaction Manager Communication
#Allow Inbound Communication
		if ($AllowInbound) {
			if ($AllowInbound -eq "Enabled") {
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "NetworkDtcAccess" -Value 1
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "NetworkDtcAccessTransactions" -Value 1
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "NetworkDtcAccessInbound" -Value 1
			} elseif ($AllowInbound -eq "Disabled") {
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "NetworkDtcAccessInbound" -Value 0		
			}
		}
#Allow Outbound Communication
		if ($AllowOutbound) {
			if ($AllowOutbound -eq "Enabled") {
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "NetworkDtcAccess" -Value 1
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "NetworkDtcAccessTransactions" -Value 1
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "NetworkDtcAccessOutbound" -Value 1
			} elseif ($AllowOutbound -eq "Disabled") {
				Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "NetworkDtcAccessOutbound" -Value 0
			}
		}
# Radio Auth Group
#Mutual Authentication Required
		if ($MutualAuthReq -eq "Enabled") {
				Set-ItemProperty -Path "$DTCBaseKey" -Name "AllowOnlySecureRpcCalls" -Value 1
				Set-ItemProperty -Path "$DTCBaseKey" -Name "FallbackToUnsecureRPCIfNecessary" -Value 0
				Set-ItemProperty -Path "$DTCBaseKey" -Name "TurnOffRpcSecurity" -Value 0
		}
#Incoming Caller Authentication Required
		if ($IncomingAuthReq -eq "Enabled") {
				Set-ItemProperty -Path "$DTCBaseKey" -Name "AllowOnlySecureRpcCalls" -Value 0
				Set-ItemProperty -Path "$DTCBaseKey" -Name "FallbackToUnsecureRPCIfNecessary" -Value 1
				Set-ItemProperty -Path "$DTCBaseKey" -Name "TurnOffRpcSecurity" -Value 0
		}
#No Authentication Required
		if ($NoAuthReq -eq "Enabled") {
				Set-ItemProperty -Path "$DTCBaseKey" -Name "AllowOnlySecureRpcCalls" -Value 0
				Set-ItemProperty -Path "$DTCBaseKey" -Name "FallbackToUnsecureRPCIfNecessary" -Value 0
				Set-ItemProperty -Path "$DTCBaseKey" -Name "TurnOffRpcSecurity" -Value 1
		}
# End Radio Auth Group
#DTC Logon Account
	<#Does not actually work.
		if ($DTCLogonAcct) {
			Set-ItemProperty -Path "$DTCBaseKey\Security" -Name "AccountName" -Value $DTCLogonAcct
			#Default is "NT AUTHORITY\NetworkService"
		}
#>
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "Successfully configured MSDTC settings."
		}
	} catch [Exception] {
		Write-Host "Unable to configure MSDTC Settings!! `n`n $_" -ForegroundColor Red -BackgroundColor White
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "Unable to configure MSDTC Settings!! $_"
		}
	}
#This should be the last thing...
	if ($Restart -eq "Enabled") {
		try {
			Restart-Service -Name "MSDTC"
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Successfully restarted MSDTC service."
			}
		} catch [Exception] {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Unable to restart MSDTC Service! $_"
			}
		}
	}
}
<#
.SYNOPSIS
	GetTheDCOMSDDL will get the binary Security Descriptor from a DCOM registry key and convert it a text SDDL and return the SDDL.
.DESCRIPTION
	GetTheDCOMSDDL will take a binary form Security Descriptor from one of these registry keys 
	("DefaultAccessPermission","DefaultLaunchPermission","MachineAccessRestriction","MachineLaunchRestriction") and covert it to a text 
	Security Descriptor Definition Language descriptor and return the text SDDL descriptor. 
.NOTES  
    File Name  : STIG-ConfigureDTC.ps1  
	Author  : Dan Meier
    Date	: 4/7/2014
.LINK  
	http://msdn.microsoft.com/en-us/library/windows/desktop/aa379567(v=vs.85).aspx Security Descriptor Definition Language
	http://msdn.microsoft.com/en-us/library/windows/desktop/aa379570(v=vs.85).aspx SDDL string format
	http://msdn.microsoft.com/en-us/library/windows/desktop/aa374928(v=vs.85).aspx ACE Strings
	http://msdn.microsoft.com/en-us/library/windows/desktop/aa379602(v=vs.85).aspx SID Strings
.EXAMPLE
	$SDDL = GetTheDCOMSDDL "MachineAccessRestriction"
.PARAMETER RegKey
	One of these: ("DefaultAccessPermission","DefaultLaunchPermission","MachineAccessRestriction","MachineLaunchRestriction"))
#>
function GetTheDCOMSDDL {
	param( 
		[ValidateSet("DefaultAccessPermission", "DefaultLaunchPermission","MachineAccessRestriction","MachineLaunchRestriction")] [string]$RegKey
	)

	LLTraceMsg -InvocationInfo $MyInvocation
	
	# Create an empty array to pass to the GetSD which will get filled by that call
	$binarySD = @($null)
	
	# Using the GetBinaryValue method of the Standard Registry Provider class get the registry value
	# from HKLM (2147483650) "software\microsoft\ole" "DefaultAccessPermission"
	$DCOM = $Reg.GetBinaryValue($HKLM,"software\microsoft\ole","$RegKey").uValue
	
    if ($DCOM) {
	    # Use the convert method to convert the DCOM registry SD
	    $outDCOMSDDL = ([wmiclass]"Win32_SecurityDescriptorHelper").BinarySDToSDDL($DCOM)
    } else {
        $outDCOMSDDL = ""
    }
	
	return $outDCOMSDDL
}
<#
.SYNOPSIS
	SDDLAddRights will take a text Security Descriptor Definition Language and an ACE and add the ACE permissions to the SDDL.
.DESCRIPTION
	SDDLAddRights will take a text Security Descriptor Definition Language and an ACE. It will match the ACE_Type and ACE_SID in the SDDL if there is a match
	will merge the existing ACE permissions with the specified permissions. If there is no match then the specified ACE will be added.
.NOTES  
    File Name  : STIG-ConfigureDTC.ps1  
	Author  : Dan Meier
    Date	: 4/7/2014
.LINK  
	http://msdn.microsoft.com/en-us/library/windows/desktop/aa379567(v=vs.85).aspx Security Descriptor Definition Language
	http://msdn.microsoft.com/en-us/library/windows/desktop/aa379570(v=vs.85).aspx SDDL string format
	http://msdn.microsoft.com/en-us/library/windows/desktop/aa374928(v=vs.85).aspx ACE Strings
	http://msdn.microsoft.com/en-us/library/windows/desktop/aa379602(v=vs.85).aspx SID Strings
.EXAMPLE
	$NewSDDL = SDDLAddRights "O:BAG:BAD:(A;;CCDCLCSWRP;;;WD)(A;;CCDCLCSWRP;;;BA)(A;;CCDCLCSWRP;;;DA)" "(A;;CCDCLC;;;DU)"
.PARAMETER SDDL
	A Security Descriptor Definition Language specification of a Security Descriptor (can be an empty string)
.PARAMETER ReqACE
	The requested ACE to be added. In the ACE format (ace_type;ace_flags;rights;object_guid;inherit_object_guid;account_sid;(resource_attribute))
#>
Function SDDLAddRights ([string]$SDDL, [string]$ReqACE) {
	LLTraceMsg -InvocationInfo $MyInvocation
	
	# $SDDL is the entire existing SDDL format is O:ownersidG:groupsidD:daclflags(ACEString)S:saclflags(ACEString)
	# $ReqACE is in the format of (ace_type;ace_flags;rights;object_guid;inherit_object_guid;account_sid;(resource_attribute)

	Set-Variable CONST_TYPE -option Constant -Value 0
	Set-Variable CONST_FLAGS -option Constant -Value 1
	Set-Variable CONST_RIGHTS -option Constant -Value 2
	Set-Variable CONST_OBJGUID -option Constant -Value 3
	Set-Variable CONST_INOOBJGUID -option Constant -Value 4
	Set-Variable CONST_ACCT_SID -option Constant -Value 5
	
	if ($SDDL.Length -lt 6) {
		# Just add the ACE, there are no existing ACE's we have to add to
		# Add a prefix (the Owner SID, Group SID, DACL flags (SACL flags if needed, not needed in this case)
		$SDDL = "O:BAG:BAD:AI"
		$SDDL += $ReqACE
	} else { 
		# There ARE existing ACEs
		# Is there an ACE in the SDDL that matches the requested ACE (matching ACE Type and Account SID)?
			# Split the requested ACE up into it's component parts
			# ACE format is (A;;(ABCCDE);;;DA) | See http://msdn.microsoft.com/en-us/library/windows/desktop/aa374928(v=vs.85).aspx for details
		$ACEArray = $ReqACE -split ";"
		
		$ACE_Type = $ACEArray[$CONST_TYPE]
		$ACE_SID = $ACEArray[$CONST_ACCT_SID]
		
		# Now that we know the Type and SID see if there is an existing ACE with the same Type and SID.
		# If there is extract it from the SDDL, break it up into an array and compare the RIGHTS. 
		# If the rights are the same then no change is needed so just add either of the ACEs (the original or the requested) to SDDL
		# You have to add because we extracted it to examine it.
		# If they are different then add the requested RIGHTS to the original ACE and add it to the SDDL
		#
		# I'm using a regular expression to find and extract any ACE with a matching Type and SID to our requested ACE
		# The regex is translated as find a group (outer parens) that looks like a left paren (the \( - parens are special chars in regex and have to be escaped with a backslash))
		#   followed by the $ACE_Type contents followed by a semi-colon followed by one or more characters that are not )( and that are followed by a semi-colon followed by the $ACE_SID contents followed
		#   by a closing paren.
		# Note that if an actual SID (like S-1-0-0-1 for Everyone) is used and the SID constant (like WD also for Everyone) is used they WON'T match. However I think that when you write
		#   the SDDL back to the registry it will combine them.
		$RegExPattern = [regex]"(\($ACE_Type;[^)(]+;$ACE_SID\))"
		
		if ($SDDL -match $RegExPattern) {
			#If there is a match then $Matches will contain an array of matching elements
            $MatchingACE = $Matches[0]
            # Remove the matched ACE from the SDDL. The $MatchingACE has parens in it so we have to wrap the variable in $([regex]::Escape($var)) to escape the parens.
            $SDDL = $SDDL -replace "$([regex]::Escape($MatchingACE))", ""
            $ExistACEArray = $MatchingACE -split ";"

            if ($ACEArray[$CONST_RIGHTS] -ne $ExistACEArray[$CONST_RIGHTS]) {
                $ExistACEArray[$CONST_RIGHTS] += $ACEArray[$CONST_RIGHTS]
            }

            # Reassemble the SDDL now that we (may or may not have altered it)
            $SDDL += ($ExistACEArray -join ";")
		
		} else {
			#There was no match so just append the requested ACE to the SDDL (with parens)
			$SDDL += "$ReqACE"
		}
	}
	return $SDDL
}
<#
.SYNOPSIS
	SetTheDCOMSDDL will take a text Security Descriptor Definition Language and covert it to binary form and then apply that to one of the four
	DCOM security registry keys ("DefaultAccessPermission","DefaultLaunchPermission","MachineAccessRestriction","MachineLaunchRestriction").
.DESCRIPTION
	This function will convert an SDDL text string into binar and then change one of the four registry entries at "HKey_Local_Machine\software\microsoft\ole":
	"DefaultAccessPermission","DefaultLaunchPermission","MachineAccessRestriction","MachineLaunchRestriction"
.NOTES  
    File Name  : STIG-ConfigureDTC.ps1  
	Author  : Dan Meier
    Date	: 4/7/2014
.LINK  
	http://msdn.microsoft.com/en-us/library/windows/desktop/aa379567(v=vs.85).aspx Security Descriptor Definition Language
	http://msdn.microsoft.com/en-us/library/windows/desktop/aa379570(v=vs.85).aspx SDDL string format
	http://msdn.microsoft.com/en-us/library/windows/desktop/aa374928(v=vs.85).aspx ACE Strings
	http://msdn.microsoft.com/en-us/library/windows/desktop/aa379602(v=vs.85).aspx SID Strings
.EXAMPLE
	$result = SetTheDCOMSDDL "DefaultLaunchPermission" "O:BAG:BAD:(A;;CCDCLCSWRP;;;WD)(A;;CCDCLCSWRP;;;BA)(A;;CCDCLCSWRP;;;DA)(A;;CCDCLCSWRP;;;DU)(A;;CCDCLCSWRP;;;LU)(A;;CCDCLCSWRP;;;S-1-5-32-562)"
.PARAMETER RegKey
	One of these: ("DefaultAccessPermission","DefaultLaunchPermission","MachineAccessRestriction","MachineLaunchRestriction")
.PARAMETER NewSecDesc
	Is a full SDDL string format consisting of O:owner_sid, G:group_sid, D:dacl_flags(string ace1)...(string_acen),[S:sacl_flags(string_aces)]
	e.g.: O:BAG:BAD:(A;;CCDCLCSWRP;;;WD)(A;;CCDCLCSWRP;;;BA)(A;;CCDCLCSWRP;;;DA)
#>
function SetTheDCOMSDDL {
	param(
		[ValidateSet("DefaultAccessPermission", "DefaultLaunchPermission","MachineAccessRestriction","MachineLaunchRestriction")] [string]$RegKey,
		[string]$NewSecDesc 
	)
	LLTraceMsg -InvocationInfo $MyInvocation
	
	$DCOMbinarySD = ([wmiclass]"Win32_SecurityDescriptorHelper").SDDLToBinarySD($NewSecDesc) # Another way to do the conversion
	$DCOMconvertedPermissions = ,$DCOMbinarySD.BinarySD
	# Write it back to the registry
	$result = $Reg.SetBinaryValue($HKLM,"software\microsoft\ole","$RegKey", $DCOMbinarySD.binarySD)
	
	return $result
}
function New-DComAccessControlEntry {
param(
    [Parameter(Mandatory=$true)][string]$Account,
	[Parameter(Mandatory=$true)][int]$ACEFlags,
	[Parameter(Mandatory=$true)][int]$ACEType,
	[Parameter(Mandatory=$true)][int]$AccessMask,
    [switch]$Group
)
	$acctarray = $Account -split("\\")
	if($acctarray.Count -lt 2){
		LLToLog -EntryId $LLERROR -Text "New-DCOMAccessControlEntry - Account must be in the form of domain\account. Data provided was $Account."
		$Status = $false
	} else {
		$Domain = $acctarray[0]
		$Name = $acctarray[1]
	}
	
    #Create the Trusteee Object
    $Trustee = ([WMIClass] "\\$ComputerName\root\cimv2:Win32_Trustee").CreateInstance()
    #Search for the user or group, depending on the -Group switch
    if (!$group) { 
        $account = [WMI] "\\$ComputerName\root\cimv2:Win32_Account.Name='$Name',Domain='$Domain'" }
    else { 
        $account = [WMI] "\\$ComputerName\root\cimv2:Win32_Group.Name='$Name',Domain='$Domain'" 
    }
 
    #Get the SID for the found account.
    $accountSID = [WMI] "\\$ComputerName\root\cimv2:Win32_SID.SID='$($account.sid)'"
 
    #Setup Trusteee object
    $Trustee.Domain = $Domain
    $Trustee.Name = $Name
    $Trustee.SID = $accountSID.BinaryRepresentation
 
    #Create ACE (Access Control List) object.
    $ACE = ([WMIClass] "\\$ComputerName\root\cimv2:Win32_ACE").CreateInstance()
 
    # COM Access Mask
    #   Execute         =  1,
    #   Execute_Local   =  2,
    #   Execute_Remote  =  4,
    #   Activate_Local  =  8,
    #   Activate_Remote = 16 
 
    #Setup the rest of the ACE.
    $ACE.AccessMask = $AccessMask
    $ACE.AceFlags = $ACEFlags
    $ACE.AceType = $ACEType
    $ACE.Trustee = $Trustee
    return $ACE
}
function SetDCOMApplicationIdentity {
param(
	[string]$Application,
	[string]$Account,
    [string]$password
)

	LLTraceMsg -InvocationInfo $MyInvocation
	
	$Status = $true
	
	#Test Params
	# Account must be fully qualified local or domain account
	# Split the account on domain\account delimiter
	$acctarray = $Account -split("\\")
	if($acctarray.Count -lt 2){
		LLToLog -EntryId $LLERROR -Text "SetDCOMApplicationIdentity - Account must be in the form of domain\account. Data provided was $Account."
		$Status = $false
	}
	
	if($Password -eq "@LOOKUP"){
		$Password = LSGet-AccountPwd -Account $Account
		if(! $Password){
			LLToLog -EntryId $LLERROR -Text "Unable to find password for $Account"
			$Status = $false
		}
	}
	
	if($Status){
		$comAdmin = New-Object -ComObject ("COMAdmin.COMAdminCatalog")
		$apps = $comAdmin.GetCollection("Applications")
		$apps.Populate()
		$app = $apps | Where-Object {$_.Name -eq $Application}
		if($app){
			$app.Value("Identity") = $Account
			$app.Value("Password") = $password
			try{
				$apps.SaveChanges()
			} catch {
				LLToLog -EntryId $LLWARN -Text "COM Application configuration failed for application $Application."
				$Status = $false
			}
		} else {
			LLToLog -EntryId $LLWARN -Text "COM Application configuration failed, could not find application $Application."
			$status = $false
		}
	}
	
	return $Status
}
function SetDCOMApplicationSecurity {
param(
	[string]$Application,
	[string]$AuthenticationLevel
)

	LLTraceMsg -InvocationInfo $MyInvocation
	
	$Status = $true
	
    $global:dcom = Get-WMIObject Win32_DCOMApplicationSetting -Filter "Description='Talisma Information Server'" -EnableAllPrivileges
    $global:dcom.AuthenticationLevel = 2
    $global:dcom.Put()
	
	return $Status
}
function ConvertTextTo-AccessMask{
param(
	[string]$AccessMaskText
)

	LLTraceMsg -InvocationInfo $MyInvocation
	
	$ListOfAccesses = $AccessMaskText.ToUpper() -split(",")
	
	$AccessMask = 0
	foreach($AccessTerm in $ListOfAccesses){
		switch($AccessTerm){
			"EXECUTE"			{$AccessMask += 1}
			"EXECUTE_LOCAL"		{$AccessMask += 2}
			"EXECUTE_REMOTE"	{$AccessMask += 4}
			"ACTIVATE_LOCAL"	{$AccessMask += 8}
			"ACTIVATE_REMOTE"	{$AccessMask += 16}
			Default				{$AccessMask += 0}
		}
	}
	
	return $AccessMask
}
function SetDCOMApplicationPermissions {
param(
	[string]$Application,
	[ValidateSet("Configuration","Launch","LaunchAccess")][string]$PermissionTarget,
	[string]$Account,
	[string]$ACEFlags,
	[string]$ACEType,
	[string]$AccessMask
)

	LLTraceMsg -InvocationInfo $MyInvocation
	
	$Filter = "Description='" + $Application + "'"
	$dcom = Get-WMIObject Win32_DCOMApplicationSetting -Filter $Filter -EnableAllPrivileges
	switch($PermissionTarget){
		"Configuration"	{$sd = $dcom.GetConfigurationSecurityDescriptor().Descriptor}
		"Launch"		{$sd = $dcom.GetLaunchSecurityDescriptor().Descriptor}
		"LaunchAccess"	{$sd = $dcom.GetLaunchAccessSecurityDescriptor().Descriptor}
		Default			{LLToLog -EventID $LLWARN -Text "It is inconceivable that you get this message: failed ValidateSet in SetDCOMApplicationPermission"}
	}

    $nsAce = $sd.Dacl | Where {$_.Trustee.Name -eq $Application}
    if ($nsAce) {
        $nsAce.AccessMask = ConvertTextTo-AccessMask -AccessMaskText $AccessMask
    } else {
        $newAce = New-DComAccessControlEntry $domain -Name $Account -AccessMask $AccessMask
        $sd.Dacl += $newAce
    }
	
	switch($PermissionTarget){
		"Configuration"	{$sd = $dcom.SetConfigurationSecurityDescriptor($sd)}
		"Launch"		{$sd = $dcom.SetLaunchSecurityDescriptor($sd)}
		"LaunchAccess"	{$sd = $dcom.SetLaunchAccessSecurityDescriptor($sd)}
		Default			{LLToLog -EventID $LLWARN -Text "It is inconceivable that you get this message: failed ValidateSet in SetDCOMApplicationPermission"}
	}
}