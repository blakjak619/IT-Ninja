param([switch]$Help, [String]$XMLFile, [String]$EnvName)

$Usage = @"
# 
# Execute an endpoint (URL) check based on defined XMLFile
# Usage: 
#   -XMLFile  : properly formatted XML file*
#   -EnvName  : uDeploy environment (used to check for Deprecated)
#   -help     : this help
#
# * sample XML File in: $/Enterprise/Enterprise/Systems/Scripts/Powershell/SCOM/UserEditMonitor.xml
# * uDeploy tokenizeable XML file in: $/Enterprise/Enterprise/Systems/Scripts/Powershell/uDMonitor/Monitor.xml
#
"@


# this include uses powershell 2.0 / .Net stuff for http
# powershell 3.0: Invoke-WebRequest

# two functions:
# GetUrl - check connectivity to URL (bool)
# GetUrlContent - get content of URL (string)

## need to combine to one function (GetUrl) with the following parameters:
# [string]$url      : url to grab  (required)
# [int]$timeout     : timeout in ms to timeout  (system.net.WebRequest only, .net.webclient will ignore)
# [bool]$returnUrl   : return the content of the url (optional  / overload) - default false

# function: GetUrl
# purpose: mimics wget -O NUL http://url; useful for http checks
# params: url, timeout (optional, set to 10000ms by default), returnUrl (bool)
# returns:  boolean (connection status)
function GetUrl  {
	param ([string]$url, [int]$timeout = 10000)
	# try grabbing the url in the specified timeout
	try {
		# ignore SSL "Could not establish trust relationship for the SSL/TLS secure channel."
		[System.Net.ServicePointManager]::ServerCertificateValidationCallback = {$true}
		$myHttpWebRequest = [system.net.WebRequest]::Create($url)
		$myHttpWebRequest.Timeout = $timeout	
		# to obtain timing: Measure-Command {$myHttpWebResponse = $myHttpWebRequest.GetResponse()}
		$myHttpWebResponse = $myHttpWebRequest.GetResponse()
		$myHttpWebResponse.Close()
        return $true
	}
		catch [Net.WebException] {
		#$_ | fl * -Force		# grab exceptions, toss into formatted list (DEBUG)
		# test if 404 (not found) - we'll ignore these
		$statuscode = ( $_.Exception.Response.StatusCode -as [int])
		if ($statuscode -eq 404)
		{
			write-host  "(404) Not Found: $url"
		} 
		else {
			write-host "Fatal error with:" $url " Timeout setting: " ($timeout/1000) "seconds"
			# throw $_.exception	
		}
        return $false
	}
} # /GetUrl



# function: GetUrlContent
# purpose: grabs URL content
# params: url (required), username, password, domain (optional)
# returns: content of URL
function GetUrlContent  {
	param ([string]$url)
	# try grabbing the url in the specified timeout
	try {

		$myHttpWebRequest = New-Object Net.WebClient
        $myHttpWebRequest.UseDefaultCredentials=$true
        $myHttpWebResponse = $myHttpWebRequest.DownloadString($url)
	}
	catch  {
		#$_ | fl * -Force		# grab exceptions, toss into formatted list (DEBUG)
		write-host "Fatal error with:" $url
		throw $($error[0])
	}
	return $myHttpWebResponse
} # /GetUrlContent

#Does an http get on a url and validates success code is in response
function InvokeMonitor($url, $successCode)
{
    $Success = $false
    $Response = ""
    #Flick monitor (initial check)
    # disregard a failure at this time, we'll try again later
    try { $Response = GetUrlContent $Monitor.Url } catch [System.Exception] { $Response = $_.Exception.ToString() } 
    
    # if Deprecated, no need to invoke monitor again and change success code
    if ("$EnvName" -like "*Deprecated*") {
        $successCode = "(404) Not Found" # 404 is what we want, overwrite whatever's in Monitor.xml
        Write-Warning "uDeploy `'envName`' property set to `'$EnvName`', checking for HTTP response: $successCode"
    }

    if ($Response -clike "*$successCode*") { $Success = $true } 
    # retry logic
    $Retries = 3 # knock 3 times
    $SleepyTime = 10  # 10 seconds between retries
    $currentRetry = 0
    if (!$Success) { 
        write-host "Re-trying.."
        do {
           if ($currentRetry -lt $Retries) { 
                try
                {
                    #Flick monitor
	                #  $Response = Invoke-WebRequest $Monitor.Url   #powershell 3.x specific
                    $Response = GetUrlContent $Monitor.Url
                    #If response has string we are looking for, success
                    if ($Response -clike "*$successCode*")
                    {
                        $Success = $true
                    }
                }
                catch [System.Exception]
                {
                    #Catch exceptions for not found, not auth, etc.
                    $Response = $_.Exception.ToString()
                }
            }
            Start-Sleep $SleepyTime
            write-host "Re-trying.."
            $currentRetry = $currentRetry + 1 
        } while (!$Success -and $currentRetry -lt $Retries) 
    } # end all attempts
    #Output for logging/debugging
    if ($Success -eq $false)
    {
        Write-Host "Monitor Check Failure - Url: $Url `nSuccessCode: $successCode `nResponse: $Response"
    }
    else
    {
        Write-Host "Monitor Check Success - Url: $Url `nSuccessCode: $successCode `nResponse: $Response"
    }

    return $Success
}

########
# MAIN #
########

# usage
if ( $Help) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	throw "Showing Help."
}
#Start: Part of Default PS Script

if ($XMLFile) {
	if (!(Test-Path $XMLFile)) {
		throw "-XMLFile <String> parameter is absolutely needed, and path valid."
	} elseif ((gi $XMLFile).PSIsContainer) {
		throw "-XMLFile <String> parameter needs to point to a valid .XML file."
	} elseif (((gi $XMLFile).Extension) -ne ".xml") {
		throw "-XMLFile <String> parameter needs to point to a valid .XML file."
	}
} else {
	throw "-XMLFile <String> parameter is absolutely needed, and path valid."
}

$NoOp = $false
$ScriptPath = ($PWD).path

try {
	[xml]$XMLParams = gc $XMLFile
} catch [Exception] {
	$NoOp = $true
	Write-Host "Error reading XML file."
    $_
    throw
    
}

if (!$XMLParams) {
	$NoOp = $true
	throw "Empty XML file"
}

if (!$NoOp) {

#End: Part Of Default Template

    #Get monitor from param file
    $Monitors = $XMLParams.params.Monitors

    #If param file has a monitor section
	if ($Monitors) {

        #Loop through monitors
		foreach ($Monitor in $Monitors.Monitor) {

            if ($Monitor.DeployCheck -eq $true)
            {
                #Invoke Monitor
                $MonitorSuccessful = InvokeMonitor $Monitor.Url $Monitor.SuccessCode

                #Do something with result?
                if ($MonitorSuccessful -eq $true)
                {
                exit 0
                }
                else
                {
                exit 1
                }
            }

		}
	}

}