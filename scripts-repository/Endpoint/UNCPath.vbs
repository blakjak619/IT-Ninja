'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - This policy setting configures secure access to UNC paths.
'If you enable this policy, Windows only allows access to the specified UNC paths
'after fulfilling additional security requirements.
'Parameters -
'Remarks -
'Configuration Type - COMPUTER
'==============================================================

Set wshShell = CreateObject( "WScript.Shell" )
' Create a new subkey and a string value in that new subkey:




wshShell.RegWrite "HKLM\SOFTWARE\Policies\Microsoft\Windows\NetworkProvider\HardenedPaths\RequireMutualAuthentication", "1", "REG_SZ"
wshShell.RegWrite "HKLM\SOFTWARE\Policies\Microsoft\Windows\NetworkProvider\HardenedPaths\RequireIntegrity", "1", "REG_SZ"
wshShell.RegWrite "HKLM\SOFTWARE\Policies\Microsoft\Windows\NetworkProvider\HardenedPaths\RequirePrivacy", "1", "REG_SZ"


' Note: Since the WSH Shell has no Enumeration functionality, you cannot
'       use the WSH Shell object to delete an entire "tree" unless you
'       know the exact name of every subkey.
'       If you don't, use the WMI StdRegProv instead.

' Release the object
Set wshShell = Nothing