function CurrentNodeIsFirstNode {
param( [string] $NodeList
)
	LLTraceMsg -InvocationInfo $MyInvocation

	$NodeArray = $NodeList.split(",")
	if($NodeArray.count -gt 0) {
		if($NodeArray[0] -eq $env:ComputerName) {
			LLToLog -EventID $LLINFO -Text "$env:ComputerName is the master node"
			return $true
		}
	} else {
		LLToLog -EventID $LLWARN -Text "No nodes were provided in NodeList ($NodeList)"
	}
	return $false
}
function ClusterValidation {
param( [string] $ClusterNodes
)
	LLTraceMsg -InvocationInfo $MyInvocation
	
	if(Get-Module | where-object {$_.name -eq "FailoverClusters"}) {
		LLToLog -EventID $LLINFO -Text "$env:computername has FailoverClusters feature installed."
	} else {
		LLToLog -EventID $LLINFO -Text "$env:computername does not have FailoverClusters feature installed."
		return $false
	}

	$result = Test-Cluster -Node $nodestr
}
function CreateCluster{

	LLTraceMsg -InvocationInfo $MyInvocation

}
function ClusterNode {

	LLTraceMsg -InvocationInfo $MyInvocation
	
}
#region Unit Tests
if (($MyInvocation.Line -eq $null) -or ($MyInvocation.Line -notmatch "\. ")) {

	$LIBPATH = $env:ScriptLibraryPath
	. $LIBPATH\Includes\LIB-Includes.ps1 -DefaultLibraryPath $LIBPATH -Intentional
	LLInitializeLogging -LogLevel $LLTRACE
	
	$StartTime = Get-Date
#region CurrentNodeIsFirstNode function tests
	$SuccessNodeList = "$env:computername,test1,test2"
	if(CurrentNodeIsFirstNode -NodeList $SuccessNodeList) {
		Write-Host "$env:computername is first in the list of $SuccessNodeList"
	} else {
		Write-Host "Failed to detect $env:computername is first in the list of $SuccessNodeList"
	}
	
	$FailNodeList = "test1,$env:computername,test2"
	if(CurrentNodeIsFirstNode -NodeList $FailNodeList) {
		Write-Host "Failed: $env:computername is not first in the list of $FailNodeList"
	} else {
		Write-Host "Correctly detected $env:computername is not first in the list of $FailNodeList"
	}
	
	$EmptyNodeList = ""
	if(CurrentNodeIsFirstNode -NodeList $FailNodeList) {
		Write-Host "Failed: $env:computername is not first in an empty list"
	} else {
		Write-Host "Correctly detected $env:computername is not first in an empty list"
	}
#endregion

	Get-EventLog -LogName Application -After $StartTime | Sort-Object TimeGenerated | Format-Table -AutoSize -Wrap
}
#endregion