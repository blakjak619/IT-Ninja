'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to delete the specified key
'Parameters -
'Remarks - The hive and the sub key must be hard coded
'Configuration Type - COMPUTER
'==============================================================

On Error Resume Next 

Const HKEY_CLASSES_ROOT 	= &H80000000
Const HKEY_CURRENT_USER 	= &H80000001
Const HKEY_LOCAL_MACHINE 	= &H80000002
Const HKEY_USERS 		= &H80000003
Const HKEY_CURRENT_CONFIG 	= &H80000005

strComputer = "."
'write the header key here
mainKey = HKEY_LOCAL_MACHINE
'write the subkey here
strKeyPath = "Software\sample" 

Set objRegistry = GetObject("winmgmts:\\" & _
    strComputer & "\root\default:StdRegProv") 

DeleteSubkeys mainKey, strKeypath

Sub DeleteSubkeys(mainKey, strKeyPath) 
    objRegistry.EnumKey mainKey, strKeyPath, arrSubkeys 

    If IsArray(arrSubkeys) Then 
        For Each strSubkey In arrSubkeys 
            DeleteSubkeys mainKey, strKeyPath & "\" & strSubkey 
        Next 
    End If 

    objRegistry.DeleteKey mainKey, strKeyPath 
End Sub
