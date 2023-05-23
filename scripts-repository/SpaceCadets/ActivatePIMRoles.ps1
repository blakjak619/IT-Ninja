# Get token for MS Graph by prompting for MFA
$MsResponse = Get-MSALToken -Scopes @("https://graph.microsoft.com/.default") -ClientId "Insert Your ClientID" -RedirectUri "urn:ietf:wg:oauth:2.0:oob" -Authority "https://login.microsoftonline.com/common" -Interactive -ExtraQueryParameters @{claims='{"access_token" : {"amr": { "values": ["mfa"] }}}'}

# Get token for AAD Graph
$AadResponse = Get-MSALToken -Scopes @("https://graph.windows.net/.default") -ClientId "Insert Your ClientID" -RedirectUri "urn:ietf:wg:oauth:2.0:oob" -Authority "https://login.microsoftonline.com/common"

Connect-AzureAD -AadAccessToken $AadResponse.AccessToken -MsAccessToken $MsResponse.AccessToken -AccountId: "upn" -tenantId: "tenantId"
Enable-DCAzureADPIMRole -RolesToActivate 'Intune Administrator', 'Authentication Administrator', 'Office Apps Administrator', 'Exchange Administrator', 'Helpdesk Administrator', 'Authentication Policy Administrator', 'Teams Administrator', 'License Administrator', 'Groups Administrator', 'SharePoint Administrator', 'Conditional Access Administrator' -UseMaximumTimeAllowed -Reason 'Working tickets.'