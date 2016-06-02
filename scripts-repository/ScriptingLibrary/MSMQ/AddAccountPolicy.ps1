param([string]$account,[string]$right)

Function AddAccountPolicy ([string]$accountToAdd, [string]$accessRight) {
$Usage = @"
#-------------------------------------------------------------------------
# Solution: AddAccountPolicy
# Author: Todd Pluciennik
# Credit: Ingo Karstein, http://ikarstein.wordpress.com v1.0, 10/12/2012
#         http://gallery.technet.microsoft.com/office/PowerShell-script-to-add-b005e0f6
# Updated: 10/10/2013
# Version: 1.0
<#
# Description:
- Configures an account to add the access right
Mandatory Parameters:
    [String]-accountToAdd: Name of the account to allow right
    [String]-accessRight: Name of right to add (e.g. SeBatchLogonRight, SeServiceLogonRight)

"@


    $sidstr = $null
    try {
	    $ntprincipal = new-object System.Security.Principal.NTAccount "$accountToAdd"
	    $sid = $ntprincipal.Translate([System.Security.Principal.SecurityIdentifier])
	    $sidstr = $sid.Value.ToString()
    } catch {
	    $sidstr = $null
    }

    # Write-Host "Account: $($accountToAdd)" -ForegroundColor DarkCyan

    if( [string]::IsNullOrEmpty($sidstr) ) {
        Write-Host "Account ($accountToAdd) not found!" -ForegroundColor Red
        Write-Host "FAILURE:: Unable to add account `'$accountToAdd`'. SID not found!"
	    throw
    }

    # Write-Host "Account SID: $($sidstr)" -ForegroundColor DarkCyan

    $tmp = [System.IO.Path]::GetTempFileName()
    Write-host "Allow $accessRight..." 
    Write-Host "Export current Local Security Policy" -ForegroundColor DarkCyan
    secedit.exe /export /cfg "$($tmp)" 

    $c = Get-Content -Path $tmp 

    $currentSetting = ""

    foreach($s in $c) {
	    if( $s -like "$accessRight*") {
		    $x = $s.split("=",[System.StringSplitOptions]::RemoveEmptyEntries)
		    $currentSetting = $x[1].Trim()
	    }
    }

    if( $currentSetting -notlike "*$($sidstr)*" ) {
	    Write-Host "Modify Setting ""$accessRight""" -ForegroundColor DarkCyan
	
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
$accessRight = $($currentSetting)
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
	    Write-Host "NO ACTIONS REQUIRED! Account already in ""$accessRight""" -ForegroundColor DarkCyan
    }

    Write-Host "Done." -ForegroundColor DarkCyan

} # end AddAccountPolicy


AddAccountPolicy $account $right