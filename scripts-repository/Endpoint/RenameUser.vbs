'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Changes the user name for a specified local account
'Parameters -
'Remarks - The local account name and the new name must be hard coded
'Configuration Type - COMPUTER
'==============================================================

'This specifies the local computer
strComputer = "."

'This tells it what name to look for
Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")
'Enter local account name here
Set colAccounts = objWMIService.ExecQuery _
    ("Select * From Win32_UserAccount Where LocalAccount = True And Name = 'nrbAdmin'")

'This tells it what to rename the account to
For Each objAccount in colAccounts
    objAccount.Rename "test1"
Next