Function AddMSFeatures {
Param(
	[Parameter()] [string[]] $FeatureList,
	[Parameter()] [switch] $IncludeAllSub
)
	Import-Module ServerManager
	
	if ($FeatureList) {
		$ValidatedFeatureList = @()
		$LogFeatures = ""
		$winf = Get-WindowsFeature
		foreach ($AddFeature in $FeatureList) {
			If($winf | Where-Object {$_.Name -eq $AddFeature}) {
				$ValidatedFeatureList += $AddFeature
				$LogFeatures = $LogFeatures + $AddFeature + ", "
			} else {
				ToLog -LogFile $LFName -Text "$AddFeature is not a valid feature on this OS (also check spelling)"
			}
		}
		##########################################################################
		# Clean up and report on accepted features
		$LogFeatures = $LogFeatures.TrimEnd(", ")
		if ($LoggingCheck) {
			If($IncludeAllSub) {
				ToLog -LogFile $LFName -Text "Installing $LogFeatures with all SubFeatures "
			} else {
				ToLog -LogFile $LFName -Text "Installing individual features: $LogFeatures"
			}
		}
		$LogFeatures = $null
		
		If($IncludeAllSub){
			Add-WindowsFeature $ValidatedFeatureList -includeAllSubFeature
		} else {
			Add-WindowsFeature $ValidatedFeatureList
		}
	}
	$winf = $null
	$ValidatedFeatureList = $null
	
	Remove-Module ServerManager
}