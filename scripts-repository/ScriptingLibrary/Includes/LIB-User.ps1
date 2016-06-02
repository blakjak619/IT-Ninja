#region SetUserRights
function SetUserRights{
param(
    [string]$Account,
    [string[]]$Rights #in the form of -right or +right for revoke or grant right
)

    #Validate Account
    # Presumes a username by itself is a local user
    # Domain users must be proceeded by domain\

    #Validate Right(s)
    $ValidRights = "SeNetworkLogonRight",                   "SeRemoteInteractiveLogonRight",    "SeBatchLogonRight",                  "SeInteractiveLogonRight",
                   "SeServiceLogonRight",                   "SeDenyNetworkLogonRight",          "SeDenyInteractiveLogonRight",        "SeDenyServiceLogonRight",
                   "SeDenyRemoteInteractiveLogonRight",     "SeTcbPrivilege",                   "SeMachineAccountPrivilege",          "SeIncreaseQuotaPrivilege",
                   "SeBackupPrivilege",                     "SeChangeNotifyPrivilege",          "SeSystemTimePrivilege",              "SeCreateTokenPrivilege",
                   "SeCreatePagefilePrivilege",             "SeCreateGlobalPrivilege",          "SeDebugPrivilege",                   "SeEnableDelegationPrivilege",
                   "SeRemoteShutdownPrivilege",             "SeAuditPrivilege",                 "SeImpersonatePrivilege",             "SeIncreaseBasePriorityPrivilege",
                   "SeLoadDriverPrivilege",                 "SeLockMemoryPrivilege",            "SeSecurityPrivilege",                "SeSystemEnvironmentPrivilege",
                   "SeManageVolumePrivilege",               "SeProfileSingleProcessPrivilege",  "SeSystemProfilePrivilege",           "SeUndockPrivilege",
                   "SeAssignPrimaryTokenPrivilege",         "SeRestorePrivilege",               "SeShutdownPrivilege",                "SeSynchAgentPrivilege",
                   "SeTakeOwnershipPrivilege"


    foreach($Right in $Rights){
        $ShortRight = $Right.Substring(1,$Right.Length - 1)
        if($ValidRights -contains $ShortRight) {
            $ValidatedRights += $Right[0]+"r $ShortRight "
        } else {
            LLToLog -EventID $LLWARN -Text "Request right $Right is not a valid right. Other specified rights (if any) will still be added."
        }
    }

    #Validate Tool
    $ToolPath = ".\tmp\NTRights.exe"
    if(-not (Test-Path $ToolPath)){
        LLToLog -EventID $LLERROR -Text "$ToolPath not found."
        return $false
    }

    #Assign rights
    foreach($Right in $ValidatedRights){
        $Command = "$ToolPath -u $Account $Right"
        try{
            $result = Invoke-Expression $Command
            if($result -like "*error*"){
                LLToLog -EventID $LLWARN -Text "$Command failed: $result"
            } else {
				LLToLog -EventID $LLINFO -Text "$Result"
			}
        } catch {
            LLToLog -EventID $LLWARN -Text "$Command failed: $_.Exception"
        }
    }
}
#endregion
#region ProcessUserRights
function ProcessUserRights{
param( [System.Xml.XmlElement]$UserRightParam )

    $User = $UserRightParam.User
    $RightsArray = @($UserRightParam.Rights -split " ")

    SetUserRights -Account $User -Rights $RightsArray
}
#endregion
#region AddUserToGroup
function AddUserToLocalGroup{
param( 
	[string]$User,
	[string]$Group
)
	$server = $env:computername
    try{
	    $groupobj=[adsi]"WinNT://$server/$Group,group"
	    $groupobj.psbase.Invoke("Add",([ADSI]"WinNT://$user").path)
    } catch {
        $cmd = "net localgroup " + '"' + $Group + '" "' + $User + '" /add'
        try{
            $result = Invoke-Expression $cmd -ErrorAction Stop
        } catch {
            if($_.Exception -like "*account*already a member of the group."){
                LLToLog -EventID $LLINFO -Text "The $User account is already a member of the $Group group."
            } else {
                LLToLog -EventID $LLWARN -Text "$_.Exception"
            }
        }
    }
}
#endregion
#region Unit Tests
if (($MyInvocation.Line -eq $null) -or ($MyInvocation.Line -notmatch "\. ")) {

	$LIBPATH = $env:ScriptLibraryPath
	. $LIBPATH\Includes\LIB-Includes.ps1 -DefaultLibraryPath $LIBPATH -Intentional
	LLInitializeLogging -LogLevel $LLTRACE
	
	[xml]$UserRightsParam = @"
<LocalUserRights>
    <UserRights User="bridgepoint\admdmeier" Rights="-SeBackupPrivilege +SeRestorePrivilege" />
</LocalUserRights>
"@

    $StartTime = Get-Date
	foreach($UserRight in $UserRightsParam.LocalUserRights) {
		ProcessUserRights -UserRightParam $UserRight.UserRights
	}

    Get-EventLog -LogName Application -After $StartTime | Sort-Object TimeGenerated | Format-Table -AutoSize -Wrap
}
#endregion