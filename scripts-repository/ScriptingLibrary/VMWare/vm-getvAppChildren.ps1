param([String]$VCloud_Server, [String]$File, [String]$CSV, [String]$SearchString, [Switch]$Help)

$Usage = @"
"vm-getvAppChildren.ps1 -VCloud_Server <String> [-SearchString <*String*>]"
	*Search for vApps where the members of the vApp match -SearchString <*String*>. Output results to screen
	
"vm-getvAppChildren.ps1 -VCloud_Server <String> [-File <String>] [-SearchString <*String*>]"
	*Search for vApps where the members of the vApp match -SearchString <*String*>. Output results to -File <Path>
	
"vm-getvAppChildren.ps1 -VCloud_Server <String> [-CSV <String>] [-SearchString <*String*>]"
	*Search for vApps where the members of the vApp match -SearchString <*String*>. Output results to -CSV <Path>
"@

if ((!$VCloud_Server) -or (!$SearchString)) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	throw "Showing usage."
}
if ($PSBoundParameters.Count -eq 0) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	throw "Showing usage."
}
if ($Help) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	throw "Showing usage."
}

function CheckReqSnapIn ($SnapIN) {
	if (!(Get-PSSnapin -Name "$SnapIN" -ErrorAction SilentlyContinue))
		{
			if (Get-PSSnapin -Registered -Name $SnapIN -ErrorAction SilentlyContinue) {
				Add-PSSnapin $SnapIN
			} else {
				Throw "Required snapin is not present"
			}
		}
}

CheckReqSnapIn "VMware.VimAutomation.Core"
CheckReqSnapIn "VMware.VimAutomation.Cloud"

$Quiet = Connect-CIServer $VCloud_Server

$vApps = Get-CIVApp
$Targets = @()

foreach ($vApp in $vApps) {
	$vAppMembers = $vApp | Get-CIVM
	$hitCount = 0
	if ($vAppMembers) {
		if ($SearchString -ne "*") {
			foreach ($member in $vAppMembers) {
				$vmName = $member.Name
				if ($vmName -like "$SearchString") {
					$hitCount++
				}
			}
		} else {
			#Skip searching, its an "all" wildcard.
			$hitCount++
		}
		if ($hitCount -gt 0) {
			$App = New-Object -TypeName "PSObject"
			$aName = $vApp.Name
			$App | Add-Member -MemberType NoteProperty -Name "AppName" -Value $aName
			$ChildVMs = @()
			foreach ($child in $vAppMembers) {
				$ChildName = $child.Name
				$ChildVMs += $ChildName
			}
			$App | Add-Member -MemberType NoteProperty -Name "ChildVMs" -Value $ChildVMs
			$Targets += $App
		}
	}
}


if ($Targets) {
	if ((!$File) -and (!$CSV)) {
		foreach ($target in $Targets)
			{
				Write-Host $target.AppName
				foreach ($childObj in $($target.ChildVMs)) {
					Write-Host "`t$childObj"
				}
				Write-Host ""
			}
	} else {
		if ($File) {
			if (!(Test-Path $File)) {
				foreach ($target in $Targets)
				{
					Add-Content $File -Value $target.AppName
					foreach ($childObj in $($target.ChildVMs)) {
						Add-Content $File -Value "`t$childObj"
					}
					
				}
				Write-Host "Completed. file written @ `'$file`'."
			}
		}
		
		if ($CSV) {
			if (!(Test-Path $CSV)) {
				Add-Content $CSV -Value "AppName,ChildVM(s) -->"

				foreach ($TargetApp in $Targets) {
					$ChildString = ""
					foreach ($vmChild in ($TargetApp.ChildVMs)) {
						$ChildString = $ChildString + $vmChild + ","
					}
					$ChildString = $ChildString.trimEnd(",")
					$CSVLine = $TargetApp.AppName + "," + $ChildString
					Add-Content $CSV -Value $CSVLine
				}
				}
				
				Write-Host "Completed. file written @ `'$CSV`'."
			}
		}

} else {
	Write-Host "No vApps Found!"
}