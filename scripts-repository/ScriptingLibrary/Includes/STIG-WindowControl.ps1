<# 
.SYNOPSIS
	Sends keystrokes to a Windows form. This only works when there is an interactive session (i.e.: someone has to be logged in for this function to work).
.DESCRIPTION
	Sends keystrokes from an object array to a Window identified by a form name. See the related link for important caveats on using this script.
.NOTES  
    File Name  : Enter-WindowsFormKeystrokes.ps1  
	Author        : Dan Meier
.LINK  
	http://technet.microsoft.com/en-us/library/ff731008.aspx
.EXAMPLE
	Enter-WindowsFormKeystrokes -WindowID $WindowName -KeyStreamObjectArr $KeyStreamObjArr 
.EXAMPLE
	$KeyStreamObjArr | Enter-WindowsFormKeystrokes -WindowID $WindowName
.PARAMETER WindowID
	[string] A string that equals the form title. Used to identify which window on the desktop the characters are to go to.
.PARAMETER KeyStreamObjectArr
	[PSObject[]] An array of PSObject type with the following attributes for each keystroke:
	.value - the actual keystroke. See the related links for string alternatives for non-printable characters
	.TimeUnit - milliseconds or seconds
	.DelayTime - the number of TimeUnits to delay after each keystroke. There should be some minimal delay (e.g.: 100 milliseconds) between each keystroke to emulate human typing speed.
	Some keystrokes will kick off processing and you'll want longer delays after those keystrokes to allow processing to complete before issuing more keystrokes (depending on whether you
	think the keystrokes will be buffered and whether certain form objects (like "Next"/"Finish" buttons) will be available).
#>
Function Enter-WindowsFormKeystrokes {
[CmdletBinding(DefaultParameterSetName = "FromPipe")]
	param (
		[Parameter(Mandatory=$true)] [string]$WindowID,
		[Parameter(ParameterSetName="FromPipe", Mandatory=$true, ValueFromPipeline=$True, ValueFromPipelinebyPropertyName=$True)] [PSObject[]] $KeyStreamObjectArr
	)

	[void] [System.Reflection.Assembly]::LoadWithPartialName("'Microsoft.VisualBasic")
	try {
		[Microsoft.VisualBasic.Interaction]::AppActivate($WindowID)
	} catch {
		if ($_.Exception -like "*Process * was not found.*") {
			if ($LoggingCheck) {ToLog -LogFile $LFName -EventID $ERR -Text "$_.Exception"}
			return 1
		}
	}
	[void] [System.Reflection.Assembly]::LoadWithPartialName("'System.Windows.Forms")

	if(!([Environment]::UserInteractive)) {
		if ($LoggingCheck) { ToLog -LogFile $LFName -EventID $WARNING -Text "The Enter-WindowsFormKeystrokes function requires an interactive session to work. No such session was found." }
	}
	#$KeyStreamObjectArr is an object with the following attributes
	# key
	# time signature (m for milliseconds; s for seconds)
	# time to wait after keystroke
	ForEach($KeyObj in $KeyStreamObjectArr) {
		if ($KeyObj.Desc) {
			Write-Host $KeyObj.Desc
		}
		[System.Windows.Forms.SendKeys]::SendWait("$($KeyObj.Key)")
		if ($KeyObj.TimeUnit -eq "m") {
			Start-Sleep -m $KeyObj.Delay
		} else {
			Start-Sleep -s $KeyObj.Delay
		}
	}
}