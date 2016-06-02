 cls

 #$username = 'DEV_SVC_DWEmlEvtMgr'
 #$password = 'EX!JHKTYkQcB'

 $username = 'sa_nav-jobqueue'
 $password = 'leo75*zodiac'

 # Get current domain using logged-on user's credentials
 $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
 $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$UserName,$Password)

if ($domain.name -eq $null)
{
 write-host "FAIL"
}
else
{
 write-host "SUCCESS"
}