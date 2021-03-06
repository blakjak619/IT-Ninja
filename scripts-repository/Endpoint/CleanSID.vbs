'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to clear the sid-history of the given object
'Parameters - "-n=objectname" "-o=objectcategory" "-c=objectclass"
'Remarks -
'Configuration Type - USER
'==============================================================


Const ADS_PROPERTY_DELETE = 4

Dim strFilter 'As String
Dim oConnection 'As ADODB.Connection
Dim oRecordSet 'As ADODB.RecordSet
Dim strQuery 'As String
Dim strDomainNC 'As String
Dim oRootDSE 'As IADs
Dim vArray 'As Variant()
Dim vSid 'As Variant
Dim oDirObject 'As Variant

' Parse the command line and set the query filter
ParseCommandLine()

' Find the domain naming context
set oRootDSE = GetObject("LDAP://RootDSE")
strDomainNC = oRootDSE.Get("defaultNamingContext")
set oRootDSE = Nothing

' Setup the ADO connection
Set oConnection = CreateObject("ADODB.Connection")
oConnection.Provider = "ADsDSOObject"
oConnection.Open "ADs Provider"

strQuery = "<LDAP://" & strDomainNC & ">;" & strFilter & ";distinguishedName,objectClass,name,sidHistory;subtree"

'Execute the query
set oRecordSet = oConnection.Execute(strQuery)
if oRecordSet.Eof then
  WScript.Echo "No objects were found"
  WScript.Quit(0)
Else
  Dim vClasses 'As Variant
  Dim strClass 'As String

  WScript.Echo "The following objects were found:"

  'On Error Resume Next

  ' Iterate through the objects that match the filter
  While Not oRecordset.Eof
     vClasses = oRecordset.Fields("objectClass").Value
     strClass = vClasses(UBound(vClasses))
     WScript.Echo "Name: " & oRecordset.Fields("name").Value & "   Class: " & strClass & "  DN: " & oRecordset.Fields("distinguishedName").Value

     If IsNull(oRecordSet.Fields("sIDHistory").Value ) Then
        WScript.Echo "This object does not have a sidHistory"
     Else
	set oDirObject = GetObject("LDAP://" & oRecordset.Fields("distinguishedName").Value) 
        vArray = oDirObject.GetEx("sIDHistory")
        For Each vSid in vArray
         oDirObject.PutEx ADS_PROPERTY_DELETE, "sIDHistory", array(vSid) 
         oDirObject.SetInfo 
        Next
        WScript.Echo "The sidHistory has been cleared for this object!"
     End if
     
     oRecordset.MoveNext
  Wend
End if

'Clean up
Set oRecordset = Nothing
Set oConnection = Nothing
'=========================================================================================================================
' The ParseCommandLine subroutine will build the query filter base on the arguments passed to the script.  The bNameFlag
' is used so that the name given can have spaces in it.
'=========================================================================================================================
Sub ParseCommandLine()
   Dim vArgs, Value, Equals, I
   Dim bNameFlag 'As Boolean
   Dim strName 'As String
   Dim strObjectCategory 'As String
   Dim strObjectClass 'As String

   Set vArgs = WScript.Arguments
   if VArgs.Count < 1 Then
      DisplayUsage()
   End if

  bNameFlag = False
  For I = 0 to vArgs.Count - 1
      If Left( vArgs(I) , 1 ) = "/" Or Left( vArgs(I) , 1 ) = "-" Then

         Value = ""
         Equals = InStr( vArgs(I) , "=" )
         If Equals = 0 Then Equals = InStr( vArgs(I) , ":" )
         If Equals > 0 Then Value = Mid( vArgs(I) , Equals + 1 )

         Select Case LCase( Mid( vArgs(I) , 2 , 1) )

   		Case "n" strName = Value
			 bNameFlag = True  'This will allow us to catch spaces
   		Case "o" strObjectCategory = Value
			 bNameFlag = False
                Case "c" strObjectClass = Value
			 bNameFlag = False
		Case Else DisplayUsage

         End Select        	

     Else 'no dash or slash;  Check if we are giving a name
        if bNameFlag Then
           strName = strName & " " & vArgs(I)
        else
           DisplayUsage
        end if
     End if
   Next

'Should be okay to build filter  

If strName = "" Then
  WScript.Echo "A name parameter must be given"
  WScript.Quit(1)
Else
  strFilter = "(&(name=" & strName & ")"
  If Len(strObjectCategory) > 0 Then
     strFilter = strFilter & "(objectCategory=" & strObjectCategory & ")"
  End if
  If Len(strObjectClass) > 0 Then
     strFilter = strFilter & "(objectClass=" & strObjectClass & ")"
  End if

  strFilter = strFilter & ")" 'Close filter
End if
End Sub

'=========================================================================================================================
' The DisplayUsage subroutine will display how to use this script, the objectCategory and objectClass arguments are optional.
'=========================================================================================================================
Sub DisplayUsage()
 WScript.Echo "Usage csript.exe " & WScript.ScriptName & vbLF & _ 
     "-n=<name of the object you are looking for>" & vbLF & _
     "[-o=<objectCategory of the object you are looking for>]" & vbLF & _
     "[-c=<objectClass of the object you are looking for>]"  & vbLF & vbLF & _ 
	 "Examples : " & vbLF & _
	 WScript.ScriptName & " -n=My Contact" & vbLF & _
	 WScript.ScriptName & " -n=Computer1 -o=computer" & vbLF & _ 
	 WScript.ScriptName & " -n=James Smith -o=Person -c=user"
 WScript.Quit(0)

End Sub