'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to move all users from Users group to Administrators group except specified users
'Parameters -
'Remarks - The exceptions must be hardcoded in the script
'Configuration Type - COMPUTER
'==============================================================
On Error Resume Next
strComputer = "."
strLocalAdminGroup = "Administrators"  
Set objGroup = GetObject("WinNT://" & strComputer & "/Administrators")
Set objGroupUsers = GetObject("WinNT://" & strComputer & "/Users")

For Each objUser In objGroupUsers.Members
	'Wscript.Echo objUser.Name
	objGroupUsers.Remove(objUser.AdsPath)
	objGroup.Add(objUser.AdsPath)	
Next

wscript.quit err.number

