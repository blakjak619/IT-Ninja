function alterEnabledProto ([ValidateSet("Add", "Delete")][String]$Action, [String]$IISPath, [String]$Protocol) {

$Usage = @"
#-------------------------------------------------------------------------
# Solution: alterEnabledProto
# Author: Sly Stewart 
# Updated: 2/27/2013
# Version: 1.1
<#
# Description: Manage Enabled protocols in IIS.

- Mandatory Parameters
	[String]-IISPath <String>: The IIS path we need to alter 
	[String]-Action "Add" | "Delete": Add or Delete this protocol
	[String]-Protocol <String>: The protocol to either Add or Delete.

#
# Usage:
# - alterEnabledProto -Action "Add" -IISPath 'IIS:\Sites\SDChargers' -Protocol "net.msmq"
#	## Add the "NET.MSMQ" protocol to the site 'IIS:\Sites\SDChargers'

# - alterEnabledProto -Action "Delete" -IISPath 'IIS:\Sites\Padres' -Protocol "http"
#	## Delete the "HTTP" protocol from the site 'IIS:\Sites\Padres'

#>
# Revision History
# Version 1.0 - Initial Commit
# Version 1.1 - Made changes to ensure that Enabled Protocols would not enter in ",proto1,proto2" with comma in start. -SS 2/27/2013
#-------------------------------------------------------------------------

"@

	if ($PSBoundParameters.Count -ne 3) {
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Required parameters were not passed to alterEnabledProto. Exiting."
		}
		throw
	}
	try {
		if (!(Get-Module -Name Webadministration)) {
			Import-Module Webadministration
		}
	} catch [Exception] {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: `"WebAdministration`" module could not be loaded! Exiting."
		}
		throw "`"WebAdministration`" module could not be loaded!"
	}
	
	if (test-path $IISPath) {
	    [String]$Current = (Get-ItemProperty $IISPath -Name EnabledProtocols).EnabledProtocols
		if ($Current -eq "")
		{
			[String]$Current = (Get-ItemProperty $IISPath -Name EnabledProtocols).Value
		}
		$ProtoList = $Current.Split(",")
		$EnabledProto = New-Object System.Collections.ArrayList
		foreach ($proto in $ProtoList) {
			if ($proto.Trim() -ne "")
            {
				$Quiet = $EnabledProto.Add($proto)
			}
		}
		
		$MakeChange = $false
		if ($Action -eq "Add") {
			if (!($EnabledProto.Contains($Protocol))) {
				$Quiet = $EnabledProto.Add($Protocol)
				$MakeChange = $true
			}
		} elseif ($Action -eq "Delete") {
			if ($EnabledProto.Contains($Protocol)) {
				$Quiet = $EnabledProto.Remove($Protocol)
				$MakeChange = $true
			}
		}
		$NewList = ""
		foreach ($item in $EnabledProto) {
			$NewList = $NewList + $item + ","
		}
		$NewList = $NewList.TrimStart(",")
		$NewList = $NewList.TrimEnd(",")
		if ($MakeChange) {
			try {
				Set-ItemProperty $IISPath -Name enabledProtocols -Value $NewList
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "Set enabled protocols ($NewList) for `'$IISPath`' successfully."
				}
			} catch [Exception] {
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: There was a problem adding `'$protocol`' for EnabledProtocols for `'$IISPath`'. $_"
				}
				Throw "There was a problem adding `'$protocol`' for EnabledProtocols for `'$IISPath`'. `n`n $_"
			}
		}
		
	} else {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: IISPath `'$IISPath`' does not exist! Exiting."
		}
		throw "IIS Path does not exist!"
	}
}

function alterEnabledAuth ([String]$IISPath, `
[ValidateSet("Enable", "Disable")][String]$Action, `
[ValidateSet("digestAuthentication", "anonymousAuthentication", "iisClientCertificateMappingAuthentication", `
"basicAuthentication", "clientCertificateMappingAuthentication", "windowsAuthentication")][String]$AuthType) {
#http://www.iis.net/configreference/system.webserver/security/authentication

$Usage = @"
#-------------------------------------------------------------------------
# Solution: alterEnabledAuth
# Author: Sly Stewart 
# Updated: 1/29/2013
# Version: 1.0
<#
# Description: Manage Enabled protocols in IIS.

- Mandatory Parameters
	[String]-IISPath <String>: The IIS path we need to alter 
	[String]-Action "Enable" | "Disable": Add or Delete this protocol
	[String]-$AuthType "digestAuthentication" | "anonymousAuthentication" | "iisClientCertificateMappingAuthentication" | 
			"basicAuthentication" | "clientCertificateMappingAuthentication" | "windowsAuthentication"
			
			: The Authentication type to preform actions against.

#
# Usage:
# - alterEnabledAuth -IISPath 'IIS:\Sites\Beck' -Action "Enable" -AuthType "anonymousAuthentication"
#	## Enable Anonymous authentication on 'IIS:\Sites\Beck'

# - alterEnabledAuth -IISPath 'IIS:\Sites\U2' -Action "Disable" -AuthType "digestAuthentication"
#	## Enable Digest authentication on 'IIS:\Sites\U2'

#>
# Revision History
# Version 1.0 - Initial Commit
#-------------------------------------------------------------------------

"@

	if ($PSBoundParameters.Count -ne 3) {
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Required parameters were not passed to alterEnabledAuth. Exiting."
		}
		throw
	}
	try {

	if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "alterEnabledAuth Called With Action: $Action IISPath: $IISPath AuthType: $AuthType"
		}

		if (!(Get-Module -Name Webadministration)) {
			Import-Module Webadministration
		}
	} catch [Exception] {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: `"WebAdministration`" module could not be loaded! Exiting."
		}
		throw "`"WebAdministration`" module could not be loaded!"
	}
	
	if (Test-Path $IISPath) {
		switch ($Action) {
			"Enable" { $BoolStr = $true }
			"Disable" { $BoolStr = $false }
		}
		$AuthPath = "/system.WebServer/security/authentication/"
		$AuthFilter = $AuthPath + $AuthType
		
		$AuthParams = Get-WebConfigurationProperty -filter $AuthFilter -name "Enabled" -pspath $IISPath
		$AuthValue = $AuthParams.Value

		if ($AuthValue -ne $BoolStr) {
			try {
				$SetValue = Set-WebConfigurationProperty -filter $AuthFilter -name "Enabled" -pspath IIS:\ -location (($IISPath -replace "IIS:\\Sites\\", "") -replace "\\", "/") -value $BoolStr
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "Set Enabled Auth for `'$IISPath`' successfully"
				}
			} catch [Exception] {
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "There was an issue setting Enabled Auth for `'$IISPath`'. $_"
				}
				throw "There was an issue setting Enabled Auth for `'$IISPath`'."
			}
		} else {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Auth Already Set"
			}
		}
	} else {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: IISPath `'$IISPath`' does not exist! Exiting."
		}
		throw "IIS Path does not exist!"
	}
}
<# 
.SYNOPSIS
	SetIISParameter takes XML-based directives to add/set/del attributes of machine.config XML elements
.DESCRIPTION
	SetIISParameter takes XML-based directives to add/set/del attributes of machine.config XML elements for example maxConnections, minFreeThreads.
	It can modify other XML files, you just need to extend the ParamLookupTable for those other attribute locations.
.NOTES  
	Author        : Dan Meier  
	Assumptions   :
		It must be run as administrator to write the machine.config file in C:\windows...
#>
function SetIISParameter {
param(
	[System.Xml.XmlElement]$IISParam
)
	LLTraceMsg -InvocationInfo $MyInvocation
	
	$ConfigXMLFile = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Config"

	#Must be all lowercase to subvert XML case-sensitivity
	$ParamLookupTable = @{
	"maxconnection"              = "machine.config,system.net,connectionmanagement" ;
	"enable"                     = "machine.config,system.web" ;
	"timeout"                    = "machine.config,system.web" ;
	"idletimeout"                = "machine.config,system.web" ;
	"shutdowntimeout"            = "machine.config,system.web" ;
	"requestlimit"               = "machine.config,system.web" ;
	"requestqueuelimit"          = "machine.config,system.web" ;
	"restartqueuelimit"          = "machine.config,system.web" ;
	"memorylimit"                = "machine.config,system.web" ;
	"webgarden"                  = "machine.config,system.web" ;
	"cpumask"                    = "machine.config,system.web" ;
	"username"                   = "machine.config,system.web" ;
	"password"                   = "machine.config,system.web" ;
	"loglevel"                   = "machine.config,system.web" ;
	"clientconnectedcheck"       = "machine.config,system.web" ;
	"comauthenticationlevel"     = "machine.config,system.web" ;
	"comimpersonationlevel"      = "machine.config,system.web" ;
	"responsedeadlockinterval"   = "machine.config,system.web" ;
	"autoconfig"                 = "machine.config,system.web" ;
	"maxworkerthreads"           = "machine.config,system.web" ;
	"maxiothreads"               = "machine.config,system.web" ;
	"minworkerthread"            = "machine.config,system.web" ;
	"miniothreads"               = "machine.config,system.web" ;
	"minfreethreads"             = "machine.config,system.web" ;
	"minlocalrequestfreethreads" = "machine.config,system.web" ;
	"servererrormessagefile"     = "machine.config,system.web" ;
	"pingfrequency"              = "machine.config,system.web" ;
	"pingtimeout"                = "machine.config,system.web" ;
	"maxappdomains"              = "machine.config,system.web" ;
	}

	foreach($Directive in $IISParam.Setting) {
		#Parse the command directive
		foreach($node in $Directive) {
			foreach($attr in $node.Attributes) {
				$paramname = $attr.Name.ToLower()
				$paramstr = $ParamLookupTable.Get_Item("$paramname")
				if($paramstr) {
					break
				}
			}
			if(-not $paramstr) {
				LLToLog -EventID $LLWARN -Text "Couldn't find an attribute that I know how to implement."
			} else {
				# Using the lookup table information parse the path to the attribute you want to add/set/del
				$spltaray = $paramstr.split(",")
				$tgtFile = $spltaray[0] #The first element is the config file name
				$docPath = Join-Path $ConfigXMLFile $tgtFile
				if(-not (Test-Path $docPath)) {
					$errmsg = "Could not find file $docPath to update IIS configuration"
					LLToLog -Eventid $LLERROR -Text $errmsg 
					throw $errmsg
				}

				[xml]$xmlDoc = Get-Content $docPath #Error handling for file not found
				if(-not $xmlDoc) {
					$errmsg = "$docPath did not parse as an XML file when updating IIS configuration settings."
					LLToLog -Eventid $LLERROR -Text $errmsg 
					throw $errmsg 
				}
				$rootNode = $xmlDoc.get_documentElement()

				# Walk through the xml tree finding or adding the path elements
				$parent = $xmlDoc.configuration
				$NumLevels = $spltaray.Count - 1
				for($Level = 1; $Level -le $NumLevels; $Level++) {
					$sub = $spltaray[$Level]
					$child = $parent.$sub
					if(-not $child) {
						$child = $xmlDoc.CreateElement($sub)
						$quiet = $parent.AppendChild($child)
						$parent = $child
					} else {
						$parent = $child
					}
				}
				# When you have found or created the path (e.g. <configuration> <system.net> <connectionManagement> ) add/set/del the requested child element + attributes
				$ElementName = $Directive.Element
				$AddElement = $true
				if($ElementName){
					$child = $parent.$ElementName
					switch($Directive.Action) {
						# if the parent.Element is not found, create it
						# add attributes to parent.Element (aka child)
						"add" {
							if(-not $child) {
								$child = $xmlDoc.CreateElement($ElementName)
								$AddElement = $true
							} else {
								$AddElement = $false
							}
							foreach($attr in $Directive.Attributes) {
								if($attr.name -ne "Action" -and $attr.name -ne "Element") {
									$child.SetAttribute($attr.name,$attr.value)
								}
							}
							LLToLog -EventID $LLINFO -Text "Added $($Directive.OuterXML) to $parent"
						}
						"set" {
						    # if the Element wasn't found create it
							# otherwise delete it and recreate it
							# then add attributes
							if(-not $child) {
								$child = $xmlDoc.CreateElement($ElementName)
							} else {
								$quiet = $parent.RemoveChild($child)
								$child = $xmlDoc.CreateElement($ElementName)
							}
							$AddElement = $true
							foreach($attr in $Directive.Attributes) {
								if($attr.name -ne "Action" -and $attr.name -ne "Element") {
									$child.SetAttribute($attr.name,$attr.value)
								}
							}
							LLToLog -EventID $LLINFO -Text "Set $($child.OuterXML) to $($Directive.OuterXML)"
						}
						"del" {
							# if the element is found then delete it
							if($child) {
								$quiet = $parent.RemoveChild($child)
								LLToLog -EventID $LLINFO -Text "Deleted $($Directive.OuterXML)"
							}
							$AddElement = $false
						}
						Default {
							LLToLog -EventID $LLWARN -Text "Unrecognized action in $($Directive.OuterXML)"
						}
					}
					if($AddElement) {
						$quiet = $parent.AppendChild($child)
					}
				}
			}
		}
		
		# When you've processed all of the directives, save the file
		LLToLog -EventID $LLINFO -Text "Writing modified $docPath"
		try {
			$xmlDoc.Save($docPath)
			LLToLog -EventID $LLINFO -Text "Modified $docPath written"
		} catch {
			LLToLog -EventID $LLERROR -Text "Failed to write $docPath $_"
		}
		
	}
	
}
if ($MyInvocation.Line -notmatch "\. ") {
	$LIBPATH = $env:ScriptLibraryPath
	if(-not $LIBPATH) {
		$DefaultPath = "\\10.13.0.206\scratch\DML\Scripts\Includes"
		Write-Host "No $env:ScriptLibraryPath environment variable found. Defaulting to $DefaultPath"
		$LIBPATH = $DefaultPath
	}
	. $LIBPATH\LIB-Logging.ps1

	LLInitializeLogging -LogLevel $LLTRACE
	
	#Test(s) for SetIISParameter ------------------------------------------------------------------------
	$StartTime = Get-Date
	
	$xmldata = [xml]@"
<Config>
	<Setting Action="Set" Element="Add" Address="*" maxConnection="100" />
	<Setting Action="Set" Element="processModel" maxWorkerThreads="100" maxIoThreads="100" />
	<Setting Action="Set" Element="httpRuntime" minFreeThreads="704" minLocalRequestFreeThreads="608" />
</Config>
"@
	$XMLel = $xmldata.Config
	SetIISParameter -IISParam $XMLel
	
	Get-EventLog -After $StartTime -LogName Application
	# End SetIISParameter Tests --------------------------------------------------------------------------
}
