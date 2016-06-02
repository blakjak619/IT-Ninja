'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.


'Description - Script to change computer name of the local machine.
'Parameters - New computer name, Username and password
' ex: "newcomputername" "domain\username" "password"
'Remarks - For domain machine username must be in the form domain\username
'For Workgroup machine only new name needs to be passed.
'Configuration Type - COMPUTER
'==============================================================

if WScript.Arguments.Count = 3 Then
Name = WScript.Arguments.Item(0)
Username = WScript.Arguments.Item(1)
Password = WScript.Arguments.Item(2)
Else if WScript.Arguments.Count = 1 Then
Name = WScript.Arguments.Item(0)
Username = NULL
Password = NULL
End if
End if

Set objWMIService = GetObject("Winmgmts:root\cimv2")

' Call always gets only one Win32_ComputerSystem object.
For Each objComputer in _
    objWMIService.InstancesOf("Win32_ComputerSystem")

        Return = objComputer.rename(Name,Password,Username)
        

Next
Wscript.Quit Return