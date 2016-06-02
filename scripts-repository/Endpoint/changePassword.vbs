'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Sets the password for the local user of the local machine.
'Parameters -
'Remarks - The usernames that you want to modify and the password must be hardcoded in the script
'Configuration Type - COMPUTER
'==============================================================
on error resume next
strComputer = "." ' Local Computer

'Write user names inside the array that you want to change the password for.
strUserNames = Array("test1","test2")

retSuccessCode = 1
retFailureCode = 0

For i = 0 To UBound(strUserNames) 
	'wscript.echo  strUserNames(i)
	SET objUser = GETOBJECT("WinNT://" & strComputer & "/" & strUserNames(i))
	'write the password you want to set for all the users.
	objUser.SetPassword("Thriftshop1")
	'wscript.echo err.number
	if err.number = 0 then
		retSuccessCode = 0
	else
		retFailureCode = err.number
	End if
	
	objUser.SetInfo
	SET objUser = nothing
	err.number = 0
Next

