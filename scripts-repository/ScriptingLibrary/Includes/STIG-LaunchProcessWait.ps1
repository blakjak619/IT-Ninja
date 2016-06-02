function ScrubPasswords {
param(
	[string]$DirtyText
)
    # match any case of password="" (or PWD="")
	$PwdArgRegex=[regex]'(([Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|PWD)=)("[^"]+")'
	$PwdArgRegex.replace($DirtyText,'$1********')
}
function LaunchProcessAndWait {
	param([String]$Destination, `
	[String]$FileName, `
	[String]$CommandLineArgs, 
	[String]$UserDomain, `
	[String]$UserName, `
	[System.Security.SecureString]$Password,
    [Switch]$DisableShellExecute,
    [Int]$Timeout,
    [Int]$Retries,
    [Int]$RetrySleep,
    [Switch]$NoClobber)
$Usage = @"
#-------------------------------------------------------------------------
# Solution: LaunchProcessAndWait
# Last Updated By: Todd Pluciennik
# Updated: 6/10/2014
# Version: 3.1
<#
# Description: Launch an .exe or .msi process and wait for completion. Returns the process Exit Code.

- Mandatory Parameters
	[String]-Destination: Parent Path of the binary/msi to run.
	[String]-FileName: Binary Name
- Optional Parameters
	[String]-CommandLineArgs: Any Command line arguments you need to pass.
	[String]-UserDomain: Domain name to run the process as.
	[String]-UserName: UserName to run the process as.
	[System.Security.SecureString]-Password: SecureString Password for the above named user.
    [Switch]-DisableShellExecute: Sets UseShellExecute to "false", default is "true" (used only for .exe install)
    [Int]-Timeout: timeout to wait for process to complete (optional)
    [Int]-Retries: Number of retries before giving up (optional, defaults to one attempt)
    [Int]-RetrySleep: Sleep time before retrying (optional, defaults to one second); only works with Retries
    [Switch]-NoClobber: Explicitly wait for other same-named processes to exit prior to continuing
#
# Usage:
# - LaunchProcessAndWait -Destination "C:\Temp" -FileName "SDChargersAreTheBest.msi" -CommandLineArgs " /q /package `'C:\Temp\SDChargersAreTheBest.msi`'"
#	## Launch 'C:\Temp\SDChargersAreTheBest.msi`' with the arguments " /q /package `'C:\Temp\SDChargersAreTheBest.msi`'"

# - LaunchProcessAndWait -Destination "D:\My Binary Directory is\Here" -FileName "Padres.exe" -CommandLineArgs "/q /norestart"
#	## Launch 'D:\My Binary Directory is\Here\Padres.exe' with the arguments "/q /norestart" (and hope it doesnt fall apart mid-season).
#
# - LaunchProcessAndWait -Destination "D:\My Binary Directory is\Here" -FileName "Padres.exe" -CommandLineArgs "/q /norestart" -UserDomain "DomainB" -UserName "SvcAcct" -Password [System.Security.SecureString]
	## Launch 'D:\My Binary Directory is\Here\Padres.exe' with the arguments "/q /norestart" as the user "DomainB\SvcAcct" and specified password.
#>
# Revision History
# Version 1.0 - Initial Commit
# Version 1.5 - Updated content, and usage. 12/05/2012
# Version 2.0 - Made this safe for Powershell 3.0 usage. Pretty much a rewrite. SS- 7/31/2013
# Version 2.1 - grab output from EXEs (if DisableShellExecute set)
# version 2.2 - add timeout and retries
# Version 3.1 - add NoClobber switch to check for running procs 
#-------------------------------------------------------------------------

"@	
	#LLTraceMsg -InvocationInfo $MyInvocation

	if ($PSBoundParameters.Count -eq 0) {
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
	}

	$ErrorActionPreference="Stop"
	$FullPath = Join-Path $Destination $FileName
	if (!(Test-Path $FullPath)) {
		throw "Execution file (`'$FullPath`') does not exist!"
	}
	$Extension = (gi $FullPath).Extension

	if (!(($Extension -eq ".msi") -or ($Extension -eq ".msu") -or ($Extension -eq ".exe"))) {
		throw "`'$FileName`' is an unsupported file."
	}

	if (($UserName) -and (!$Password)) {
		throw "Password must be specified when a username is given"
	}

	$WorkingDir = $PWD
	$CleanCMDArgs = ScrubPasswords -DirtyText $CommandLineArgs
	Write-Host "Starting process $FileName with these arguments `'$CleanCMDArgs`' ..."
	$env:SEE_MASK_NOZONECHECKS = 1
	$Process = New-Object System.Diagnostics.Process
	$Process.StartInfo.WorkingDirectory = $WorkingDir
	if ($CommandLineArgs) {
		$Process.StartInfo.Arguments = $CommandLineArgs
	}
	if ($UserName) {
		$Process.StartInfo.UseShellExecute = $false
		$Process.StartInfo.UserName = $UserName
		$Process.StartInfo.Domain = $UserDomain
		$Process.StartInfo.Password = $Password
	}


	switch -Wildcard ($Extension) {
		".exe" {
			$Process.StartInfo.FileName = $FullPath
			if ($DisableShellExecute) { 
				$Process.StartInfo.UseShellExecute = $false 
				$Process.StartInfo.RedirectStandardOutput = $true
				$Process.StartInfo.RedirectStandardError = $true
			}
		}

		".msi" {
			$Process.StartInfo.FileName = "msiexec.exe"
			if ($DisableShellExecute) { 
				$Process.StartInfo.UseShellExecute = $false 
				$Process.StartInfo.RedirectStandardOutput = $true
				$Process.StartInfo.RedirectStandardError = $true
			}
		}

		".msu" {
			$Process.StartInfo.FileName= "wusa.exe"
			$Process.StartInfo.UseShellExecute = $false 
		}
	}
    
   
    if (!$Retries) { $Retries = 0 }
    $currentRetry = 1;
    $success = $false;
        do { 
        ## add NoClobber
        # first revision - no "timeout" (so there is a chance for deadlock / dining philosophers)
        if ($NoClobber) {
            $ProcName = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
            $TestProc = Get-Process $ProcName -ErrorAction SilentlyContinue
            if ($TestProc) { Write-Host "Process found ($ProcName), waiting until complete"}
            while ($TestProc) {
                write-host -NoNewline "."
                $TestProc = Get-Process $ProcName -ErrorAction SilentlyContinue
                sleep 1
            }
        } # end NoClobber
        $Quiet = $Process.Start()
        if ($Timeout) { $Process.WaitForExit($Timeout) } else { $Process.WaitForExit() } 
        if ($DisableShellExecute) { [string] $Out = $Process.StandardOutput.ReadToEnd(); [string] $OutErr = $Process.StandardError.ReadToEnd(); }
        $PExitCode = $Process.ExitCode
        $env:SEE_MASK_NOZONECHECKS = 0
        switch ($PExitCode)
        { 
            0    { $logtxt = "`'$FullPath $CleanCMDArgs`' completed successfully." ; $success = $true }
            3010 { $logtxt = "`'$FullPath $CleanCMDArgs`' completed successfully. Changes will not be effective until the system is rebooted." ; $success = $true } 
            4123 { $logtxt = "`'$FullPath $CleanCMDArgs`' is installed as part of OS. Separate install was aborted." ; $success = $true  }
            default { # any other return is a failure
                if ($currentRetry -gt $Retries) {
                    Write-Host "FAILED:: `'$CleanCMDArgss`' had a failure. Exit Code: $PExitCode"
                    if ($DisableShellExecute) { Write-Host "FAILED:: (stdout) $Out`nFAILED:: (stderr) $OutErr" }
                    if ($LoggingCheck) {
                        ToLog -LogFile $LFName -Text "FAILED:: `'$FullPath $CleanCMDArgs`' had a failure. Exit Code: $PExitCode"
                        if ($DisableShellExecute) { ToLog -LogFile $LFName -Text "FAILED:: (stdout) $Out  (stderr) $OutErr" }
                        }
                    throw
                } else {
                    if (!$RetrySleep) { $RetrySleep = 1} 
                    Write-Host ".. Failed. Attempt $currentRetry of $Retries. Retrying after $RetrySleep seconds ...  "
                    Start-Sleep $RetrySleep
                }
                $currentRetry = $currentRetry + 1  
            } # end default
        } # end switch


    } while (!$success) 
    
    # log results from above
    if ($DisableShellExecute) { $logtxt = "$logtxt`nOutput:`n$Out" }
    if ($LoggingCheck) { ToLog -LogFile $LFName -Text $logtxt }  else { write-host $logtxt }

}
<# 
.SYNOPSIS
	Invoke-ExeFile sets up the command line to execute the LaunchProcessAndWait function.  
.DESCRIPTION
	Used as a launch platform for simple .exe/.msi files that don't need any additional processing (Action=Execute).
.NOTES  
	Author        : Dan Meier  
	Assumptions   :

	Assumes these variables are defined (by calling script):
	$INFO
	$LoggingCheck
	$LFName
	$TempFldrPath
	$PakPath
.OUTPUTS
    Returns a 0 for success; 1 for failure. Writes to the console any failure messages, logs to a log file other informational messages.
#>
Function Invoke-ExeFile {
Param(
[Parameter()] [System.Xml.XmlElement]$XMLNode
)
	if ($LoggingCheck) {
		ToLog -LogFile $LFName -EventID $INFO -Text "$($XMLNode.Name) is requested to install."
	}
	$CArgs = $XMLNode.Argument
	$BinName = $XMLNode.Name
	if ($CArgs) {
		$CLA = ""
		foreach ($argu in $CArgs) {
			$CoA = $argu
			if ($CoA -eq "/Package %:PACKAGELOCALPATH%") {
				$PakPath = Join-Path $TempFldrPath $BinName
				$CoA = $CoA.Replace("/Package %:PACKAGELOCALPATH%", "/Package `'$PakPath`'")
			}
			$CLA += $CoA + " "
		}
		$CLA = $CLA.TrimEnd(" ")
	}
	LaunchProcessAndWait -Destination $TempFldrPath -FileName $BinName -CommandLineArgs $CLA
}
<# 
.SYNOPSIS
	Invoke-MsuFile sets up the command line to execute the LaunchProcessAndWait function.  
.DESCRIPTION
	Used as a launch platform for simple .msu files that don't need any additional processing (Action=Execute).
.NOTES  
	Author        : Dan Meier  
	Assumptions   :

	Assumes these variables are defined (by calling script):
	$INFO
	$LoggingCheck
	$LFName
	$TempFldrPath
	$PakPath
.OUTPUTS
    Returns a 0 for success; 1 for failure. Writes to the console any failure messages, logs to a log file other informational messages.
#>
Function Invoke-MsuFile {
Param(
[Parameter()] [System.Xml.XmlElement]$XMLNode
)
	Write-Host "$($XMLNode.Name) install started"
	if ($LoggingCheck) {
		ToLog -LogFile $LFName -EventID $INFO -Text "$($XMLNode.Name) is requested to install."
	}
	$CArgs = $XMLNode.Argument
	$BinName = $XMLNode.Name
	if ($CArgs) {
		$CLA = ""
		foreach ($argu in $CArgs) {
			$CoA = $argu
			if ($CoA -eq "/Package %:PACKAGELOCALPATH%") {
				$PakPath = Join-Path $TempFldrPath $BinName
				$CoA = $CoA.Replace("/Package %:PACKAGELOCALPATH%", "/Package `'$PakPath`'")
			}
			$CLA += $CoA + " "
		}
		$CLA = $CLA.TrimEnd(" ")
	}
    $PakPath = Join-Path $TempFldrPath $BinName
	try {
		start -wait $PakPath -argumentlist $CLA
		if ($LoggingCheck) {ToLog -LogFile $LFName -EventID $INFO -Text "$($XMLNode.Name) installed." }
	} catch {
		if ($LoggingCheck) {ToLog -LogFile $LFName -EventID $INFO -Text "$($XMLNode.Name) failed to install." }
	}
	Write-Host "$($XMLNode.Name) install completed"
}
<# 
.SYNOPSIS
	ProcessLauncher takes a BinDependency XML element and prepares it for LaunchProcessAndWait
.DESCRIPTION
	This function takes an XML element from BinDependency, extracts the attributes and setups a call to LaunchProcessAndWait.
	The expected attributes are:
	<File Name="" Action="Execute" PathFromBinRoot="" [ProductIsInstalled="powershell script block text"] [Persist=true] >
	  <Argument></Argument>
	</File>
.NOTES  
	Author        : Dan Meier  
	Assumptions   :

	Assumes these variables are defined (by calling script):
	$LoggingCheck
	$LFName
	$TempFldrPath
	$PakPath
.OUTPUTS
    Returns a 0 for success; 1 for failure. Writes to the console any failure messages, logs to a log file other informational messages.
#>
Function ProcessLauncher {
param(
	[Parameter()] [System.Xml.XmlElement]$FileSpec
)
	$BinName = $FileSpec.Name
	if ($LoggingCheck) { ToLog -LogFile $LFName -Text "$BinName is requested to install." }

	# Creates a scriptblock from the ProductIsInstalled attribute of the <File> XML element. Note that if the string contains a $_ the $ must be escaped with a back tick.
	if($FileSpec.ProductIsInstalled) {
		$TestScriptBlock = [ScriptBlock]::Create($FileSpec.ProductIsInstalled)
		$result = $TestScriptBlock.Invoke()
	} else {
		# Unless of course a ProductIsInstalled attribute isn't provide, then install no matter what.
		$result = $false
	}

	$ReqRetryMax = $FileSpec.RetryMax
	if($ReqRetryMax) {
		$Retrymax = $ReqRetryMax -As [int]
		if(-not ($Retrymax.GetType().Name -like "Int*")) {
			$Retrymax = 0
		}
	} else {
		$Retrymax = 0
	}

    if($FileSpec.DisableShellExecute) {
        $DisableShellExecute = $true
    }
	if (!($result)) {  #Safe to install
		if ($LoggingCheck) { ToLog -LogFile $LFName -Text "$BinName was not found to be installed, and will install."}

		$CArgs = $FileSpec.Argument
			
		if ($CArgs) {
			$CLA = ""
			foreach ($argu in $CArgs) {
				$CoA = $argu
				if ($CoA -like "*%:PACKAGELOCALPATH%") {
					$PakPath = Join-Path $TempFldrPath $BinName
					$CoA = $CoA.Replace("%:PACKAGELOCALPATH%", "`"$PakPath`"")
				}
				$CLA += $CoA + " "
			}
			$CLA = $CLA.TrimEnd(" ")
		}
        $ParamHash = @{}
        $ParamHash.Add("-Destination","$TempFldrPath")
        $ParamHash.Add("-FileName","$BinName")
        $ParamHash.Add("-CommandLineArgs","$CLA")
        if($DisableShellExecute) { $ParamHash.Add("-DisableShellExecute",$true) }

		$RetryCnt = 0

		#Default status/message when app is already installed
		$status = 2
        $errmsg = "$BinName is already installed, skipping install."

		while (-not ($result) -and $RetryCnt -le $Retrymax) {
			LaunchProcessAndWait @ParamHash

			$RetryCnt++
			#Perform install validation
			if($TestScriptBlock ) {
				$result = $TestScriptBlock.Invoke()
				if($result) {
					$errmsg = "$BinName install was successful, passed the ProductIsInstalled test."
					$status = 2
				} else {
					$errmsg = "$BinName install was not successful, failed the ProductIsInstalled test. Retrying $RetryCnt of $Retrymax attempts."
					Write-Host $errmsg
					$status = 3
				}
			} else {
				# Unless of course a ProductIsInstalled attribute isn't provide, then just assume the install went well.
				$result = $true
				$errmsg = "$BinName install was apparently successful. There was no ProductIsInstalled test to verify installation."
				$status = 2
			}
		}
		
		if ($LoggingCheck) { ToLog -LogFile $LFName -EventID $status -Text $errmsg }
	} else {
		# Unless of course a ProductIsInstalled attribute isn't provide, then install no matter what.
		$result = $false
	}
}