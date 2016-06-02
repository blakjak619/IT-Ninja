Function ConfigureService ([string]$ServiceName, [string]$ServiceStartMode, [string]$ServiceAccount, [String]$ServicePassword) {

$Usage = @"
#-------------------------------------------------------------------------
# Solution: ConfigureService
# Author: Sly Stewart
# Updated: 1/24/2013
# Version: 1.2
<#
# Description:
- Configures a service Startup Mode, and optionally Service Logon User 
Mandatory Parameters:
	[String]-ServiceName: Name of the service to configure
	[String]-ServiceStartMode: Automatic | Manual | Disabled
	
Optional Parameters:
	[String]-ServiceAccount: `"DOMAIN\User`" account to be used as the logon type.
	[String]-ServicePassword <string> to indicate the password for supplied ServiceAccount

# Revision History
# Version 1.0 - Initial Commit
# Version 1.1 - Changed the username/password combo to be passed to the function instead of prompting. -SS 1/24/2013
# Version 1.2 - Made changes to error handling when starting a configured service back up. Thanks Todd Plu. -SS 4/26/2013 
# Version 1.2 - Made changes to add service account rights to logon as a service before configuring service -ToddP 10/10/2013
#-------------------------------------------------------------------------

"@

	LLTraceMsg -InvocationInfo $MyInvocation
	
	if ((!$ServiceName) -or (!$ServiceStartMode)) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ConfigureService"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
	}
	
	$AcceptableParams = @("Automatic", "Manual", "Disabled", "Delayed-Auto")
	if ($AcceptableParams -notcontains $ServiceStartMode) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ConfigureService (ServiceStartMode)"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
	}
	if ($ServiceAccount) {
		if (!$ServicePassword) {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ConfigureService (ServicePassword)"
			}
			Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
			throw "You need to supply -ServiceAccount <string> AND -ServicePassword <string>"
		}
	}
		Stop-Service -Name $ServiceName -Force | Out-Null
		if($ServiceStartMode.ToLower() -eq "delayed-auto"){
			$cmd = "sc.exe config $ServiceName start= $ServiceStartMode"
			$quiet = Invoke-Expression -Command $cmd
		} else {
			Set-Service -Name $ServiceName -StartupType $StartMode | Out-Null
		}
		if ($ServiceAccount -ne "") {
            # set logon right first
            AddAccountPolicy -account "$ServiceAccount" -right "SeServiceLogonRight"
			$WMISVC = gwmi Win32_service | ? {$_.name -eq "$ServiceName" }
			$WMISVC.Change($null,$null,$null,$null,$null,$null,$ServiceUser,$ServicePassword,$null,$null,$null) | Out-Null
		}
		if ($StartMode.ToLower() -eq "automatic" -or $StartMode.ToLower() -eq "delayed-auto") {
			try {
				Start-Service $ServiceName -ErrorAction Stop
				Write-Host "Started `'$ServiceName`' successfully!"
			} catch [Exception] {
				Write-Host "FAILURE:: Unable to start service `'$ServiceName`'. $_"
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: Unable to start service `'$ServiceName`'. $_"
				}
			}
		}

}

# executes service operations 
Function ServiceOps ([string]$ServiceName, [string]$ServiceOp) {
	LLTraceMsg -InvocationInfo $MyInvocation
    ## Validation
    if ((!$ServiceName) -or (!$ServiceOp)) {
	    Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	    if ($LoggingCheck) {
		    ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to ServiceOps"
	    }
	    throw
    }

    ## Logic
    # build command
    $cmdArgs =  "-Name $ServiceName"
    switch($ServiceOp) {
		"Stop" { $cmd = 'Stop-Service -Force' }
		"Start"  { $cmd = 'Start-Service' }
        "Restart"  { $cmd = 'Restart-Service -Force' }
		Default { if ($LoggingCheck) {ToLog -LogFile $LFName -EventID 3 -Text "FAILURE:: [ServiceOps] Operation for service ($ServiceName) was not Stop, Start or Restart, it was `'$ServiceOp`'" } 
                throw
                }
    } # end switch
    # execute command
    try {
        Write-Warning "INFO:: [ServiceOps] Performing $ServiceOp on $ServiceName"
        if ($LoggingCheck) { ToLog -LogFile $LFName -Text "INFO:: [ServiceOps] Performing $ServiceOp on $ServiceName" }
        $results = (Invoke-Expression "$cmd $cmdArgs -ErrorAction stop") 2>&1         
    } catch { 
        Write-Error "FAILURE:: [ServiceOps] Could not perform $ServiceOp on $ServiceName. Error: $results"
        if ($LoggingCheck) { ToLog -LogFile $LFName -Text "FAILURE:: [ServiceOps] Could not perform $ServiceOp on $ServiceName. Error: $results"}
        throw
    }


}

function ProcessServiceConfig {
param ( [System.Xml.XmlElement]$Service )
	LLTraceMsg -InvocationInfo $MyInvocation
	$SName = $Service.Name
	$StartMode = $Service.StartMode
	$UseServiceUser = $Service.User
	if ($UseServiceUser -eq "True") {
		$ServiceUser = $Service.Auth.User
		$ServicePW = $Service.Auth.Password
		if ($ServiceUser -ne "%_USER_%") {
			if ($ServicePW -ne "%_PASSWORD_%") {
				ConfigureService -ServiceName $SName -ServiceStartMode $StartMode -ServiceAccount $ServiceUser -ServicePassword $ServicePW
			} else {
				#They are using the default password. managing service without changing users
				ConfigureService -ServiceName $SName -ServiceStartMode $StartMode
				Write-Host "Service `'$SName`' was managed, but manual username and password intervention is required to configure! (Password missing)" -ForegroundColor Red -BackgroundColor White
			}
		} else {
			#They are using the default username. managing service without changing users
			ConfigureService -ServiceName $SName -ServiceStartMode $StartMode
			Write-Host "Service `'$SName`' was managed, but manual username and password intervention is required to configure! (User missing)" -ForegroundColor Red -BackgroundColor White
		}
	} else {
		ConfigureService -ServiceName $SName -ServiceStartMode $StartMode
	}
}
function CreateService{
param(
	[Parameter(Mandatory=$true)][string]$ServiceName,
	[ValidateSet("own","share","interact","kernel","filesys","rec")][string]$ServiceType,
	[ValidateSet("boot","system","auto","demand","disabled","delayed-auto")][string]$StartupType,
	[ValidateSet("normal","severe","critical","ignore")][string]$ErrorHandling,
	[Parameter(Mandatory=$true)][string]$BinPath,
	[string]$LoadOrderGroup,
	[ValidateSet("yes","no")][string]$Tag,
	[string]$Dependencies,
	[string]$Account,
	[string]$DisplayName,
	[string]$Password
)

	LLTraceMsg -InvocationInfo $MyInvocation
	
	if( $ServiceName.Length -lt 1){
		LLToLog -EventID $LLERROR -Text "The service name was empty for CreateService."
		return $false
	}		
	if( Get-Service $ServiceName -ErrorAction SilentlyContinue ){
		LLToLog -EventID $LLINFO -Text "Service $ServiceName already exists. No action taken."
		return $false
	}
	
	$CmdString = "sc.exe create $ServiceName "
	
	if($ServiceType){
		$CmdString += "type= $ServiceType "
	}
	
	if($StartupType){
		$CmdString += "start= $StartupType "
	}
	
	if($ErrorHandling){
		$CmdString += "error= $ErrorHandling "
	}
	
	$CmdString += "binPath= $BinPath "
	
	if($LoadOrderGroup){
		$CmdString += "group= $LoadOrderGroup "
	}
	
	if($Tag){
		$CmdString += "tag= $Tag "
	}
	
	if($Dependencies){
		$CmdString += "depend= $Dependencies "
	}
	
	if($Account){
		$CmdString += "obj= $Account "
	}
	
	if($DisplayName){
		$CmdString += "DisplayName= $DisplayName "
	}
	
	if($Password){
		if($Password -match "@LOOKUPPWD*") {
			$AcctRegex = [regex]'@LOOKUPPWD\((.+)\)'
			$Account = [regex]::match($Password,$AcctRegex).Groups[1].Value
			$Password = LSGet-AccountPwd -Account $Account 
        }
		$CmdString += "password= $Password "
	}
	
	try{
		$Result = Invoke-Expression $CmdString
        if($Result -like "*FAIL*"){
            LLToLog -EventID $LLERROR -Text "Failed to create service $ServiceName; reason: $Result"
            return $false
        } else {
		    return $true
        }
	} catch {
		LLToLog -EventID $LLERROR -Text "Failed to create service $ServiceName; reason: $_.Exception"
		return $false
	}
}
function DeleteService{
param( [Parameter(Mandatory=$true)][string]$ServiceName )

	LLTraceMsg -InvocationInfo $MyInvocation
	
	if( Get-Service $ServiceName -ErrorAction SilentlyContinue ){
		LLToLog -EventID $LLINFO -Text "Service $ServiceName already exists. No action taken."
		return $false
	}

	$CmdString = "sc.exe Delete $ServiceName"
	
	try{
		$Result = Invoke-Expression $CmdString
        if($Result -like "*FAIL*"){
            LLToLog -EventID $LLERROR -Text "Failed to delete service $ServiceName; reason: $Result"
            return $false
        } else {
		    return $true
        }
	} catch {
		LLToLog -EventID $LLERROR -Text "Failed to delete service $ServiceName; reason: $_.Exception"
		return $false
	}
}
#region Unit Tests
if (($MyInvocation.Line -eq $null) -or ($MyInvocation.Line -notmatch "\. ")) {
	$LIBPATH = $env:ScriptLibraryPath
	if(-not $LIBPATH) {
		$DefaultPath = "\\10.13.0.206\scratch\DML\Scripts"
		Write-Host "No '$env:ScriptLibraryPath' environment variable found. Defaulting to $DefaultPath"
		$LIBPATH = $DefaultPath
	}
	. $LIBPATH\Includes\LIB-Logging.ps1

	LLInitializeLogging -LogLevel $LLTRACE
	
	#Test(s) for CreateService -------------------------------------------------------------------------
	$StartTime = Get-Date
    $CreateStatus = CreateService -ServiceName "TestService" -BinPath "C:\Windows\System32\Notepad.exe" -StartupType disabled
	Get-EventLog -After $StartTime -LogName Application
	# End GetCredential Tests --------------------------------------------------------------------------

	#Test(s) for DeleteService -------------------------------------------------------------------------
	$StartTime = Get-Date
    if($CreateStatus){
	    $DeleteStatus = DeleteService -ServiceName "TestService"
    }
	Get-EventLog -After $StartTime -LogName Application
	# End GetCredential Tests --------------------------------------------------------------------------
}
#endregion