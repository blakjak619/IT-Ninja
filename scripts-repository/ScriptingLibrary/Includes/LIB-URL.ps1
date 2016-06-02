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