

ipmo servermanager
$Features = @( "Web-Webserver", "Web-Mgmt-Tools", "NET-Framework")
$Error_List = @()
foreach ($Feature in $Features) {
	$Feat_Pres = (get-windowsFeature $Feature).Installed
	if (!($Feat_Pres)) {
		$Error_List += $Feature
	}
}

if ((($Error_List).Count) -gt 0) {
	foreach ($Ecount in $Error_List) {
		Write-Host "Feature `'$ECount`' missing!!" -ForegroundColor Red
	}
} else {
	Write-Host "Windows Features good" -ForegroundColor Green
}

Ipmo WebAdministration
#Physical Structure
$PhysLayout = @("C:\WWWROOT", "C:\WWWROOT\Site_A", "C:\WWWROOT\Site_B")
$Error_List = @()
foreach ($Phys in $PhysLayout) {
	if (!(Test-Path $Phys)) {
		$Error_List += "$Phys"
	}	
}
if ((($Error_List).Count) -gt 0) {
	foreach ($Ecount in $Error_List) {
		Write-Host "Physical Path `'$ECount`' missing!!" -ForegroundColor Red
	}
} else {
	Write-Host "Physical Paths good" -ForegroundColor Green
}

$Error_List = @()
#Windows Firewall
$FWStates = netsh advfirewall show allprofiles | Select-String "State"
foreach ($ln in $FWStates) {
	[String]$Line = $ln
	$Split = $Line.Split(" ")
	$Last = $Split[-1]
	if ($Last -ne "OFF") {
		$Error_List += 1
	}
}

if (($Error_List).Count -gt 0) {
	Write-Host "Windows fireall not off!!" -ForegroundColor Red	
} else {
	Write-Host "Windows Firewall configured properly." -ForegroundColor Green
}

$Error_List = @()
$Websites = @("Site_A", "Site_B")
foreach ($webs in $Websites) {
	$WSCheck = Get-Website | ? {$_.Name -eq "$Webs" }
	if (!$WSCheck) {
		$Error_List += "$Webs"
	}
}

if (($Error_List).Count -gt 0) {
	foreach ($item in $Error_List) {
		Write-Host "Website `'$Item`' is not present!!" -ForegroundColor Red
	}	
} else {
	Write-Host "Websites configured properly." -ForegroundColor Green
}

$Error_List = @()
foreach ($webs in $Websites) {
	$WSCheck = Dir "IIS:\AppPools" | ? {$_.Name -eq "$Webs" }
	if (!$WSCheck) {
		$Error_List += "$Webs"
	}
}

if (($Error_List).Count -gt 0) {
	foreach ($item in $Error_List) {
		Write-Host "AppPool `'$Item`' is not present!!" -ForegroundColor Red
	}	
} else {
	Write-Host "AppPools are present." -ForegroundColor Green
}

 
 
#App Pools
$Error_Count = 0
$SiteA_AP = Get-Item "IIS:\AppPools\Site_A"
if (($SiteA_AP.processModel.identityType) -ne "SpecificUser") {
	$Error_Count++
	Write-Host "Site_A identityType set incorrectly." -ForegroundColor Red
}

$SiteB_AP = Get-Item "IIS:\AppPools\Site_B"
if (($SiteB_AP.processModel.identityType) -ne "NetworkService") {
	$Error_Count++
	Write-Host "Site_B identityType set incorrectly." -ForegroundColor Red
}

if ($Error_Count -gt 0) {
		Write-Host "AppPools are not configured properly!" -ForegroundColor Red
} else {
	Write-Host "AppPools are configured properly." -ForegroundColor Green
}

#Websites
if (get-website | ? {$_.name -eq "Default Web Site"}) {
	Write-Host "Default website not removed!" -ForegroundColor Red
} else {
	Write-Host "Default website is not present. good." -ForegroundColor Green
}

if (!(dir "IIS:\SSLBindings" | ? {($_.Port -eq 443) -and ($_.Sites -eq "Site_B")} )) {
	Write-Host "SSL Bindings not set!" -ForegroundColor Red
} else {
	Write-Host "SSL Bindings set properly." -ForegroundColor Green
}

if (!((get-website | ? {$_.name -eq "Site_B"}).Bindings).Collection | ? {$_.protocol -eq "net.pipe"}) {
	Write-Host "Bindings not set for Site_B!" -ForegroundColor Red
} else {
	Write-Host "Bindings set properly." -ForegroundColor Green
}

$Error_Count = 0
$TC = 0
#WebApps
$WebApps = @("WebApp1", "WebApp2")
foreach ($WebApp in $WebApps) {
	$WAP = get-webApplication -Name $WebApp
	if ($WAP) {
		if ($WebApp -eq "WebApp1") {
			$XPath = $WAP.ItemXPath | Select-String "`@name`=`'Site_A"
			if (!($XPath)) {
				$Error_Count++
			}
			if (($WAP.ApplicationPool) -ne "Site_B") {
				$Error_Count++
			}
			if (($WAP.PhysicalPath) -ne "C:\WWWROOT\Site_A\WebApp1") {
				$Error_Count++
			}
			if ($Error_Count -gt 0) {
				Write-Host "$WebApp is configured incorectly!" -ForegroundColor Red
				$TC = $TC + $Error_Count
				$Error_Count = 0
			}
		} elseif ($WebApp -eq "WebApp2") {
			$XPath = $WAP.ItemXPath | Select-String "`@name`=`'Site_B"
			if (!($XPath)) {
				$Error_Count++
			}
			if (($WAP.ApplicationPool) -ne "Site_A") {
				$Error_Count++
			}
			if (($WAP.PhysicalPath) -ne "C:\WebApp2") {
				$Error_Count++
			}
			if ($Error_Count -gt 0) {
				Write-Host "$WebApp is configured incorectly!" -ForegroundColor Red
				$TC = $TC + $Error_Count
				$Error_Count = 0
			}
		}
	} else {
	
	}
}
if ($TC -gt 0) {
	Write-Host "The webapps test has failed!!" -ForegroundColor Red
} else {
	Write-Host "Webapps are configured correctly." -ForegroundColor green
}