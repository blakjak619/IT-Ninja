if( $SN_STATE_NEW -eq $null ) { Set-Variable -Name SN_STATE_NEW -Value 2 –option Constant }
if( $SN_STATE_AWAITRESP -eq $null ) { Set-Variable -Name SN_STATE_AWAITRESP -Value -5 –option Constant }
if( $SN_STATE_COMPLETE -eq $null ) { Set-Variable -Name SN_STATE_COMPLETE -Value 3 –option Constant }
if( $SN_STATE_CANCELLED -eq $null ) { Set-Variable -Name SN_STATE_CANCELLED -Value 4 –option Constant }
function ProcessServicePointSOAP{
param(
    [xml]$xml,
    [string]$table
)
    LLTraceMsg -InvocationInfo $MyInvocation
    $username = 'svc_opsbrain'
    $password = LSGet-AccountPwd -Account $username

    # You can see the list of parameters at https://bridgepoint.service-now.com/sc_req_item.do?WSDL
    # Other types of ServiceNow SOAP requests are:
    # https://bridgepoint.service-now.com/cmdb_ci_linux_server.do?SOAP)
    # https://bridgepoint.service-now.com/sc_req_item.do?SOAP)
    # https://bridgepoint.service-now.com/cmdb_ci_win_server.do?SOAP)
    # https://bridgepoint.service-now.com/sc_req_item.do?SOAP)
    # https://bridgepoint.service-now.com/change_task.do?SOAP)
    # https://bridgepoint.service-now.com/change_request.do?SOAP)
    # https://bridgepoint.service-now.com/task_ci_list.do?SOAP)
    # https://bridgepoint.service-now.com/cmdb_ci.do?SOAP)
    # https://bridgepoint.service-now.com/cmdb_ci_environment_list.do?SOAP)
    # https://bridgepoint.service-now.com/sys_user.do?SOAP)
    
    $uri = "$global:ServicePointUrl/$table.do?SOAP"


    # From an example at http://stackoverflow.com/questions/24050819/powershell-soap-for-servicenow
    $header = @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($username+":"+$password))}
    try {
        $post = Invoke-WebRequest -Uri $uri -Headers $header -Method Post -Body $xml -ContentType "application/xml" -ErrorAction SilentlyContinue
    } catch {
        LLToLog -EventID $LLERROR -Text "Error inserting CMDB record at $uri. Error was: $_.Exception"
    }
    if($post){
        $result_xml = [xml]$post.Content
        $resultarray = @($result_xml.Envelope.Body.getRecordsResponse.getRecordsResult)
        if($resultarray.Count -lt 1){
            return $false
        } else {
            return $resultarray
        }
    } else {
        return $false
    }
}
function GetRequestItems{
param(
    [xml]$xml
)
    LLTraceMsg -InvocationInfo $MyInvocation
    $paramHash = @{}
    $paramHash.Add("-xml",$xml)
    $paramHash.Add("-table","sc_req_item")

    ProcessServicePointSOAP @paramHash

}
function RobustGetCMDBCI{
param(
	[string]$fqdn
)

	$ci = GetCMDBCI -fqdn $fqdn
    if(-not $ci){
        #The problem is the CI can be either fqdn or shortname, and despite it's name $fqdn isn't necessarily fqdn, it could be the shortname.
        #If you couldn't find the CI by the given $fqdn then try with/with-out the domain (depending on what you have already tried)
        if($fqdn.IndexOf(".") -gt 0){ #fqdn was truly a Fully Qualified Domain Name
            $ciname = ($fqdn -split "\.")[0]
        } else {
            $ciname = ($fqdn + ".bridgepoint.local")
        }

        $ci = GetCMDBCI -fqdn $ciname
    }

	return $ci
}
function GetCMDBCI{
param(
    [string]$fqdn
)
    LLTraceMsg -InvocationInfo $MyInvocation
$xml = [xml]@"
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://www.service-now.com">
   <soapenv:Header/>
   <soapenv:Body>
      <getRecords>
         <name>$fqdn</name>
      </getRecords>
   </soapenv:Body>
</soapenv:Envelope>
"@

    foreach($table in "cmdb_ci_win_server_list","cmdb_ci_linux_server_list"){
        $paramHash = @{}
        $paramHash.Add("-xml",$xml)
        $paramHash.Add("-table",$table)

        $ci = ProcessServicePointSOAP @paramHash
        if($ci){
            return $ci
        }
    }

    return $false
}
function GetCMDBCIbyIP{
param(
    [string]$ip
)
    LLTraceMsg -InvocationInfo $MyInvocation
$xml = [xml]@"
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://www.service-now.com">
   <soapenv:Header/>
   <soapenv:Body>
      <getRecords>
         <ip_address>$ip</ip_address>
      </getRecords>
   </soapenv:Body>
</soapenv:Envelope>
"@

    foreach($table in "cmdb_ci_win_server","cmdb_ci_linux_server"){

        $ci = ProcessServicePointSOAP -xml $xml -table $table
        if($ci){
            return $ci
        }
    }

    return $false
}
function GetRITMID{
param([string]$RITM)
    LLTraceMsg -InvocationInfo $MyInvocation
$xml = [xml]@"
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://www.service-now.com/sc_req_item">
   <soapenv:Header/>
   <soapenv:Body>
      <getRecords>
         <number>$RITM</number>
      </getRecords>
   </soapenv:Body>
</soapenv:Envelope>
"@

    $returnval = ProcessServicePointSOAP -Table "sc_req_item" -xml $xml

    return $returnval.sys_id
}
function GetRITM{
param([string]$RITM)
    LLTraceMsg -InvocationInfo $MyInvocation
$xml = [xml]@"
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://www.service-now.com/sc_req_item">
   <soapenv:Header/>
   <soapenv:Body>
      <getRecords>
         <number>$RITM</number>
      </getRecords>
   </soapenv:Body>
</soapenv:Envelope>
"@

    $returnval = ProcessServicePointSOAP -Table "sc_req_item" -xml $xml

    return $returnval
}
function UpdateRITM{
param( [string]$RITM,
        [string]$Comment,
        [int]$State,
		[string]$Approval
)
    LLTraceMsg -InvocationInfo $MyInvocation
    if(-not $RITM){
        LLToLog -EventID $LLERROR -Text "RITM Number is required."
        return $false
    }

    $SOAPArgs = ""

    $SOAPArgs += "<sys_id>$RITM</sys_id>"

    if($Comment){
        $SOAPArgs += "<Comments>$Comment</Comments>"
    }

    if($State){
        $SOAPArgs += "<State>$State</State>"
    }

	if($Approval){
		$SOAPArgs += "<approval>$Approval</approval>"
	}

$xml = [xml]@"
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://www.service-now.com/sc_req_item">
   <soapenv:Header/>
   <soapenv:Body>
      <update>
$SOAPArgs
      </update>
   </soapenv:Body>
</soapenv:Envelope>
"@

    $returnval = ProcessServicePointSOAP -Table "sc_req_item" -xml $xml

    return $returnval
}
function SetCIActive{
param(
    [string]$CIID,
    [int]$state,
    [string]$table,
    [string]$comment
)
$xml = [xml]@"
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://www.service-now.com/sc_req_item">
   <soapenv:Header/>
   <soapenv:Body>
      <update>
        <sys_id>$CIID</sys_id>
        <u_active>$state</u_active>
        <comments>$comment</comments>
      </update>
   </soapenv:Body>
</soapenv:Envelope>
"@
    $status = ProcessServicePointSOAP -xml $xml -table $table
}
function AddCI{
param(
    [hashtable]$Params
)
    LLTraceMsg -InvocationInfo $MyInvocation

    #Update the comments field (Date, Action (New/Delete), RITM)
    $cdate = Get-Date -UFormat "%Y%m%d%H%M%S"
    $caction = "Created"
    $critm = $Request.Number
    $newcomment = "$cdate - $caction per $critm"

    if($Params.ContainsKey("name")){
        $fqdn = $Params.Get_Item("name")
    } else {
        LLToLog -EventID $LLWARN -Text "A valid server name must be provided to add a CI."
        return $false
    }

    if($Params.ContainsKey("os")){
        if($Params.Get_Item("OS") -like "windows*"){
            $table = "cmdb_ci_win_server_list"
        } else {
            $table = "cmdb_ci_linux_server_list"
        }
    } else {
        LLToLog -EventID $LLWARN -Text "You must provide an OS value when inserting into the CMDB"
        $returnval = $false
    }

    $ci = RobustGetCMDBCI -fqdn $fqdn
    if( $ci ){
        LLToLog -EventID $LLWARN -Text "A CI record for $fqdn was found in the Service-Now CMDB"
        SetCIActive -CIID $ci.sys_id -table $table -state 1 -comment "$($ci.comments)`n$newcomment"
        return $true
    }

    $returnval = $true

    $SOAPArgs = ""
    foreach($Param in $Params.GetEnumerator()){
        $SOAPArgs += "<"
        $SOAPArgs += $Param.Key
        $SOAPArgs += ">"
        $SOAPArgs += $Param.Value
        $SOAPArgs += "</"
        $SOAPArgs += $Param.Key
        $SOAPArgs += ">"
    }

    $xml = [xml]@"
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://www.service-now.com/sc_req_item">
   <soapenv:Header/>
   <soapenv:Body>
      <insert>
$SOAPArgs
        <comments>$newcomment</comments>
      </insert>
   </soapenv:Body>
</soapenv:Envelope>
"@

    $paramHash = @{}
    $paramHash.Add("-xml",$xml)
    $paramHash.Add("-table",$table)
    $status = ProcessServicePointSOAP -xml $xml -table $table

    #Adding a CI always returns a 500 error, even if successful.
    #Actually check to see if the CI got added.
        
    $citest = RobustGetCMDBCI -fqdn $fqdn
    if(($citest.sys_id).length -gt 4){
        LLToLog -EventID $LLVERBOSE -Text "Post ADDCI result for $fqdn is $($citest.sys_id)"
        return $true
    } else {
        LLToLog -EventID $LLWARN -Text "Failed to add CI"
        return $false
    }
}
function DeleteCI{
param(
    [string]$fqdn
)
    # Don't actually delete CI's. Just mark them inactive
    # Get the CI ID
    $ci = RobustGetCMDBCI -fqdn $fqdn

    #Update the comments field (Date, Action (New/Delete), RITM)
    $cdate = Get-Date -UFormat "%Y%m%d%H%M%S"
    $caction = "Deleted"
    $critm = $Request.Number
    $comments = $ci.comments
    $newcomment = "$comments`n$cdate - $caction per $critm"

$xml = [xml]@"
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://www.service-now.com">
   <soapenv:Header/>
   <soapenv:Body>
      <update>
        <sys_id>$($ci.sys_id)</sys_id>
        <u_active>0</u_active>
        <comments>$newcomment</comments>
      </update>
   </soapenv:Body>
</soapenv:Envelope>
"@

    ProcessServicePointSOAP -xml $xml -table $ci.sys_class_name
    
}
function GetAllCMDB{
    LLTraceMsg -InvocationInfo $MyInvocation
    $cilist = @()
    foreach($urlmod in "linux","win"){
        $returncnt = 999
        $prevsys_id = 0
        $startrow = 0
        $endrow = 250
        while($returncnt -ne 0){
            $xml = [xml]@"
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://www.service-now.com">
   <soapenv:Header/>
   <soapenv:Body>

      <getRecords >
      <__first_row>$startrow</__first_row>
      <__last_row>$endrow</__last_row>
      <__order_by>sys_id</__order_by>
      </getRecords>
   </soapenv:Body>
</soapenv:Envelope>
"@
            $uri = "https://bridgepointdev.service-now.com/cmdb_ci_${urlmod}_server.do?SOAP"
            $header = @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($credaccount+":"+$plainpwd))}
            $post = Invoke-WebRequest -Uri $uri -Headers $header -Method Post -Body $xml -ContentType "application/xml" -ErrorAction SilentlyContinue
            $result = [xml]$post.content
            $returncnt = $result.Envelope.body.getRecordsResponse.getRecordsResult.count
            foreach($ci in $result.Envelope.body.getRecordsResponse.getRecordsResult){
                $obj = New-Object PSObject
                $obj | Add-Member -type NoteProperty -Name Name -value $ci.name
                $obj | Add-Member -type NoteProperty -Name SubCategory -value $ci.subcategory
                $obj | Add-Member -type NoteProperty -Name UpdateDate -value $ci.sys_updated_on
                $obj | Add-Member -type NoteProperty -Name CreatedBy -value $ci.sys_created_by
                $cilist += $obj
            }

            $startrow += $returncnt
            $endrow += $returncnt

        } #while returncnt -ne 0
    } #foreach linux,win

    return $cilist
}

#region Unit Tests
if (($MyInvocation.Line -eq $null) -or ($MyInvocation.Line -notmatch "\. ")) {

	$LIBPATH = $env:ScriptLibraryPath
	. $LIBPATH\Includes\LIB-Includes.ps1 -DefaultLibraryPath $LIBPATH -Intentional
	LLInitializeLogging -LogLevel $LLTRACE
	

    $StartTime = Get-Date
    
    $RITMID = GetRITMID -RITM "RITM0121296"

    UpdateRITM -RITM $RITMID -Comment "Unit test of UpdateRITM" -State 3
    GetRITM -RITM "RITM0121296"

    Get-EventLog -LogName Application -After $StartTime | Sort-Object TimeGenerated | Format-Table -AutoSize -Wrap
}
#endregion