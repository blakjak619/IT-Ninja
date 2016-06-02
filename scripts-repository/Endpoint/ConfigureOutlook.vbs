'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to Import the outlook profile using PRF file 
'Parameters - "<Profile location share path>" "<profile name>"
'Remarks -
'Configuration Type - USER
'==============================================================

Option Explicit

Dim  PRFLocation, ProfileName

'PRFLocation = "c:\test.prf"         ' 
PRFLocation = WScript.Arguments.Item(0) ' OF THE PRF THAT HAS BEEN CREATE
ProfileName = WScript.Arguments.Item(1)   
      ' 
' =========================================
' =========================================

' =================DO NOT EDIT ANYTHING BELOW THIS SECTION================
' ========================================================================

Set WshShell = CreateObject("WScript.Shell")
Dim HKCUprofile 
HKCUprofile = "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Windows Messaging Subsystem\Profiles\" & ProfileName &"\"
Dim WshShell,  MSOKey, NoProfile ,OutlookInstalled
Dim strOfficePath, OfficePathWithParams,Outlooklocregpath
Outlooklocregpath = "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\OUTLOOK.EXE\path"

' ============== START OF MAIN SCRIPT ==============

' =========================================
'Test to see if the script has run before
' ========================================= 

 TestProfile 
 If NoProfile then 'Set up profile if none exists
	GetOutlookPath
	If OutlookInstalled then
		OutlookSetup 'Setup Outlook profile
	End if
 End if

' ================================================
' ============== END OF MAIN SCRIPT ==============
' ================================================


'------------ Test if profile exists?
Sub TestProfile
 on error resume next 'cannot be read first time
 MSOKey = WshShell.RegRead(HKCUprofile)
' determine if a profile has already been setup 
  If Err.Number = 0 Then
   'wscript.echo "Profile exists" 'Testing
   NoProfile = False
  else
  'wscript.echo "No Profile" 'Testing
   NoProfile = True
  end if
  On Error Goto 0
End sub

'----------- get outlook profile path
Sub GetOutlookPath
 on error resume next
strOfficePath = WshShell.RegRead(Outlooklocregpath)
' determine if outlook installed
  If strOfficePath = "" Then
  ' wscript.echo "Outlook not installed" 'Testing
   OutlookInstalled= false
  else
  ' wscript.echo "Outlook exists" 'Testing
     OutlookInstalled= true
  end if
  On Error Goto 0
End Sub
Sub OutlookSetup
		OfficePathWithParams = chr(34)&strOfficePath&"outlook.exe"&chr(34)&" /importprf "&chr(34)&PRFLocation&chr(34)
		'wscript.echo OfficePathWithParams
	    WshShell.Run  OfficePathWithParams, 1, False
End Sub

Sub Cleanup
 Set objSysInfo = Nothing
 Set strOfficePath = Nothing
 Set OfficePathWithParams = Nothing 
 Set Outlooklocregpath = Nothing
End Sub