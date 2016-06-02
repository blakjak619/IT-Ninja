function ProcessSiteAction {
param( [System.Xml.XmlElement]$Site )

	switch($Site.Action){
		"Add"{
			$SiteName = $Site.SiteName
			try  {
				if (!(Test-Path "IIS:\Sites\$SiteName")) {
					$SitePhysPath = $Site.PhysPath
					$SiteFullPath = join-path $WWWROOT $SitePhysPath
					$SiteAppPool = $Site.AppPool
					$SSL_Check = $Site.SSL
					if ($SSL_Check -eq "True") {
					
						$SiteCertName = $Site.SSLCERTName
						$SiteCertObj = gci "Cert:\LocalMachine\My\" | ? {$_.Subject -like "*$SiteCertName*" }
						$SiteSSLIP = $Site.SSLIP
						$SiteSSLPort = $Site.SSLPort
						
						CreateWebSite -Name $SiteName -PhysicalPath $SiteFullPath -ApplicationPool $SiteAppPool -SSL $true -SSL_Cert $SiteCertObj -SSL_IP $SiteSSLIP -SSL_Port $SiteSSLPort | Out-File -Append $LLLogFilePath -encoding ASCII
					} else {
						CreateWebSite -Name $SiteName -PhysicalPath $SiteFullPath -ApplicationPool $SiteAppPool -SSL $false | Out-File -Append $LLLogFilePath -encoding ASCII
					}
				}
				LLToLog -EventID $LLINFO -Text "Created website $SiteName"
			} catch [Exception] {
				LLToLog -EventID $LLERROR -Text "FAILURE:: Unable to create `'$SiteName`'"
			}
			#Do the bindings...
			$Bindings = $Site.Binding
			foreach ($Binding in $Bindings) {
			$BAction = $Binding.action
			
			#Set up the Binding Hash
			$BiType = $Binding.type
			$BiAddress = $Binding.address
			$BiPort = $Binding.port
			$BiHostN = $Binding.hostname
			$BindInfo = $Binding.BindingInfo
			
			$BindingHash = @{}
			if ($BiType -like "http*") {
				$BindHash = @{"Type"="$BiType";"IPAddress"="$BiAddress";"Port"="$BiPort";"HostName"="$BiHostN";"BindingInfo"=""}
			} else {
				$BindHash = @{"Type"="$BiType";"IPAddress"="$BiAddress";"Port"="$BiPort";"HostName"="$BiHostN";"BindingInfo"="$BindInfo"}
			}
				if ($BAction -eq "Delete") {
					ManageWSBinding -WSName "$SiteName" -WSBindings $BindHash -Remove
				} elseif ($BAction -eq "Add") {
					ManageWSBinding -WSName "$SiteName" -WSBindings $BindHash
				}
			}
		}
		"Delete"{
			LLToLog -EventID $LLTRACE -Text "Deleting Website $($Site.SiteName)"
			$SiteName = $Site.SiteName
			try {
				if (Test-Path "IIS:\Sites\$SiteName") {
					Remove-Website $SiteName
					if ($LoggingCheck) {
						LLToLog -EventID $LLINFO -Text "Successfully removed IIS Site `'$SiteName`'."
					}
				}
			} catch [Exception] {
				if ($LoggingCheck) {
					LLToLog -EventID $LLERROR -Text "FAILURE:: error removing IIS Site `'$SiteName`'. $_"
				}
			}
		}
	}
}
function ProcessWWWROOT {
param( [System.Xml.XmlElement]$FStructure )
	foreach ($Dir in $FStructure) {
		$CPath = Join-Path $WWWROOT $Dir.InnerText
		if (!(Test-Path $CPath)) {
			New-Item -ItemType Directory -Path "$CPath" | Out-Null
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Creating folder structure `'$CPath`'"
			}
		}
	}
}
function ProcessAppPoolDelete{
param([System.Xml.XmlElement]$Pool)
	$PoolName = $Pool.NAME
	try {
		if (Test-Path "IIS:\AppPools\$PoolName") {
			Remove-WebAppPool $PoolName
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Successfully removed `'$PoolName`' App Pool."
			}
		}
	} catch [Exception] {
		Write-Host "Unable to Delete `'$PoolName`'!" -ForegroundColor Red -BackgroundColor White
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: There was an issue removing `'$PoolName`' App Pool. $_"
		}
	}
}
function ProcessAppPoolAdd{
param([System.Xml.XmlElement]$Pool)
	$PoolName = $Pool.NAME
	$NETver = $Pool.NETVer
	$IdenType = $Pool.IDType
	$Enable32Bit = "False"   # By default, all pools should be 64bit
	if ($Pool.Enable32Bit) { $Enable32Bit = $Pool.Enable32Bit }

	if ($IdenType -eq "SpecificUser") {
		$PoolUser = $Pool.Auth.User
		$PoolPW = $Pool.Auth.Password
		#Checking for default username and password combo.
		if ($PoolUser -ne "%_USER_%") {
			if ($PoolPW -ne "%_PASSWORD_%") {
				CreateAppPool -PoolName $PoolName -NetVer $NETver -IdentityType $IdenType -Enable32Bit $Enable32Bit -Username $PoolUser -Password $PoolPW
			} else {
			Write-Host "Pool `'$PoolName`' was created, but manual username and password intervention is required to configure! (Password missing)" -ForegroundColor Red -BackgroundColor White
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "WARNING:: Pool `'$PoolName`' was created, but the password was set to default, and not used."
			}
			CreateAppPool -PoolName $PoolName -NetVer $NETver -IdentityType $IdenType -Enable32Bit $Enable32Bit
		}
		} else {
			Write-Host "Pool `'$PoolName`' was created, but manual username and password intervention is required to configure! (Username missing)" -ForegroundColor Red -BackgroundColor White
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "WARNING:: Pool `'$PoolName`' was created, but the username was set to default, and not used."
			}
			CreateAppPool -PoolName $PoolName -NetVer $NETver -IdentityType $IdenType -Enable32Bit $Enable32Bit
		}
	} else {
		CreateAppPool -PoolName $PoolName -NetVer $NETver -IdentityType $IdenType -Enable32Bit $Enable32Bit
	}
}
function GetIISParentSite {
param ($IIS_Path)
$Usage = @"
	Input an IIS Path ("IIS:\Sites\default Web Site\Virtual Directory")
	returns an object with an IIS Path's Name, Parent Site and Application. Mostly used for removing nested IIS items.
"@
	if (Get-Module -Name "WebAdministration") {
		if (Test-Path $IIS_Path) {
			$Property = Get-ItemProperty -Path $IIS_Path
			$SParentPath = ($Property.PSParentPath).Split("\")
			$ParentSite = $SParentPath[$SParentPath.Length - 1]
			$Self = $Property.Name
			
			$ParentDef = New-Object PSObject
			$ParentDef | Add-Member -MemberType NoteProperty -Name "Name" -Value $Self
			if ($ParentSite -eq "Sites") {
				#This is the ParentSite
				$ParentDef | Add-Member -MemberType NoteProperty -Name "Parent" -Value $null
			} else {
				$index = [array]::IndexOf($SParentPath, "Sites")
				if ($index -gt -1) {
					$Parent = $SParentPath[$index + 1]
					$ParentDef | Add-Member -MemberType NoteProperty -Name "Parent" -Value $Parent
					$Path_WON = $IIS_Path.Replace($Self, "")
					$Path_WON = $Path_WON.TrimEnd("\")
					$WON = $Path_WON.Split("\")
					$RevEnd = $index + 1
					$Position = ($WON.Length - 1)
					
					$WhatsLeft = $Path_WON.Replace("IIS:\Sites\$Parent\", "")
					$TryDirectMatch = Dir -Recurse "IIS:\Sites" | ? {$_.Name -eq "$WhatsLeft"}
					if ($TryDirectMatch) {
						$TDM_Type = $TryDirectMatch.NodeType
						if ($TDM_Type -eq "application") {
							$ParentDef | Add-Member -MemberType NoteProperty -Name "Application" -Value $WhatsLeft
						} else {
							$ParentDef | Add-Member -MemberType NoteProperty -Name "Application" -Value $null
						}
					}
				}
			}
		return $ParentDef
		}
	}
}