'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - The script configures the data source name, i.e connects to the database
'Parameters -
'Remarks - The name, path, etc must be hard coded in the script.
'Configuration Type - COMPUTER
'==============================================================
Const HKEY_LOCAL_MACHINE = &H80000002

strComputer = "."
 
Set objReg=GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & _ 
    strComputer & "\root\default:StdRegProv")
 
strKeyPath = "SOFTWARE\ODBC\ODBC.INI\ODBC Data Sources"
objReg.CreateKey HKEY_LOCAL_MACHINE,strKeyPath
strValueName = "Script Repository"   ' Name of the connection
strValue = "SQL Server"
objReg.SetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue
 
strKeyPath = "SOFTWARE\ODBC\ODBC.INI\"&strValueName

objReg.CreateKey HKEY_LOCAL_MACHINE,strKeyPath

strKeyPath = "SOFTWARE\ODBC\ODBC.INI\"&strValueName

strValueName = "Database"
strValue = "Script Center"           ' Name of the actual database we want to connect to. In this example, the database is named Script Center.
objReg.SetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue
 
strValueName = "Driver"
strValue = "C:\WINDOWS\System32\SQLSRV32.dll"   'Path to SQL Server ODBC drive. In this example, that path is C:\WINDOWS\System32\SQLSRV32.dll
objReg.SetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue

strValueName = "Server"
strValue = "atl-sql-01"          ' Name of the server where the database is found
objReg.SetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue


strValueName = "Trusted_Connection"
strValue = "Yes"  'Tells SQL Server to use our logon credentials when we access the database. This enables us to connect to the database without having to supply a user name and password.
objReg.SetStringValue HKEY_LOCAL_MACHINE,strKeyPath,strValueName,strValue