cls
$FileList = Get-ChildItem "DSC*.ps1"
$ProcdConfigsArray = @()
$MOFPath = pwd
foreach($File in $FileList){
	. $File.FullName
	
	# Get a list of Configuration names from the DSC Script
	$TargetConfig = @((((Get-Content $File.FullName) | Select-String "^Configuration ") -split " ")[1])
	
	foreach($ConfigName in $TargetConfig){
		#Add the name to the array if it isn't there already
		if($ProcdConfigsArray -contains $ConfigName){
			$retcode = 1
			continue
		} else {
			$ProcdConfigsArray += $ConfigName
		}
	
		#Determine what the output folder name is going to be
		$TargetMOF = Join-Path $MOFPath $ConfigName
	
		if((Test-Path $TargetMOF)) {
			remove-item $TargetMOF -Force -Recurse -Confirm:$False
		} 

		$pswdSecure = ConvertTo-SecureString -String "boost-PrkiT" -AsPlainText -Force
		$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "BRIDGEPOINT\svc_dsc_ro",$pswdSecure
		$result = & $ConfigName -ConfigurationData $ConfigurationData -Credential $cred
	}
}
foreach($ConfigName in $TargetConfig){
	Start-DscConfiguration -Wait -Force -Verbose -Path ./$ConfigName
}