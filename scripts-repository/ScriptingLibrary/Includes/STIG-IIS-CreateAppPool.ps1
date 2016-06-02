function CreateAppPool {
	#http://www.iis.net/configreference/system.applicationhost/applicationpools/add/processmodel
	#Process Model Settings for an Application Pool <processModel>
	
param(
[string]$PoolName,
[string]$NETVer,
[string]$IdentityType,
[String]$Username,
[String]$Password,
[String]$ManagedPipelineMode,
[string]$LogonType,
[String]$Enable32Bit = "False",
[int]$TimeOutMinutes = 0
)
#region Usage
$Usage = @"
#-------------------------------------------------------------------------
# Solution: CreateAppPool
# Author: Sly Stewart
# Updated: 4/3/2013
# Version: 1.5
<#
# Description:
- Creates an IIS App Pool
- Mandatory Parameters:
	[String]-PoolName: Name of the AppPool to create
	[String]-NETVer: .NET Version. "v2.0" | "v4.0"
	[String]-IdentityType: Configures the App Pool to run as:
			"ApplicationPoolIdentity" | "LocalService" | "LocalSystem" | "NetworkService" | "SpecificUser"
    [String]-Enable32Bit: Enable 32 bit application (enable32BitAppOnWin64) "True" | "False" 
## Notes about using -IdentityType "SpecificUser":
	If this parameter and value are used, you must also include the parameters:
		[String]-Username "DOMAIN\UserName" to indicate which user account to run under.
		[String]-Password <string> to indicate the password for supplied username
	
- Optional Parameters:
	[String]-ManagedPipelineMode: Configures ASP.NET to run in Classic Mode or Integrated Mode:
			"Integrated" | "Classic"
	[String]-LogonType: Specifies the logon type for the process identity
			"LogonBatch" | "LogonService"

# Dependencies:
	IIS
	AppCmd.exe (Part of the IIS install) in the default location of "C:\Windows\System32\inetsrv\appcmd.exe"
#
# Usage:
# - CreateAppPool -PoolName "AppPool0" -NetVer "v4.0" -IdentityType "SpecificUser" -Enable32Bit "False" -AppUser "ServiceDomain\ServiceUser"
	#Create an AppPool named "AppPool0" with the following properties:
		* .NET 4.0
		* Running as Active Directory user "ServiceDomain\ServiceUser"
		
# - CreateAppPool -PoolName "AppPool1" -NetVer "v2.0" -IdentityType "ApplicationPoolIdentity" -Enable32Bit "True"
	#Create an AppPool named "AppPool1" with the following properties:
		* .NET 2.0
		* Running as "ApplicationPoolIdentity"
        * Enable 32bit Applications

#>
# Revision History
# Version 1.0 - Initial Commit 
# Version 1.01 - Added provision to exit quietly if the AppPool already exists. -SS
# Version 1.2 - Changed the username/password combo to be passed to the function instead of prompting. -SS
# Version 1.3 - Allow the specific user to be prompted for a password, if -Password "Prompt" is used.
# Version 1.4 - Adjusted to allow an update to an existing App Pool -SS 4/3/2013
# Version 1.5 - Enable 32 bit application (enable32BitAppOnWin64)  -tpluciennik 5/5/2014
#-------------------------------------------------------------------------

"@
#endregion
	$NVAr = @("v2.0", "v4.0")
	$ITAr = @("ApplicationPoolIdentity", "LocalService", "LocalSystem", "NetworkService", "SpecificUser")
	$LTAr = @("LogonBatch", "LogonService")
	$MPLAr = @("Integrated", "Classic")
    $E32bitAr = @("True","False")
	
	if ($PSBoundParameters.Count -eq 0) {
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		if ($LoggingCheck) {
			LLToLog -EventID $LLERROR  -Text "FAILURE:: No parameters were passed to CreateAppPool"
		}
		throw
	}

	if (!$PoolName -or !$IdentityType) {
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		if ($LoggingCheck) {
			LLToLog -EventID $LLERROR  -Text "FAILURE:: Required parameters were not passed to CreateAppPool"
		}
		throw
	}
	# Mandatory params check
	if ($NVAr -notcontains $NETVer) {
		#Mandatory value not passed
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		if ($LoggingCheck) {
			LLToLog -EventID $LLERROR  -Text "FAILURE:: Required parameters (.NETVersion) was not passed to CreateAppPool"
		}
		throw
	}
	
	if ($ITAr -notcontains $IdentityType) {
		#Mandatory value not passed
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		if ($LoggingCheck) {
			LLToLog -EventID $LLERROR  -Text "FAILURE:: Required parameters (IdentityType) was not passed to CreateAppPool"
		}
		throw
	}
	# Optional params check
	if ($LogonType) {
		if ($LTAr -notcontains $LogonType) {
			#Mandatory value not passed
			Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
			if ($LoggingCheck) {
				LLToLog -EventID $LLERROR  -Text "FAILURE:: Optional parameters (LoginType) was not correctly passed to CreateAppPool: $LogonType"
			}
			throw
		}
	}
	if ($ManagedPipelineMode) {
		if ($MPLAr -notcontains $ManagedPipelineMode) {
			#Mandatory value not passed
			Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
			if ($LoggingCheck) {
				LLToLog -EventID $LLERROR  -Text "FAILURE:: Optional parameters (ManagedPipelineMode) was not correctly passed to CreateAppPool: $ManagedPipelineMode"
			}
			throw
		}
	}
    if ($Enable32Bit) {
		if ($E32bitAr -notcontains $Enable32Bit) {
			#Mandatory value not passed
			Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
			if ($LoggingCheck) {
				LLToLog -EventID $LLERROR  -Text "FAILURE:: Optional parameters (Enable32Bit) was not correctly passed to CreateAppPool: $Enable32Bit"
			}
			throw
		}
	}
	
	switch ($IdentityType) {
		"ApplicationPoolIdentity" {$IntIDT = 4}
		"LocalService" {$IntIDT = 1}
		"LocalSystem" {$IntIDT = 0}
		"NetworkService" {$IntIDT = 2}
		"SpecificUser" {$IntIDT = 3}
		Default {$IntIDT = 4}
	}
	if ($IntIDT -eq 3) {
		if ((!$Username) -or (!$Password)) {
			Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
			if ($LoggingCheck) {
				LLToLog -EventID $LLERROR  -Text "FAILURE:: Optional parameters (IdentityType) was not correctly passed to CreateAppPool: If `"SpecificUser`" is used, You must specify -username AND -password"
			}
			throw "If `"SpecificUser`" is used, You must specify -username AND -password"
		}
	}
	if ($LogonType) {
		switch ($LogonType) {
			"LogonBatch" {$IntLT = 0 }
			"LogonService" {$IntLT = 1 }
		}
	}
	$AppPoolNew = $true
	if (Test-Path "IIS:\AppPools\$PoolName") {
		if ($LoggingCheck) {
			LLToLog -EventID $LLINFO  -Text "AppPool `'$PoolName`' already exits. Assuming we are updating an existing app pool."
		}
		$AppPoolNew = $false
	}
	
		try {
			if ($AppPoolNew) {
				new-WebAppPool $PoolName -force | Out-Null
			}
			$AppPool = Get-Item "IIS:\AppPools\$PoolName"
			if ($IntIDT -eq 3) {
				#We will need to switch this back to 3 when we get ready to pass the credentials.
				$AppPool.processModel.identityType = 4
			} else {
				$AppPool.processModel.identityType = $IntIDT
			}
			$AppPool.ManagedRuntimeVersion = $NETVer
			 
			if ($LogonType) {
				$AppPool.processModel.logonType = $IntLT
			}
			if ($ManagedPipelineMode) {
				$AppPool.managedPipelineMode = $ManagedPipelineMode
			}
			if($Enable32Bit -eq "True"){
				LLToLog -EventID $LLWARN -Text "32-bit processing enabled for app pool $PoolName in contravention of Windows Engineering Technical Advisory IIS"
			}
			$AppPool.enable32BitAppOnWin64 = $Enable32Bit

			$AppPool.processModel.idleTimeout = [TimeSpan]::FromMinutes($TimeOutMinutes)
			Set-ItemProperty ("IIS:\AppPools\"+$PoolName) -Name processModel.idleTimeout $AppPool.processModel.idleTimeout

			$AppPool | Set-Item
            
           if ($LoggingCheck) {
				LLToLog -EventID $LLINFO  -Text "AppPool `'$PoolName`' created/updated successfully."
			}

		} catch [Exception] {
			write-host "Unable to create/update `'$PoolName`'. `n`n $_" -ForegroundColor Red -BackgroundColor White
			if ($LoggingCheck) {
				LLToLog -EventID $LLERROR  -Text "FAILURE:: Unable to create/update App Pool `'$PoolName`'. $_"
			}
			#ToLog -LogFile $LogFile -LogText "Unable to create $PoolName. `n $_"
			Throw
		}
		if (($IntIDT -eq 3) -and (($Username) -and ($Password))) {
				#If we are set to a Specific user.
<#
I WILL HAVE TO USE APPCMD.EXE TO INPUT THE PASSWORD, OTHERWISE THE PASSWORD IS STORED IN CLEAR TEXT.
http://www.iis.net/learn/get-started/getting-started-with-iis/getting-started-with-appcmdexe
C:\Windows\System32\inetsrv\appcmd.exe

# AppCmd.exe also does not accept encrypted System.Management.Automation.PSCredential
# So the user will have to manually punch in the password

				#$AppPool.processModel.UserName = $AppUser
				#$AppPool.processModel.Password = $AppSecPass
#>
				if ($LoggingCheck) {
					LLToLog -EventID $LLTRACE  -Text "Setting `'$PoolName`' specific user."
				}
				try {
					if (Test-Path "C:\Windows\System32\inetsrv\appcmd.exe") {

						
						#If Requested, Prompt the user for the password.
						if ($Password -eq "Prompt") {
							if ($LoggingCheck) {
								LLToLog -EventID $LLINFO -Text "Prompting user for `'$UserName`' Password..."
							}
							$AppCreds = read-host "What is the correct IIS App Pool password for `"$Username`" ?" -AsSecureString
							$Credentials = New-Object System.Management.Automation.PSCredential -ArgumentList $Username, $AppCreds
							$PP = $Credentials.GetNetworkCredential().Password
							Invoke-Expression "C:\Windows\System32\inetsrv\appcmd.exe set APPPOOL `"$PoolName`" /processModel.identityType:SpecificUser` /processModel.userName:`"$Username`" /processModel.password:`"$PP`""
						} else {
							Invoke-Expression "C:\Windows\System32\inetsrv\appcmd.exe set APPPOOL `"$PoolName`" /processModel.identityType:SpecificUser` /processModel.userName:`"$Username`" /processModel.password:`"$Password`""
						}
					} else {
						#APPCMD is not in the default location. This is a problem.
						write-host "appcmd was not found in `"C:\Windows\System32\inetsrv\`". Unable to set $PoolName U/P combo!" `
						-ForegroundColor Red -BackgroundColor White
						if ($LoggingCheck) {
							LLToLog -EventID $LLERROR  -Text "FAILURE:: appcmd was not found in `"C:\Windows\System32\inetsrv\`". Unable to set $PoolName U/P combo! Exiting." 
						}
						Throw
					}
					if ($LoggingCheck) {
						LLToLog -EventID $LLINFO  -Text "Set `'$PoolName`' specific user successfully."
					}
				} catch [Exception] {
					Write-Host "Unable to set `'$PoolName`' User/Pass combo! `n`n $_" -ForegroundColor Red -BackgroundColor White
					if ($LoggingCheck) {
						LLToLog -EventID $LLERROR  -Text "Unable to set `'$PoolName`' User/Pass combo! `n $_"
					}
					Throw
				}
				
				
			} else {
				if ($IntIDT -eq 3) {
					#The user did not put in all the correct information. Alert them and exit.
					Write-Host "Input the -username <string> -password <string> when using `"SpecificUser`" for app pools." -ForegroundColor Red -BackgroundColor White
					if ($LoggingCheck) {
						LLToLog -EventID $LLWARNING  -Text "Input the -username <string> -password <string> when using `"SpecificUser`" for app pools."
					}
					Throw
				}
			}
    #region Start it up!
    $AppPool = Get-Item "IIS:\AppPools\$PoolName"
    if ($AppPool.state -match "Stop") {
        $AppPool.Start()
        if ($LoggingCheck) {
				LLToLog -EventID $LLINFO -Text "AppPool `'$PoolName`' Starting."
			}
        $maxtime = 60
        $poolTimer = 0
        while ($AppPool.state -ne "Started" ) {
           sleep 1
           if ($poolTimer -eq $maxtime ) {
            Write-Host "Unable to Start `'$PoolName`' after $maxtime seconds" -ForegroundColor Red -BackgroundColor White
			if ($LoggingCheck) {
				LLToLog -EventID $LLERROR  -Text "Unable to start `'$PoolName`' after $maxtime seconds"
			}
			Throw

            }
        $poolTimer ++
        }
    } 
    #endregion starting pool

}


#region Unit Tests
if (($MyInvocation.Line -eq $null) -or ($MyInvocation.Line -notmatch "\. ")) {

	$LIBPATH = $env:ScriptLibraryPath
	. $LIBPATH\Includes\LIB-Includes.ps1 -DefaultLibraryPath $LIBPATH -Intentional
	LLInitializeLogging -LogLevel $LLTRACE
	
	#Test TimeOutMinutes
    $StartTime = Get-Date
	# First, is IIS even installed?
	try{
		Import-Module ServerManager -ErrorAction Stop
	} catch {
		Write-Host "Cannot test CreateAppPool because ServerManager is not installed." -ForegroundColor Yellow -BackgroundColor Black
		return $false
	}
	if( -not (Get-WindowsFeature | Where-Object {$_.Name -eq "Web-Server"}).InstallState -eq "Installed"){
		Write-Host "Cannot test CreateAppPool because Web-Server (IIS) is not installed." -ForegroundColor Yellow -BackgroundColor Black
		return $false
	}
	
	CreateAppPool -PoolName "TOSTestPool" -NETVer "v4.0" -IdentityType "ApplicationPoolIdentity" -Enable32Bit "True"
	
	$SetTimeOutValue = Get-ItemProperty ("IIS:\AppPools\TOSTestPool") -Name processModel.idleTimeout.value
	if($SetTimeOutValue -ne 0){
		Write-Host "TOSTestPool idleTimeout was $SetTimeOutValue instead of 0." -ForegroundColor Red -BackgroundColor Yellow
	} else {
		Write-Host "TOSTestPool idleTimeout was $SetTimeOutValue expected 0." -ForegroundColor Green -BackgroundColor White
	}
	Remove-Item IIS:\AppPools\TOSTestPool -Recurse
	
	CreateAppPool -PoolName "TOSTestPool" -NETVer "v4.0" -IdentityType "ApplicationPoolIdentity" -Enable32Bit "True" -TimeOutMinutes 1800
	
	$SetTimeOutValue = Get-ItemProperty ("IIS:\AppPools\TOSTestPool") -Name processModel.idleTimeout.value
	if($SetTimeOutValue -ne 20){
		Write-Host "TOSTestPool idleTimeout was $SetTimeOutValue instead of 20." -ForegroundColor Red -BackgroundColor Yellow
	} else {
		Write-Host "TOSTestPool idleTimeout was $SetTimeOutValue expected 20." -ForegroundColor Green -BackgroundColor White
	}
	Remove-Item IIS:\AppPools\TOSTestPool -Recurse
	
    Get-EventLog -LogName Application -After $StartTime | Sort-Object TimeGenerated | Format-Table -AutoSize -Wrap
}
#endregion
