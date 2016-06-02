[CmdletBinding()]
param (
    [Parameter()] [string]$XMLFile,
    [Parameter()] [string]$TokenFile,
	[Parameter()] [switch]$Test,
	[Parameter()] [switch]$NonInteractive
)
$pswdSecure = ConvertTo-SecureString -String "boost-PrkiT" -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "BRIDGEPOINT\svc_dsc_ro",$pswdSecure

#


New-PSDrive Src -PSProvider FileSystem -Root \\bpe-aesd-cifs.bridgepoint.local\scratch\DML\Scripts -Credential $cred

$script:DMLSource = "\\10.13.0.206\scratch\DML\Scripts"
$script:INISource = "\\10.13.0.206\scratch\DML\Scripts\INIFiles"
$script:LocalScriptFolder = "c:\scripts\BridgepointScriptingLibrary"
$script:TempFolder = 

$StartTime = Get-Date 
New-Item  $script:LocalScriptFolder -ItemType Directory -Force | Out-Null

Write-Verbose "Copying source files locally"
Robocopy $script:DMLSource $script:LocalScriptFolder *.* /E /Z /NP /MT /R:1
$TempFolder = Join-Path $script:LocalScriptFolder "tmp"
New-Item -type Directory -Path $TempFolder -Force | Out-Null
Robocopy $script:INISource $TempFolder *.* /E /Z /NP /MT /R:1

Write-Verbose "Sourcing Library"
	$IncludesF = join-path "$script:LocalScriptFolder" "/includes"
	. $IncludesF\LIB-Includes.ps1 -DefaultLibraryPath $script:LocalScriptFolder -Intentional

LLInitializeLogging -LogLevel $LLTRACE
		
if($XMLFile -AND $TokenFile){
	ReplaceTokens -XMLFile $XMLFile -TokenFile $TokenFile
}

if(-not $XMLFile){
	LLToLog -EventID $LLWARN -Text "An XMLFile must be specified."
} else {
	if(-not $Test) {
		$CmdLine = "cd $script:LocalScriptFolder; .\STIG-ServerStandup.ps1 -XMLFile $XMLFile"
		$tpwd = LSGet-AccountPwd -Account "svc_ServerStandup" -PasswordFolder "OpsBrain\API Access"
		$uDeployPwd = ConvertTo-SecureString -String $tpwd -AsPlainText -Force
		$uDeployCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "BRIDGEPOINT\svc_ServerStandup",$uDeployPwd
		LLToLog -EventID $LLINFO -Text "Starting command: $CmdLine"
		cd $script:LocalScriptFolder
		.\STIG-ServerStandup.ps1 -XMLFile $XMLFile -Logfile $LLLogFilePath
		LLToLog -EventID $LLINFO -Text "Returned from STIG-ServerStandup."
	}
}

if (-not ((gwmi win32_process | ? { $_.processname -eq "powershell.exe" }).commandline -match "-NonInteractive")) {
	if( -not $NonInteractive) {
		Get-EventLog -LogName Application -After $StartTime | Out-GridView 
	}
}

LLToLog -EventID $LLSuccess -Text "Exiting the script with status 0"
exit 0