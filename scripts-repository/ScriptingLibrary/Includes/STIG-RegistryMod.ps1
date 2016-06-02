Function RegistryMod {
param([String]$RegAction,
	[String]$ParentKey,
	[String]$KeyType,
	[String]$KeyName,
	$KeyValue)

$Usage = @"
#-------------------------------------------------------------------------
# Solution: RegistryMod
# Author: Sly Stewart 
# Updated: 12/17/2014
# Version: 1.1
<#
# Description: Create, Alter or Remove a registry key.

- Mandatory Parameters
	[String]-RegAction: Requires either `"Add`" (Create/Alter) or `"Delete`" (Remove) or `"New`" (Create New key)
	[String]-ParentKey: Name of the Parent Key. E.G.: "HKLM:\CurrentVersion\Microsoft"
	[String]-KeyName: Name of the SubKey to preform the RegAction on. e.g. PadresKey


- Optional Parameters
	[String]-KeyType: Type of key to add e.g. "String", "ExpandString", "Binary", "DWord", "MultiString", "QWord", "Unknown"
	-KeyValue: Value to store in they key. 


#
# Usage:
# - RegistryMod -RegAction "Delete" -ParentKey "HKLM:\Software\Bridgepoint" -KeyName "Raiders"
#	## Remove the RegistryKey "HKLM:\Software\Bridgepoint\Raiders". 


# - RegistryMod -RegAction "Add" -ParentKey "HKLM:\Software\Bridgepoint\GreatTeams" -KeyName "SDPadres" -KeyType "DWORD" -KeyValue 1
	## Create or modify the registry key "HKLM:\Software\Bridgepoint\GreatTeams\SDPadres" DWORD value 1
	
# - RegistryMod -RegAction "New" -ParentKey "HKML:\Software\Bridgepoint\SuperBowl" -KeyName "SDChargers"
	## Create key "HKLM:\Software\Bridgepoint\SuperBowl\SDChargers" 
	
# Revision History
# Version 1.0 - Initial Commit
# Version 1.1 - added "New" for creating new Keys (not just subkeys); tpluciennik
#-------------------------------------------------------------------------

"@


	if ($PSBoundParameters.Count -eq 0) {
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to RegistryMod"
		}
		throw
	}
	if ((!$RegAction) -or (!$ParentKey) -or (!$KeyName)) {
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to RegistryMod"
		}
		throw
	}
	if ($RegAction -eq "Add") {
		if ((!$KeyType) -or ($KeyValue -eq $null)) {
			Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to RegistryMod (KeyValue or KeyType missing)"
			}
			throw
		}
	}

	$AcceptableValues = @("Add", "Delete", "New")
	if ($AcceptableValues -notcontains $RegAction) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to RegistryMod (AcceptableValues is either `"Add`" , `"Delete`" ,`"New`" )"
		}
			Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
			throw
	}
		
	$FullKeyPath = Join-Path $ParentKey $KeyName
	switch ($RegAction) {
		"Add" {
			try {			
					if (test-path "$FullKeyPath") {
						$NonAuthKey = (Get-ItemProperty -Path $ParentKey -Name "$KeyName").$KeyName
						if ($NonAuthKey -ne $KeyValue) {
							Set-ItemProperty -Path "$ParentKey" -Name "$KeyName" -Value $KeyValue -type $KeyType -Force
						}
					} else {
						Set-ItemProperty -Path "$ParentKey" -Name "$KeyName" -Value $KeyValue -type $KeyType -Force
					}
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "Successfully added registry key for `'$KeyName`'"
					}
				} catch [Exception] {
					Write-Host "Unable to set RegistryKey for $FullKeyPath" -ForegroundColor Red -BackgroundColor White
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: Unable to set RegistryKey for `'$KeyName`'"
					}
				}
		}
		
		"Delete" {
			try {
                    # logic to switch on key or subkeys
                    if (test-path "$FullKeyPath") { # parent key
						Remove-Item -Path "$FullKeyPath" -Recurse -Force
                        if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "Successfully removed registry key for `'${FullKeyPath}`'"
						}
                    } elseif (Get-ItemProperty -Path "$ParentKey" -Name "$KeyName" ) { #subkey

                        Remove-ItemProperty -Path "$ParentKey" -Name "$KeyName" -Force 
                        if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "Successfully removed registry key for `'${FullKeyPath}`'"
						}
						
					} else {
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "FAILURE:: `'$FullKeyPath`' does not exist."
						}
					}
				} catch [Exception] {
					Write-Host "Unable to remove RegistryKey for $FullKeyPath" -ForegroundColor Red -BackgroundColor White
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: Unable to remove RegistryKey for `'$FullKeyPath`'"
					}
				}
		}

		"New" {
			try {
					if (test-path "$FullKeyPath") {
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "Nothing done, `'$FullKeyPath`' already exists. "
						}
					} else {
                        # do the needful
                        New-Item -Path  $ParentKey -Name $KeyName
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "Successfully added new registry key `"$KeyName`" in `"$ParentKey`""
						}
					}
				} catch [Exception] {
					Write-Host "Unable to add new RegistryKey for $FullKeyPath" -ForegroundColor Red -BackgroundColor White
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: Unable to add new RegistryKey for `'$FullKeyPath`'"
					}
				}
                # verify the new key was created
                if (!(test-path "$FullKeyPath")) {
                    Write-Host "Unable to add new RegistryKey for $FullKeyPath" -ForegroundColor Red -BackgroundColor White
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: Unable to add new RegistryKey for `'$FullKeyPath`'"
					}
                }
    
		} # end New
		Default {
			Write-Host "RegAction parameter requires either `"Add`" , `"Delete`" or `"New`" as a value." -ForegroundColor Red -BackgroundColor White
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: RegAction parameter requires either `"Add`" , `"Delete`" or `"New`" as a value."
			}
		}
	}
}
function ProcessRegKeyConfig {
param ( [System.Xml.XmlElement]$SubKey )
	$Action = $SubKey.Action
	$ParentK = $SubKey.Key
	$Name = $SubKey.Name

	if ($Action -eq "Add") {
		$KType = $SubKey.Type
		$KVal = $SubKey.Value
		RegistryMod -RegAction $Action -ParentKey $ParentK -KeyName $Name -KeyType $KType -KeyValue $KVal
	} else {
		RegistryMod -RegAction $Action -ParentKey $ParentK -KeyName $Name
	}

	$ServiceConfig = $SubKey.ServiceConfig
	if($ServiceConfig) {
		foreach($Service in $ServiceConfig) {
			ProcessServiceConfig -Service $Service.Service
		}
	}
}
function FindRegistryKey{
param(
    [string]$SearchPath,
    [string]$SearchTerm
)
	LLTraceMsg -InvocationInfo $MyInvocation
	
	if( -not $SearchPath -or -not $SearchTerm){
		LLToLog -EventID $LLERROR -Text "Either SearchPath or SearchTerm were null. A value must be provided for each argument."
		return $false
	}
	
    $ItemList = Get-ChildItem $SearchPath -Recurse | ForEach-Object {Get-ItemProperty $_.pspath}
    foreach($Item in $ItemList){
        $RegObj = Get-ItemProperty $Item.PsPath
        $Properties = $RegObj.psobject.properties
        foreach($Prop in $Properties) {
            if($Prop.TypeNameOfValue -eq "System.String"){
                if($Prop.Value -eq $SearchTerm){
                    $NewObj = New-Object PSObject
                    $NewObj | Add-Member -Type NoteProperty -Name Path -Value $Item.PsPath
                    $NewObj | Add-Member -Type NoteProperty -Name Key -Value $Prop.Name
                    $NewObj | Add-Member -Type NoteProperty -Name Value -Value $Prop.Value
                    $NewObj
                }
            }
        }
    }
}