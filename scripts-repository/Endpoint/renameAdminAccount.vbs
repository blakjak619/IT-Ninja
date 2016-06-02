'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to rename the user name of the admin account of the local machine
'Parameters - <New User name>
'Remarks -
'Configuration Type - COMPUTER
'==============================================================

'This specifies the local computer
strComputer = "."
newAccountName = WScript.Arguments.Item(0)
'This tells it what name to look for
Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")
Set colAccounts = objWMIService.ExecQuery _
    ("Select * From Win32_UserAccount Where LocalAccount = True And Name = 'Administrator'")

'This tells it what to rename the account to
For Each objAccount in colAccounts
    objAccount.Rename newAccountName
Next