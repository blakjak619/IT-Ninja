'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to set multiple homepages in Internet Explorer
'Parameters -
'Remarks - The url for the home pages must be hard coded in the script
'Configuration Type - USER
'==============================================================

Const HKEY_CURRENT_USER = &H80000001

strComputer = "."

Set objReg = GetObject("winmgmts:\\" & strComputer & "\root\default:StdRegProv")

strKeyPath = "SOFTWARE\Microsoft\Internet Explorer\Main"
ValueName = "Start Page"
strValue = "http://www.microsoft.com/technet/scriptcenter/default.mspx"

objReg.SetStringValue HKEY_CURRENT_USER, strKeyPath, ValueName, strValue

ValueName = "Secondary Start Pages"

strValue1 = "http://yahoo.com"
strValue2 = "http://google.com"
arrValues = Array(strValue1, strValue2)

objReg.SetMultiStringValue HKEY_CURRENT_USER, strKeyPath, ValueName, arrValues