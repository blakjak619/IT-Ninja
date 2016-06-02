param([switch]$Help, 
[String]$WebDeployExe = "C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe", 
[String]$PackagePath, 
[String]$SetParamFilePath,
[String]$EnvName, 
[String]$Server,
[String]$SiteName,
[String]$userName,
[String]$password,
[String]$wwwRoot,
[String]$WCDropFolder = "\\10.13.0.206\uDeploy_repository\WebConfigExport"  )



$Usage = @"
#-------------------------------------------------------------------------
# Solution: uD-CloudWebDeployWrapper.ps1
# Author: Todd Pluciennik
# Updated:1/5/2015
# Version: 1
<#
# Description:
- Executes webdeploy with the package and set parameters path passed. Specifically for cloud deployments using msdeploy.exe
  The uDeploy envName passed will check for environment specific <envname>.setparameters.xml
  Use cases:  
  1) Only SetParameters.xml - will be called as is 
  2) Only <env>.SetParameters.xml files exist - will be called with specific environment file only
  3) SetParameters.xml + nonprod/<Env>.SetParameters.xml - will be combined

#
# Usage: 
		- WebDeployWrapper.ps1 -WebDeployExe <path> -PackagePath <path> -SetParamFilePath <path> -EnvName <property> -AppName <property> -wwwRoot <property> -WCDropFolder <path>
		- WebDeployWrapper.ps1 -Help : Show this help text.
  Parameters:
        -WebDeployExe <path to ms webdeploy>
        -PackagePath <path to .zip website to deploy>
        -SetParamFilePath <path to setparamers XML files>
        -EnvName <uDeploy envName property>
        -wwwRoot <uDeploy wwwroot folder property> 
        -WCDropFolder <path to Web.config drop folder share>
        -Server  <uDeploy Server property (Cloud endpoint)>
        -SiteName <uDeploy SiteName property (Cloud sitename)>
        -userName <uDeploy userName property (Cloud userName)>
        -password <uDeploy password property (Cloud password)>
#>
# Revision History
# Version 1.0  - Initial Commit 
#-------------------------------------------------------------------------

"@
if ($Help) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	throw "Showing Help."
}

# params: $xmlelem: XML element to use as root node, e.g. "parameters"
# Credit: https://gist.github.com/kardeiz/1723916
function CombineXML {
    param([String]$xmlelem,
    [String]$BaseFile,
    [String]$EnvFile,
    [String]$DestFile
    )
    Write-host "INFO:: Combining XML files.."
    $xmldoc = new-object xml
    $rootnode = $xmldoc.createelement($xmlelem)
    $null = $xmldoc.appendchild($rootnode)
    $dec = $xmldoc.CreateXmlDeclaration("1.0", $null, $null)
    $null = $xmldoc.InsertBefore($dec, $rootnode)
    $files = @("$BaseFile","$EnvFile")
    foreach ($file in $files) {
        Write-host "INFO:: $file"
        $file = gci $file    # need child item object
        $xmltoadd = select-xml -path $file.FullName -xpath "/*"
        $xml2 = $xmltoadd.node.innerxml
        $finalxml += $xml2
    }
    $rootnode.innerxml = $finalxml
    $xmldoc.Save($DestFile )
 
 } # end CombineXML


# from get-serverstandupfiles.ps1
Function ReplaceTokens {
param (
    [Parameter()] [string]$TokenFile,
    [Parameter()] [string]$PathToTokenize
)
    #Get the list of tokens
    if (!(Test-Path $TokenFile)) {
        throw
    }

    $TokenDelimiter = "@@@"
    $TokenHash = ConvertFrom-StringData ([io.file]::ReadAllText( $TokenFile ))
	#ProcessTokenFunctions
	#So right now $TokenHash looks like TokenKeyWord,TokenValue
    #Form the search pattern
    $SearchPattern = ""
    $TokenHash.Keys | foreach {
        $SearchPattern += "$_|"
    }
    #Remove trailing "|"
    $SearchPattern = $SearchPattern.TrimEnd("|")

    # file or container?
    if (Test-Path $PathToTokenize -PathType Leaf) {
       $TargetFiles = (Get-ChildItem $PathToTokenize)
    } else { # container

       $TargetFiles = (Get-ChildItem $PathToTokenize -recurse | 
        Where-Object {$_.psiscontainer -eq $false} | 
        Where-Object {$_.Extension -eq ".xml" -or $_.Extension -eq ".ini"} |
        Where-Object {!($_.FullName -like "*$TokenFile" )} |
        Where-Object {Get-Content $_.pspath |select-string -pattern "$SearchPattern"})
    }
    foreach ($File in $TargetFiles) {
		Set-ItemProperty $File.fullname -name IsReadOnly -value $false
        Write-Host "Replacing tokens in $($File.FullName)"
        (Get-Content $File.FullName) | ForEach-Object {
            $Line = $_
            $TokenHash.GetEnumerator() | ForEach-Object {
                $KeyPattern = $TokenDelimiter + $_.Key + $TokenDelimiter
                if ($Line -match $KeyPattern) {
                    $OldLine = $Line
                    $Line = $Line -replace $KeyPattern, $_.Value
                    Write-Host "Replacing [$OldLine] with [$Line]"
                }
            }
            $Line
        } | Set-Content $File.FullName
    }
}


# source includes
$ScriptPath = ($PWD).path
$IncludesF = join-path "$ScriptPath" "..\Includes"
if (Test-Path "$IncludesF") {
		foreach ($item in $(dir "$IncludesF" | ? {$_.name -like "*.ps1"})) {
			$FullName = $item.FullName
			. "$FullName"
		}
	} else {
		#Includes folder is not present.
		throw "`'$IncludesF`' folder is not present!"
	}



##########
## MAIN ##
##########
# Are we Deprecated? 
if ("$EnvName" -like "*Deprecated*") {
    Write-Warning "uDeploy `'envName`' property set to `'$EnvName`', skipping msdeploy!"
    return 0
}

# example WebDeployExe:  C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe
$FldrPath = Split-Path -Path "$WebDeployExe" -Parent
$BinName = Split-Path -Path "$WebDeployExe" -Leaf

# sanity checks:
if (!(test-path $WebDeployExe -PathType Leaf)) {
    Write-Error "FAILURE:: Could not find Webdeploy in supplied path ($WebDeployExe)!" 
    throw 
    }

# find Package and SetParameters.xml + <env>.SetParameters.xml
if (test-path $PackagePath) {
    $files = ( Get-ChildItem $PackagePath -Filter *.zip  | Measure-Object ).Count
    if (($files -eq 0 ) -or ($files -gt 1) ) {
        Write-Error "FAILURE:: 0 (or more than 1) .zip file(s) found in $PackagePath...`n>> There can be only one! <<"
        throw
        }

    $item =  $(dir "$PackagePath" | ? {$_.name -like "*.zip"})
	$Package = $item.FullName
} 

# combo XML if SetParameters found with <env>.SetParameters.xml
if (test-path $SetParamFilePath) {
    $envFiles = $False  # flag to join files if env files exist
    # last match wins
    # nonprod.setparams
    if ("$EnvName" -ne "PROD") { 
        $xml = "nonprod.SetParameters.xml" 
        $envFilePath = join-path $SetParamFilePath $xml
        if (test-path $envFilePath -pathType leaf) { 
            $SetParamFile = $envFilePath 
            $envFiles = $True
            }
    }
    # envname.setparams
    $xml = "$EnvName.SetParameters.xml" 
    $envFilePath = join-path $SetParamFilePath $xml
    if (test-path $envFilePath -pathType leaf) { 
            $SetParamFile = $envFilePath
            $envFiles = $True
            }

    # now test if there's a SetParameters.xml file 
    $xml = "SetParameters.xml"
    $testPath = join-path $SetParamFilePath $xml
    if (test-path $testPath -pathType leaf) { 
        $SetParamFile = $testPath
        if ($envFiles) {
            # this means we need to combo $envFilePath with $SetParamFile
            $combinedFile = join-path $SetParamFilePath "SetParameters-combined.xml"
            CombineXML -xmlelem "parameters" -BaseFile $SetParamFile -EnvFile $envFilePath -DestFile $combinedFile
            # last step, the combined file will be used
            $SetParamFile = $combinedFile 
            } # end $envFiles 
        }
} 

if (! $SetParamFile) {
    write-host "FAILURE:: Could not find a proper SetParameters.xml file ($SetParamFile) from supplied path ($SetParamFilePath)!" 
    throw
}

# last sanity check
if (!(Test-path $Package -PathType Leaf) -or !(Test-Path $SetParamFile -PathType Leaf)) {
    write-host "FAILURE:: Could not find .zip ($Package) and/or SetParameters ($SetParamFile) from supplied paths!" 
    throw
}

#region version
# grab version info from package and setparam version.txt, create temp file that can be used for replacing tokens
$tokenFile = [System.IO.Path]::GetTempFileName()
if (Test-Path ${PackagePath}\Version.txt -PathType Leaf) { (Get-Content ${PackagePath}\Version.txt) | Set-Content $tokenFile -Encoding Ascii }
if (Test-Path ${SetParamFilePath}\Version.txt -PathType Leaf) { (Get-Content ${SetParamFilePath}\Version.txt) | Add-Content $tokenFile -Encoding Ascii }
if (Get-Content $tokenFile) { #only do replacement if versions present
    ReplaceTokens -TokenFile "$tokenFile" -PathToTokenize "$SetParamFile"
}
#endregion

   
#region build command line and execute    
$CLA = "-source:package='$Package' -dest:auto,computerName='$Server/msdeploy.axd?site=$SiteName',userName='$userName',password='$password',authtype='Basic',includeAcls='False' -verb:sync -disableLink:AppPoolExtension -disableLink:ContentExtension -disableLink:CertificateExtension -setParamFile:`"$SetParamFile`""
 
# log everything to stdout, WebDeploy requires DisableShellExecute
$LoggingCheck = $false
# kickstart the msdeploy service, then deploy
restart-service -Name MsDepSvc -Force -Verbose

LaunchProcessAndWait -Destination "$FldrPath" -FileName $BinName -CommandLineArgs $CLA -DisableShellExecute -Timeout 300000 -Retries 3 -RetrySleep 10 -NoClobber
#endregion

#region Display contents of web.config
<# deprecated for now
# and copy to DropFolder
# only for nonprod
if ("$EnvName" -ne "PROD") { 
    # Build the path with the uDeploy supplied properties wwwroot and appname
    $webconfigpath = "D:\WWWROOT\$wwwRoot\$AppName\web.config"
    if (Test-path $webconfigpath -PathType Leaf){
        # stdout web.config
        write-host "[INFO]:: Contents of ${webconfigpath}:"
        Get-Content $webconfigpath 
    
        # copy to drop folder
        if ($WCDropFolder) {
            if (test-path $WCDropFolder -PathType Container) {
                $sourcehost=($env:COMPUTERNAME).ToLower()
                write-host "[INFO}:: Copying ${webconfigpath} to $WCDropFolder"
                try {
                 Copy-Item $webconfigpath -Destination "$WCDropFolder\$AppName-$EnvName-$sourcehost-web.config" -Force
                } catch {
                 Write-Error "Error: $_"
                 throw
                }
            }
        }
       
       
    }
}
#>
#endregion

exit 0