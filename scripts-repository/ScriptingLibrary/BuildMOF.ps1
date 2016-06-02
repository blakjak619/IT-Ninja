param(
    [string]$DSCPath = "d:\DSCAutoGen",
    [string]$MOFPath = "\\10.13.0.206\scratch\DML\Microsoft\Powershell\MOF"
)

$script:LocalScriptFolder = "c:\scripts\BridgepointScriptingLibrary"
. $script:LocalScriptFolder\Includes\LIB-Logging.ps1

$ELName = "BPI"
$ELSource = "DSCMOF"
$BinLogLevel = $LLCUSTOM
$retcode = 0
$errors = $null

LLInitializeLogging -EventLogName $ELName -EventLogSource $ELSource -LogFileNameSeed "MOFBuild" -LogLevel $BinLogLevel 

#Keep track of configuration names to avoid overwriting duplicates
$ProcdConfigsArray = @()

#One-time creation of the svc_dsc_ro credential
$pswdSecure = ConvertTo-SecureString -String "boost-PrkiT" -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "BRIDGEPOINT\svc_dsc_ro",$pswdSecure

if(-not (Test-Path $DSCPath)){
    LLToLog -EventID 12121 -Text "Path $DSCPath not found."
    exit 1
}

foreach($DSCScript in Get-Childitem -Path $DSCPath -Filter "*.ps1"){

    # Get a list of Configuration names from the DSC Script
    $TargetConfig = @((((Get-Content $DSCScript) | Select-String "^Configuration ") -split " ")[1])

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
        if((Test-Path $TargetMOF) -and ((("$TargetMOF\localhost.mof").LastWriteTime -lt $DSCScript.LastWriteTime))) {$Build = $true} #Folder exists, but MOF is older; so build it

        if($Build){
            #delete it so we get a guaranteed fresh output (folder and file date/time update)
            if(Test-Path $TargetMOF){
                remove-item $TargetMOF -Force -Recurse -Confirm:$False
            }

            #In the folder where the DSCScript exists
            cd $DSCPath

            #Validate the script
            $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $DSCScript),[ref]$errors)
            if($errors.Count -gt 0){
                LLToLog -EventID 13231 -Text "The sourcing of $DSCScript failed with $errors."
				$retcode = 1
            } else {
                . .\$DSCScript
            }

            #Execute the Configuration
            try{
                $result = & $ConfigName -ConfigurationData $ConfigurationData -Credential $cred
                LLToLog -EventID 10001 -Text "The compilation of $DSCScript succeeded."
            } catch {
                LLToLog -EventID 13231 -Text "The compilation of $DSCScript failed with $_.Exception.Message."
				$retcode = 1
                continue
            }

			#Move the MOF file to the desired location
            if(Test-Path $ConfigName){
                Copy-Item -Path $ConfigName -Destination $MOFPath  -Force -Recurse
            } else {
                LLToLog -EventID 10501 -Text "No path for $ConfigName to copy when compiling $DSCScript"
				$retcode = 1
            }
        } 
    }
}
exit $retcode