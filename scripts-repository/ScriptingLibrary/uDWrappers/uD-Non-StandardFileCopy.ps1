param(
	[string]$SourceSiteName,
	[string]$DestSiteName
)
Import-Module ServerManager
Import-Module WebAdministration

$SrcBinPath = $(get-item iis:\sites\$SourceSiteName\).physicalPath
$SrcBinPath = $SrcBinPath+"\bin"
$DestBinPath = $(get-item iis:\sites\$DestSiteName\).physicalPath
Write-Output "Copy files from: `"$SrcBinPath`" to: `"$DestBinPath`""
Copy-Item -path "$SrcBinPath" -Destination "$DestBinPath" -recurse -ErrorAction "Stop" -Force -Verbose

$split = $SourceSiteName -split "\\"

[string]$subSite = $split[1]

Write-Output "Remove the sub-site from IIS but leave the files"
Remove-WebApplication -Name $subSite -Site $DestSiteName -ErrorAction "Stop" -Verbose; exit $LASTEXITCODE