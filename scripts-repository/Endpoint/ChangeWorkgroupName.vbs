'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Changes the Workgroup name for the local machine
'Parameters - New Workgroup Name, Username, Password
' "workgroupname" "username" "password"
'Configuration Type - COMPUTER
'==============================================================

Const JOIN_WORKGROUP = 0
Const JOIN_DOMAIN = 1
Const ACCT_CREATE = 2
Const ACCT_DELETE = 4
Const WIN9X_UPGRADE = 16
Const DOMAIN_JOIN_IF_JOINED = 32
Const JOIN_UNSECURE = 64
Const MACHINE_PASSWORD_PASSED = 128
Const DEFERRED_SPN_SET = 256
Const INSTALL_INVOCATION = 262144

Const NETSETUP_ACCT_DELETE = 2 'Disables computer account in domain.

'strDomain = "WORKGROUP"
'strUser = "username"
'strPassword = "password"

if WScript.Arguments.Count = 3 Then
strDomain = WScript.Arguments.Item(0)
strUser = WScript.Arguments.Item(1)
strPassword = WScript.Arguments.Item(2)
Else if WScript.Arguments.Count = 2 Then
strDomain = WScript.Arguments.Item(0)
strUser = WScript.Arguments.Item(1)
Else if WScript.Arguments.Count = 1 Then
strDomain = WScript.Arguments.Item(0)
End if
End if
End if

Set objNetwork = CreateObject("WScript.Network")
strComputer = objNetwork.ComputerName
Set objComputer = _
GetObject("winmgmts:{impersonationLevel=Impersonate}!\\" & _
strComputer & "\root\cimv2:Win32_ComputerSystem.Name='" _
& strComputer & "'")

intReturn = objComputer.UnjoinDomainOrWorkgroup _
(NULL, NULL, NETSETUP_ACCT_DELETE)


ReturnValue = objComputer.JoinDomainOrWorkGroup(strDomain, _
strPassword, _
strDomain & "\" & strUser, _
NULL, _
JOIN_WORKGROUP + ACCT_CREATE)

Wscript.Quit ReturnValue