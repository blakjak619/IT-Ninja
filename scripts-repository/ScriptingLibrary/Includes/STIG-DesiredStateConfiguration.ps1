Function Process-DSC {
param( [System.Xml.XMLElement]$DSC) 
 $MOF = $DSC.MOF
        $DSCPath = $DSC.Path
        if(Test-Path($DSCPath)){
            LLToLog -Text "Compiling MOF from $DSCPath"
            $MOF = CompileMOF -DSCPath $DSCPath
        }
        LLToLog -Text "Starting Desired State Configuration ($MOF)."
    	Start-DSC -PathToMOF $MOF
}
<# 
.SYNOPSIS
	Start-DSC is a wrapper to Desired State Configuration Start-DscConfiguration
.DESCRIPTION
	Start-DSC takes a path to the MOF (Management Object Format) file previously created via DSC
    And copies/executes locally
.NOTES  
	Author        : Todd Pluciennik
	Assumptions   :
		Permissions to the path of the MOF file to read and copy locally; make temp directory
.OUTPUTS
    Returns a 0 for success; 1 for failure. Writes to the console any failure messages, logs to a log file other informational messages.
#>
function Start-DSC {
param(
	[parameter(Mandatory=$true)]$PathToMOF
	
)

	LLTraceMsg -InvocationInfo $MyInvocation

    if ($LoggingCheck) {
	    ToLog -LogFile $LFName -EventID $LLINFO -Text "StartDSC"
    }

    # test path
    if (!(Test-Path $PathToMOF)) { 
    $errmsg = "FAILURE:: Start-DSC Could not find supplied MOF ($PathToMOF)"
		if ($LoggingCheck) {ToLog -LogFile $LFName -EventID $FAILURE -Text $errmsg }

    }

    # create temp dir and copy mof
    # copy MOF to a temporary path to read from (since the supplied MOF file may be a network share)
    try {
        $TempMOFpath = [system.guid]::newguid().tostring()
        $TempMOFPathname = (new-item -type directory -name $TempMOFpath).FullName
        Copy-Item -Path $PathToMOF\* -Destination $TempMOFpath -Recurse
    } catch [Exception] {
        if ($LoggingCheck) {
                $errmsg = "FAILURE:: Start-DSC Could not copy source MOF ($PathToMOF) to temp dir ($TempMOFpath). Exception: $_"
				ToLog -LogFile $LFName -EventID $FAILURE -Text $errmsg
                }
		        write-host $errmsg
        
        return 1
        
    }


    # start-dsc
    try {            
			LLToLog -Text "Start-DscConfiguration -Path $TempMOFPathname -Verbose -Wait -Force"
			# Create a PowerShell Command 
			$pscmd = [PowerShell]::Create() 
			# Add a Script to change the verbose preference. 
			# Since I want to make sure this change stays around after I run the command I set UseLocalScope to $false. 
			# Also note that since AddScript returns the PowerShell command, I can simply call Invoke on what came back. 
			# I set the return value to $null to suppress any output 
			$null = $psCmd.AddScript({$VerbosePreference = “Continue”},$false).Invoke() 
			# If I added more commands, I’d be adding them to the pipeline, so I want to clear the pipeline 
			$psCmd.Commands.Clear() 
			# Now that I’ve cleared the pipeline, I’ll add another script that writes out 100 messages to the Verbose stream 
			$sbtext = "Start-DscConfiguration -Path $TempMOFpathname -Verbose -Wait -Force"
			$sb = [scriptblock]::Create($sbtext)
			$null = $psCmd.AddScript($sbtext).Invoke() 
			# Finally, I’ll output the stream 
			$psCmd.Streams.Verbose | Out-File -Append $LLLOGFILEPATH -encoding ASCII

			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Successfully executed DSC"
                $returnCode = 0
			}
		} catch [Exception] {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -EventID $FAILURE -Text "FAILURE:: Start-DSC failed. Exception: $_"
                }
		        write-host "FAILURE:: Start-DSC failed. Exception: $_"
                $returnCode = 1
	    }
    # cleanup
    Remove-Item $TempMOFpath -Force -Recurse
    return $returnCode

}
function CompileMOF {
param(
    [string]$DSCPath #Path and file to compile
)

	$MOFPath = "C:\Temp"

	#Keep track of configuration names to avoid overwriting duplicates
	$ProcdConfigsArray = @()

	#One-time creation of the svc_dsc_ro credential
	$pswdSecure = ConvertTo-SecureString -String "boost-PrkiT" -AsPlainText -Force
	$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "BRIDGEPOINT\svc_dsc_ro",$pswdSecure

	if(-not (Test-Path $DSCPath)){
		LLToLog -EventID 12121 -Text "Couldn't find the source file at $DSCPath."
		return
	}

	# Get a list of Configuration names from the DSC Script

	$TargetConfig = @((((Get-Content $DSCPath) | Select-String "^Configuration ") -split " ")[1])

	foreach($ConfigName in $TargetConfig){
		#Add the name to the array if it isn't there already
		if($ProcdConfigsArray -contains $ConfigName){
			LLToLog -EventID 11111 -Text "A duplicate configuration named $ConfigName was found during MOF building of $DSCScript."
			$retcode = 1
			continue
		} else {
			$ProcdConfigsArray += $ConfigName
		}

		#Determine what the output folder name is going to be
		$TargetMOF = Join-Path $MOFPath $ConfigName
			
		#Check to see if this DSC file is more recent than it's MOF
		$Build = $False
		if(-not (Test-Path $TargetMOF)) {$Build = $true} #Folder doesn't even exist; so build it
		if(-not (Test-Path $TargetMOF\localhost.mof)) {$Build = $true} #File doesn't even exist; so build it
		if((Test-Path $TargetMOF) -and ((("$TargetMOF\localhost.mof").LastWriteTime -lt $DSCScript.LastWriteTime))) {$Build = $true} #Folder exists, but MOF is older; so build it

		if($Build){
			$errors = $null

			#delete it so we get a guaranteed fresh output (folder and file date/time update)
			if(Test-Path $TargetMOF){
				remove-item $TargetMOF -Force -Recurse -Confirm:$False
			}

			#In the folder where the DSCScript exists
			cd $MOFPath

			#Validate the script
			$null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $DSCPath),[ref]$errors)
			if($errors.Count -gt 0){
				LLToLog -EventID 13231 -Text "The sourcing of $DSCPath failed with $errors."
			} else {
				. $DSCPath
			}

			#Execute the Configuration
			try{
				$result = & $ConfigName -ConfigurationData $ConfigurationData -Credential $cred
				#$result = & $ConfigName
				LLToLog -EventID 10001 -Text "The compilation of $DSCPath succeeded."
			} catch {
				LLToLog -EventID 13231 -Text "The compilation of $DSCPath failed with $_.Exception.Message."
				continue
			}

#			if(Test-Path $ConfigName){
#				Copy-Item -Path $ConfigName -Destination $MOFPath  -Force -Recurse
#			} else {
#				LLToLog -EventID 10501 -Text "No path for $ConfigName to copy when compiling $DSCScript"
#			}
		} 
	}
	if($retcode){
		return $retcode
	} else {
		return $TargetMOF
	}
}
#region Unit Tests
if (($MyInvocation.Line -eq $null) -or ($MyInvocation.Line -notmatch "\. ")) {
#  function to test xml, this is a conditional function
    function ParseFileXML {
    param (
	    [System.Xml.XmlElement]$FileNode
    )
	    $DSCMOF = $FileNode.MOF
        $DSCCrit = $FileNode.Critical

	    $ParamHash = @{}
	
	    if($DSCMOF){
		    $ParamHash.Add("-PathToMOF","$DSCMOF")
	    } else {
		    $errmsg = "No source specified for $FileNode"
		    LLToLog -EventID $LLWARN -Text $errmsg 
		    if($DSCCrit){
			    throw $errmsg
		    }
	    }
        
        $ParamHash
        $result = Start-DSC @ParamHash
     	
    }


	$LIBPATH = $env:ScriptLibraryPath
	if(-not $LIBPATH) {
		$DefaultPath = "\\10.13.0.206\scratch\DML\Scripts"
		Write-Host "No '$env:ScriptLibraryPath' environment variable found. Defaulting to $DefaultPath"
		$LIBPATH = $DefaultPath
	}
	. $LIBPATH\Includes\LIB-Logging.ps1

	LLInitializeLogging -LogLevel $LLTRACE

    #Test(s) -------------------------------------------------------------------------
    # Test method:
    # use the existing HelloWorldConfig MOF to create the "helloworld.txt" file
    # obtain the contents of that file, desired state: Hello World!
    # remove the created file
	$StartTime = Get-Date
    $desiredFile = "c:\temp\HelloWorld.txt"    # this needs to what file will be created
    [xml]$TestXML=@"
	<XMLRoot>
	<DSC MOF="\\10.13.0.206\scratch\DML\Microsoft\Powershell\MOF\HelloWorldConfig\localhost.mof" />
	</XMLRoot>
"@
	foreach($DSC in $TestXML.XMLRoot.DSC) {
		ParseFileXML -FileNode $DSC
        Start-Sleep -Seconds 2
	}
    Write-Host "Content of DSC created file: $desiredFile (this will be removed)"
    Get-Content $desiredFile
    Remove-Item $desiredFile -Force

    Get-EventLog -After $StartTime -LogName Application
	# End Tests --------------------------------------------------------------------------

}
#endregion