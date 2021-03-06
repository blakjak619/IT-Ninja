#region isElevate
function isElevated {
  $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
  return $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
#endregion
#region RunElevated
function RunElevated {
param(
	[ScriptBlock]$ScriptBlock
)
	LLTraceMsg -InvocationInfo $MyInvocation

	# Get the ID and security principal of the current user account
	$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
	$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
	 
	# Get the security principal for the Administrator role
	$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
	 
	# Check to see if we are currently running "as Administrator"
	if ($myWindowsPrincipal.IsInRole($adminRole))
	   {
	   # We are running "as Administrator" - so change the title and background color to indicate this
	   $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
	   $Host.UI.RawUI.BackgroundColor = "DarkBlue"
	   clear-host
	   }
	else
	   {
	   # We are not running "as Administrator" - so relaunch as administrator
	   
	   # Create a new process object that starts PowerShell
	   $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
	   
	   # Specify the current script path and name as a parameter
	   $newProcess.Arguments = $myInvocation.MyCommand.Definition;
	   
	   # Indicate that the process should be elevated
	   $newProcess.Verb = "runas";
	   
	   # Start the new process
	   [System.Diagnostics.Process]::Start($newProcess);
	   
	   # Exit from the current, unelevated, process
	   exit
	   }
	 
	# Run your code that needs to be elevated here
}
#endregion
#region LSGet-AccountPwd
function LSGet-AccountPwd {
param(
	[string]$Account,
	[string]$PasswordFolder
)
	LLTraceMsg -InvocationInfo $MyInvocation
	
	switch($PasswordFolder){
		"Non-Production\BPE Applications" {$PasswordAppURL = "https://pwds01t.bridgepoint.local/api/passwords/296?apikey=e43da895f3762bc736a93b84f2edc5ba&QueryAll&Format=XML"}
		"OpsBrain\API Access" {$PasswordAppURL = "https://pwds01t.bridgepoint.local/api/passwords/821?apikey=395f7be486dac28b2eadc957643fc6ad&QueryAll&Format=XML"}
		default {$PasswordAppURL = "https://pwds01t.bridgepoint.local/api/passwords/88?apikey=c92647dae5bf8352dafb489763ec75b4&QueryAll&Format=XML"}
	}
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}

    $wc = New-Object System.Net.WebClient

    [xml]$credxml =$wc.DownloadString($PasswordAppURL)
	$credrec = $credxml.ArrayOfPassword.Password | Where-Object {$_.UserName -eq $Account}
	if($credrec) {
		LLToLog -EventID $LLAUDIT -Text "User $env:username accessed credentials for $Account"
		return $credrec.Password
	} else {
		LLToLog -EventID $LLWARN -Text "User $env:username failed to access credentials for $Account"
		return $false
	}
	
	
}
#endregion
#region Unit Tests
if (($MyInvocation.Line -eq $null) -or ($MyInvocation.Line -notmatch "\. ")) {
	$LIBPATH = $env:ScriptLibraryPath
	if(-not $LIBPATH) {
		$DefaultPath = "C:\Scripts\BridgepointScriptingLibrary"
		Write-Host "No '$env:ScriptLibraryPath' environment variable found. Defaulting to $DefaultPath"
		$LIBPATH = $DefaultPath
	}
	. $LIBPATH\Includes\LIB-Logging.ps1

	LLInitializeLogging -LogLevel $LLTRACE
	
	#Test(s) for isElevated -------------------------------------------------------------------------
	$StartTime = Get-Date
	if(isElevated) {
		Write-Host "Script is running as administrator."
	} else {
		Write-Host "Script is running as non-administrator."
	} 
	Get-EventLog -After $StartTime -LogName Application
	# End GetCredential Tests --------------------------------------------------------------------------

	#Test(s) for GetCredential -------------------------------------------------------------------------
	$StartTime = Get-Date
	if((LSGet-AccountPwd -Account "LIB-Security") -eq "This is LIB-Security") {
		Write-Host "LSGet-AccountPwd Passed"
	} else {
		Write-Host "LSGet-AccountPwd Failed"
	}
	Get-EventLog -After $StartTime -LogName Application
	# End GetCredential Tests --------------------------------------------------------------------------
}
#endregion