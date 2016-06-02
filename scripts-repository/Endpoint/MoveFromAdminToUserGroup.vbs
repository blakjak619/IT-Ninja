'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to move all users from Administrators group to Users group except specified users
'Parameters -
'Remarks - The exceptions must be hardcoded in the script
'Configuration Type - COMPUTER
'==============================================================

On Error Resume Next
strComputer = "."
strLocalAdminGroup = "Administrators"  
Set objGroup = GetObject("WinNT://" & strComputer & "/Administrators")
Set objGroupUsers = GetObject("WinNT://" & strComputer & "/Users")

For Each objUser In objGroup.Members
'Mention the user names you want to exclude from the above action 
   if objUser.Name <> "Administrator" And objUser.Name <> "PC_ADMIN" then
		'Wscript.Echo objUser.Name
		objGroupUsers.add(objUser.AdsPath)
		objGroup.Remove(objUser.AdsPath)	
	End if
Next

wscript.quit err.number

