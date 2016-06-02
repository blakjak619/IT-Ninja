function ProcessPerms{
param( [System.Xml.XmlElement]$AdjustPermissions )
	foreach ($AP in $AdjustPermissions) {
		$AP_Action = $AP.Action
		$AP_User = $AP.User
		$AP_Target = $AP.Target
		$AP_Right = $AP.Right
		$AP_Prop = $AP.Propagation
		$AP_ACE = $AP.ACE
		switch ($AP_Action) {
			"Add" {
				FSAddUserPerm -Target $AP_Target -User $AP_User -RightEnum $AP_Right -PropagationEnum $AP_Prop -ACEEnum $AP_ACE
			}
			
			"Remove" {
				FSRemoveUserPerm -Target $AP_Target -User $AP_User -RightEnum $AP_Right -PropagationEnum $AP_Prop -ACEEnum $AP_ACE
			}
			
			"DeleteUser" {
				FSRemoveUser -Target $AP_Target -User $AP_User
			}
		}
	}
}
function Manage-Perms {
param([String]$Object)
$Usage = @"
#-------------------------------------------------------------------------
# Solution: Manage-Perms
# Author: Sly Stewart 
# Updated: 2/19/2013
# Version: 1.0
<#
# Description: Returns a custom PSObject that represents a file or folder
	to change permissions on.

- Mandatory Parameters
	[String]-Object <String Path> : Path to the FileSystem object
		that needs permission changes.
		
- Exposed Methods:
	`$FSObject.ACLProtection([Bool]`$Protected, [Bool]$Inheritance)
		`$Protected: true to protect the access rules associated with this object from inheritance; false to allow inheritance.
		`$Inheritance: true to preserve inherited access rules; false to remove inherited access rules. 
			This parameter is ignored if `$Protected is false
			
	`$FSObject.CreateRule([String]$User, [String]$Right, [String]$Propagation, [String]$ACE)
		Returns rule object.
		`$User: The user in which to create a rule for.
		`$Right: The right to create the rule for. ONE of the following:
			"ReadData", "ListDirectory", "WriteData", "CreateFiles", "AppendData", "CreateDirectories", `
			"ReadExtendedAttributes", "WriteExtendedAttributes", "ExecuteFile", "Traverse", "DeleteSubdirectoriesAndFiles", `
			"ReadAttributes", "WriteAttributes", "Delete", "ReadPermissions", "ChangePermissions", "TakeOwnership", "Synchronize", `
			"FullControl", "Read", "ReadAndExecute", "Write", "Modify"
			
		`$Propagation: Specifies how this rule is propagated to child objects. ONE of the following:
			"None", "NoPropagateInherit", "InheritOnly"
			
		`$ACE: Sets the created rule to allow or deny/. ONE of the following:
			"Allow", "Deny"

	`$FSObject.AddAccessRule($Rule)
		Add the access rule to the filesystem object.
		`$Rule: Rule Object. Created from using the $FSObject.CreateRule() method.	
	
	`$FSObject.RemoveSpecificACL($Rule)
		Remove the access rule to the filesystem object.
		`$Rule: Rule Object. Created from using the $FSObject.CreateRule() method.
		
	`$FSObject.RemoveUserACL($Rule)
		Remove the access rule to the filesystem object FOR ALL rules of that user.
		`$Rule: Rule Object. Created from using the $FSObject.CreateRule() method.

#>
# Revision History
# Version 1.0 - Initial Commit 2/19/2013
#-------------------------------------------------------------------------

"@
	if (Test-Path $Object) {
		$FSObject = New-Object PSObject
		$FSObject | Add-Member -MemberType NoteProperty -Name "Path" -Value $Object
		
		#Get the ACL
		$AC = @'
return (get-acl $This.Path)
'@
		$AC_SB = [Scriptblock]::Create($AC)
		$FSObject | Add-Member -MemberType ScriptMethod -Name "ACL" -Value $AC_SB

		#SetAccessRuleProtection
		$ACRP = @'
param([Bool]$Protected, [Bool]$PreserveInheritance)
$ACL = $This.ACL()
$ACL.SetAccessRuleProtection($Protected, $PreserveInheritance)
'@
		$ACLScrpt = [ScriptBlock]::Create($ACRP)
		$FSObject | Add-Member -MemberType ScriptMethod -Name "ACLProtection" -Value $ACLScrpt
		
		$CreateRuleScrpt = @'
param([String]$FSUser, [String]$Right, [String]$Propagation, [String]$ACE)

		$FSRightsE = @("ReadData", "ListDirectory", "WriteData", "CreateFiles", "AppendData", "CreateDirectories", `
		"ReadExtendedAttributes", "WriteExtendedAttributes", "ExecuteFile", "Traverse", "DeleteSubdirectoriesAndFiles", `
		"ReadAttributes", "WriteAttributes", "Delete", "ReadPermissions", "ChangePermissions", "TakeOwnership", "Synchronize", `
		"FullControl", "Read", "ReadAndExecute", "Write", "Modify")
		
		$ACType = @("Allow", "Deny")
		
		$InheritEnum = [system.security.accesscontrol.InheritanceFlags]"ContainerInherit, ObjectInherit"
		
		$PropagationEnum = @("None", "NoPropagateInherit", "InheritOnly")

		if (!$FSUser) {
			Throw "Bad param for Right. use ONE of $FSRightsE"
		}
		if (!($FSRightsE | Select-String $Right)) {
			Throw "Bad param for Right. use ONE of $FSRightsE"
		}
		if (!($ACType | Select-String $ACE)) {
			Throw "Bad param for Right. use ONE of $FSRightsE"
		}
		if (!($PropagationEnum | Select-String $Propagation)) {
			Throw "Bad param for Right. use ONE of $FSRightsE"
		}
		
		$File = gi $This.Path
		if ($File.PSIsContainer) {
			$Rule = New-Object System.Security.AccessControl.FileSystemAccessRule($FSUser, $Right, $InheritEnum, $Propagation, $ACE)
		} else {
			$Rule = New-Object System.Security.AccessControl.FileSystemAccessRule($FSUser, $Right, $ACE)
		}
		
		return $Rule
'@

		$CRuleBlock = [ScriptBlock]::Create($CreateRuleScrpt)
		$FSObject | Add-Member -MemberType ScriptMethod -Name CreateRule -Value $CRuleBlock
		
		$SARScrpt = @'
param([System.Security.AccessControl.FileSystemAccessRule]$AccessRule)
	$ACL = $This.ACL()
	try {
		$ACL.AddAccessRule($AccessRule)
		Set-Acl $This.Path $ACL
	} catch [Exception] {
		$Pth = $This.Path
		Write-host "Unable to set the access rule for `'$Pth`' $_"
	}
'@

		$SARBlock = [ScriptBlock]::Create($SARScrpt)
		$FSObject | Add-Member -MemberType ScriptMethod -Name AddAccessRule -Value $SARBlock
		
		$RemSpecACL_Scrpt = @'
param([System.Security.AccessControl.FileSystemAccessRule]$AccessRule)
$ACL = $This.ACL()
try {
		$ACL.RemoveAccessRuleSpecific($AccessRule)
		Set-Acl $This.Path $ACL
	} catch [Exception] {
		$Pth = $This.Path
		Write-host "Unable to remove the access rule for `'$Pth`'"
	}
'@
		$RMS_Block = [ScriptBlock]::Create($RemSpecACL_Scrpt)
		$FSObject | Add-Member -MemberType ScriptMethod -Name RemoveSpecificACL -Value $RMS_Block
		
		$RMUserACL_Scrpt = @'
param([String]$User)
$ACLRule = $This.CreateRule($User, "ReadData", "None", "Allow")
	$ACL = $This.ACL()
	try {
		$ACL.RemoveAccessRuleAll($ACLRule)
		Set-Acl $This.Path $ACL
	} catch [Exception] {
		$Pth = $This.Path
		Write-host "Unable to remove the access rule(s) for `'$User`' on `'$Pth`'"
	}
'@
		$RUserBlock = [ScriptBlock]::Create($RMUserACL_Scrpt)
		$FSObject | Add-Member -MemberType ScriptMethod -Name RemoveUserACL -Value $RUserBlock

		return $FSObject
		
	} else {
		Throw "`'$Object`' Does not currently exist!"
	}
}

Function FSTestUserPerm{
param([parameter(Mandatory=$true)][String]$Target, `
[parameter(Mandatory=$true)][String]$User, `
[parameter(Mandatory=$true)][String]$RightEnum, `
[parameter(Mandatory=$true)][String]$ACEEnum)
	
	#Form a comparison string
	$TestString = "*$User $ACEEnum $RightEnum"

	#Get the object's permissions
	$permArray = (Get-Item $Target).GetAccessControl().AccessToString -split "`n"

	# Loop thru the array, trimming multiple spaces and comparing to test string. If you have a match then that permission is set, stop checking
	foreach($permSet in $permArray){
		if($permSet -replace '\s+', ' ' -like $TestSTring){
			return $true
		}
	}

	return $false
}
Function FSAddUserPerm {
param([parameter(Mandatory=$true)][String]$Target, `
[parameter(Mandatory=$true)][String]$User, `
[parameter(Mandatory=$true)][String]$RightEnum, `
[parameter(Mandatory=$true)][String]$PropagationEnum, `
[parameter(Mandatory=$true)][String]$ACEEnum)

	$TestPermHash = @{"-Target" = $Target; "-User" = $User;"-RightEnum" = $RightEnum;"-ACEEnum" = $ACEEnum}

	if(FSTestUserPerm @TestPermHash){
		LLToLog -EventID $LLINFO -Text "Permission $RightEnum for $User on $Target was already set. No action taken."
	} else {
		try {
			$FSO = Manage-Perms -Object $Target
			if ($FSO) {
				$FSRule = $FSO.CreateRule($User, $RightEnum, $PropagationEnum, $ACEEnum)
				$FSO.AddAccessRule($FSRule)
			}
			if ($LoggingCheck) {
				if(FSTestUserPerm @TestPermHash){
					ToLog -LogFile $LFName -Text "Successfully added `'$User`' permission `'$RightEnum`' on `'$Target`'"
				} else {
					LLToLog -EventID $LLERROR -Text "FAILURE:: Failed to add `'$User`' permission `'$RightEnum`' on `'$Target`' with no error message."
				}
			}
		} catch [Exception] {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: There was an issue adding `'$User`' permission `'$RightEnum`' on `'$Target`'. $_"
			}
		}
	}
}

Function FSRemoveUserPerm {
param([parameter(Mandatory=$true)][String]$Target, `
[parameter(Mandatory=$true)][String]$User, `
[parameter(Mandatory=$true)][String]$RightEnum, `
[parameter(Mandatory=$true)][String]$PropagationEnum, `
[parameter(Mandatory=$true)][String]$ACEEnum)

	$TestPermHash = @{"-Target" = $Target; "-User" = $User;"-RightEnum" = $RightEnum;"-ACEEnum" = $ACEEnum}
	if(FSTestUserPerm @TestPermHash){
		LLToLog -EventID $LLINFO -Text "Permission $RightEnum for $User on $Target was already not set. No action taken."
	} else {
		try {
			$FSO = Manage-Perms -Object $Target
			if ($FSO) {
				$FSRule = $FSO.CreateRule($User, $RightEnum, $PropagationEnum, $ACEEnum)
				$FSO.RemoveSpecificACL($FSRule)
			}
			if ($LoggingCheck) {
				if(FSTestUserPerm @TestPermHash){
					LLToLog -EventID $LLINFO -Text "FAILURE:: Permission $RightEnum for $User on $Target was not removed. There was no error to report."
				} else {
					ToLog -LogFile $LFName -Text "Successfully removed `'$User`' permission `'$RightEnum`' on `'$Target`'"
				}
			}
		} catch [Exception] {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: There was an issue removing `'$User`' permission `'$RightEnum`' on `'$Target`'. $_"
			}
		}
	}
}

Function FSRemoveUser {
param([parameter(Mandatory=$true)][String]$Target, `
[parameter(Mandatory=$true)][String]$User)

	try {
		$FSO = Manage-Perms -Object $Target
		if ($FSO) {
			$FSO.RemoveUserACL($User)
		}
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "Successfully Removed `'$user`' from `'$Target`'"
		}
	} catch [Exception] {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: There was an issue removing `'$user`' from `'$Target`'. $_"
		}
	}	
}

function FSSetACEProtection {
#Protected access rules cannot be modified by parent objects through inheritance.
param([parameter(Mandatory=$true)][String]$Target, `
[parameter(Mandatory=$true)][Bool]$Protected, `
#true to protect the access rules associated with this object from inheritance; false to allow inheritance.
[parameter(Mandatory=$true)][Bool]$PreserveInheritance)
#true to preserve inherited access rules; false to remove inherited access rules. This parameter is ignored if isProtected is false.

	try {
		$FSO = manage-perms -Object $Target
		if ($FSO) {
			$FSO.ACLProtection($Protected, $PreserveInheritance)
		}
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "Successfully set Inheritance protections on `'$Target`'"
		}
	} catch [Exception] {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: There was an issue setting Inheritance protections on `'$Target`' $_"
		}
	}	
}

<#
		
		$FS = Manage-Perms -Object "C:\temp\FSTEST\NF2"
		#$FS.ACLProtection($true, $false)
		$Rule = $FS.CreateRule("BRIDGEPOINT\sstewart", "FullControl", "None", "Deny")
		$FS.AddAccessRule($Rule)
		#$FS.RemoveSpecificACL($Rule)
#>