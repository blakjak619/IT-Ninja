## Functions pertaining to UserRightsAssignment
Function AddAccountPolicy {
    param([string]$account,
    [string]$right)

$Usage = @"
#-------------------------------------------------------------------------
# Solution: AddAccountPolicy
# Author: Todd Pluciennik
# Credit: Ingo Karstein, http://ikarstein.wordpress.com v1.0, 10/12/2012
#         http://gallery.technet.microsoft.com/office/PowerShell-script-to-add-b005e0f6
# Updated: 04/21/2014
# Version 1.5
#
# Revision History
# Version 1.0 - Initial Commit 
# Version 1.5 - added rights as a passable param to make this function usable

<#
# Description:
- Configures an account to add the access right
Mandatory Parameters:
    [String]-account: Name of the account to allow right
    [String]-right: Name of right to add (e.g. SeBatchLogonRight, SeServiceLogonRight)

"@


    $sidstr = $null
    try {
	    $ntprincipal = new-object System.Security.Principal.NTAccount "$account"
	    $sid = $ntprincipal.Translate([System.Security.Principal.SecurityIdentifier])
	    $sidstr = $sid.Value.ToString()
    } catch {
	    $sidstr = $null
    }

    # Write-Host "Account: $($account)" -ForegroundColor DarkCyan

    if( [string]::IsNullOrEmpty($sidstr) ) {
        Write-Host "Account ($account) not found!" -ForegroundColor Red
        Write-Host "FAILURE:: Unable to add account `'$account`'. SID not found!"
	    throw
    }

    # Write-Host "Account SID: $($sidstr)" -ForegroundColor DarkCyan

    $tmp = [System.IO.Path]::GetTempFileName()
    Write-host "Allow $right..." 
    Write-Host "Export current Local Security Policy" -ForegroundColor DarkCyan
    secedit.exe /export /cfg "$($tmp)" 

    $c = Get-Content -Path $tmp 

    $currentSetting = ""

    foreach($s in $c) {
	    if( $s -like "$right*") {
		    $x = $s.split("=",[System.StringSplitOptions]::RemoveEmptyEntries)
		    $currentSetting = $x[1].Trim()
	    }
    }

    if( $currentSetting -notlike "*$($sidstr)*" ) {
	    Write-Host "Modify Setting ""$right""" -ForegroundColor DarkCyan
	
	    if( [string]::IsNullOrEmpty($currentSetting) ) {
		    $currentSetting = "*$($sidstr)"
	    } else {
		    $currentSetting = "*$($sidstr),$($currentSetting)"
	    }
	
	    Write-Host "$currentSetting"
    # Signature: http://msdn.microsoft.com/en-us/library/windows/hardware/ff547502(v=vs.85).aspx	
	    $outfile = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
$right = $($currentSetting)
"@

	    $tmp2 = [System.IO.Path]::GetTempFileName()
	
	
	    Write-Host "Import new settings to Local Security Policy" -ForegroundColor DarkCyan
	    $outfile | Set-Content -Path $tmp2 -Encoding Unicode -Force

	    #notepad.exe $tmp2
	    Push-Location (Split-Path $tmp2)
	
	    try {
		    secedit.exe /configure /db "secedit.sdb" /cfg "$($tmp2)" /areas USER_RIGHTS 
            write-host "Contents of scesrv.log:"
            gc $env:windir\security\logs\scesrv.log
		    #write-host "secedit.exe /configure /db ""secedit.sdb"" /cfg ""$($tmp2)"" /areas USER_RIGHTS "
	    } finally {	
		    Pop-Location
	    }
    } else {
	    Write-Host "NO ACTIONS REQUIRED! Account already in ""$right""" -ForegroundColor DarkCyan
    }

    Write-Host "Done." -ForegroundColor DarkCyan

} # end AddAccountPolicy


Function RemoveAccountPolicy  {
    param([string]$account,
    [string]$right)

$Usage = @"
#-------------------------------------------------------------------------
# Solution: RemoveAccountPolicy
# Author: Todd Pluciennik
# Credit: Ingo Karstein, http://ikarstein.wordpress.com v1.0, 10/12/2012
#         http://gallery.technet.microsoft.com/office/PowerShell-script-to-add-b005e0f6
# Updated: 04/21/2014
# Version 1.5
#
# Revision History
# Version 1.0 - Initial Commit 
# Version 1.5 - added rights as a passable param to make this function usable

<#
# Description:
- Configures Removes access right for a particular user
Mandatory Parameters:
    [String]-account: Name of the account to remove rights from
    [String]-right: Name of right to add (e.g. SeBatchLogonRight, SeServiceLogonRight)

"@
## process summary:
<# 
map account to remove to SID if possible
export existing Local Security Policy
find the name to remove and remove, create import file
import new policy with import file
#>

    # Do not need SID per-se, as this may or may not exist (e.g. for Classic .NET AppPool), so set to the account name to remove
    try {
	    $ntprincipal = new-object System.Security.Principal.NTAccount "$account"
	    $sid = $ntprincipal.Translate([System.Security.Principal.SecurityIdentifier])
	    $sidstr = $sid.Value.ToString()
    } catch {
	    $sidstr = $account
    }

    $tmp = [System.IO.Path]::GetTempFileName()
    $tmp2 = [System.IO.Path]::GetTempFileName()
    Write-host "Remove $right..." 
    Write-Host "Export current Local Security Policy" -ForegroundColor DarkCyan
    secedit.exe /export /cfg "$($tmp)" 

    $c = Get-Content -Path $tmp 
    $currentSetting = ""

    foreach($s in $c) {
	    if( $s -like "$right*") {
		    $x = $s.split("=",[System.StringSplitOptions]::RemoveEmptyEntries)
		    $currentSetting = $x[1].Trim()
	    }
    }

    if( $currentSetting -like "*$($sidstr)*" ) {
	    Write-Host "Modify Setting ""$right""" -ForegroundColor DarkCyan
	    $currentSetting = $currentSetting -replace "\*${sidstr}", ""
        $currentSetting = $currentSetting.TrimStart(",")  # ensure first character is not a comma
        $currentSetting = $currentSetting -replace  ",,", ","  # replace double with single comma
        $currentSetting = "$($currentSetting)"

# Signature: http://msdn.microsoft.com/en-us/library/windows/hardware/ff547502(v=vs.85).aspx	
	$outfile = @"
[Unicode]
Unicode=yes
[Version]
signature="`$CHICAGO`$"
Revision=1
[Privilege Rights]
SeServiceLogonRight = $($currentSetting)
"@

	

	Write-Host "Import new settings to Local Security Policy" -ForegroundColor DarkCyan
	$outfile | Set-Content -Path $tmp2 -Encoding Unicode -Force

    Push-Location (Split-Path $tmp2)
	try {
		secedit.exe /configure /db "secedit.sdb" /cfg "$($tmp2)" /areas USER_RIGHTS 
        write-host "Contents of scesrv.log:"
        gc $env:windir\security\logs\scesrv.log
		#write-host "secedit.exe /configure /db ""secedit.sdb"" /cfg ""$($tmp2)"" /areas USER_RIGHTS "
	} finally {	
		Pop-Location
	}


    } else {
	    Write-Host "NO ACTIONS REQUIRED! Account ($account) not found within ""$right""" -ForegroundColor DarkCyan
    }

    Write-Host "Done." -ForegroundColor DarkCyan
    # cleanup: remove tmp files
    $nothing = rm $tmp  -Force
    $nothing = rm $tmp2 -Force

} # end function

