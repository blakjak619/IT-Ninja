function ParseDescriptionToHash{
param( [PSObject]$Request )
    LLTraceMsg -InvocationInfo $MyInvocation
    # Each line in the description starts with "%"
    # 
    $paramsArray = $Request.description -split "%"
    $paramhash = @{}
    foreach($param in $paramsArray){
        if($param){
            $aName = ($param -split ":")[0]
            $aValue = (($param -split ":")[1])
            if($aValue){ $aValue = $aValue.trim() }
            $paramhash.Add($aName,$aValue)
         }
    }
    return $paramhash
}
function isValidRequest{
param( 
    [string]$task,
    [string]$fqdn,
    [string]$ip,
    [string]$RITMID
 )
    LLTraceMsg -InvocationInfo $MyInvocation

    $validRequest = $true
    #Get CI from CMDB
    $ci = RobustGetCMDBCI -fqdn $fqdn
	if($ci){
		LLToLog -EventID $LLVERBOSE -Text "A CI was found for $fqdn. u_active = $($ci.u_active)"
	} else {
		LLToLog -EventID $LLVERBOSE -Text "No CI was found for $fqdn."
	}
	
    $comment = ""

    LLToLog -EventID $LLVERBOSE -Text "Processing RITM $($Request.number) for $action server $fqdn"

    $ValidTaskTypes = "new","rebuild","delete"
    if(-not ($ValidTaskTypes -contains $task)){
        $Comment += "A valid task was not specified.`n" 
    }

    #If task = 'new' but a CI was found throw error to RITM
    if($task -eq "new" -and $ci -and $ci.u_active -ne 0){
        $Comment += "Cannot create a new server $fqdn, there is already an existing active CI.`n" 
    }


    #If task = 'new' but a valid IP was not provided; throw error to RITM
    $IPv4Regex = [regex]'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'

    if($task -eq "new" -and $IPv4Regex.Match($ip).Success -eq $false){
        $Comment += "Our apologies, currently OpsBrain cannot provide IP addresses. You must put in a ticket to get an IP address and then add that IP address to the description using %ip:&lt;ipaddress&gt;. Then change the ticket state to 'Active'.`n"
    }


    #If task = 'rebuild' and a CI or a VM was NOT found throw error to RITM
    if($task -eq "rebuild"){
        $vm = LVGet_VM -VMName $ci.host_name -vCenter $global:vCenterList
        if(-not $CI ){
            $Comment += "A CI was not found for $fqdn, unable to rebuild.  `n"
        }
        if(-not $VM ){
            $Comment += "A VM was not found for $fqdn, unable to rebuild.  `n"
        }
    }

    #If task = 'delete' and a VM was not found throw error to RITM
    if($task -eq "delete"){
        $vm = LVGet_VM -VMName $ci.host_name -vCenter $global:vCenterList

        if(-not $VM){
            $Comment += "A VM was not found for $fqdn, unable to delete.`n"
        } else {
            LLToLog -EventID $LLVERBOSE -Text "VM found $($VM.Name)"
        }
    }

    if($comment){
        LLToLog -EventID $LLVERBOSE -Text "Invalid RITM because: $comment"
$xml = [xml]@"
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://www.service-now.com/sc_req_item">
   <soapenv:Header/>
   <soapenv:Body>
      <update>
         <sys_id>$RITMID</sys_id>
         <comments>$comment</comments>
         <state>$SN_STATE_AWAITRESP</state>
      </update>
   </soapenv:Body>
</soapenv:Envelope>
"@
        LLToLog -EventID $LLINFO -Text "Updating RITM $RITMID with comment: $comment"
        $result = ProcessServicePointSOAP -xml $xml -table "sc_req_item" 
        $validRequest = $false
    } else {
        LLToLog -EventID $LLVERBOSE -Text "RITM $($Request.Number) for $action $fqdn is a valid request."
    }
    return $validRequest
}
function ConvertIP2MAC{
param( [string]$os,
       [string]$ip 
)
    LLTraceMsg -InvocationInfo $MyInvocation
    if($os -like "Windows*"){
        $mac = 'BE-EF-EE-'
    } else {
        $mac = 'C0-FF-EE-'
    }

    $ipArray = $ip -split "\."
    try{
        $hexvals = "{0:X2}-{1:X2}-{2:X2}" -f [int]$ipArray[1],[int]$ipArray[2],[int]$ipArray[3]
    } catch {
        LLToLog -EventID $LLWARN -Text "Unable to convert IP to MAC address: $_.Exception"
        return $false
    }

    $mac += $hexvals
    LLToLog -EventID $LLINFO -Text "Calculated MAC address is $mac"
    $MACRegex = [regex]'([0-9A-Fa-f]{2}[-:]){5}[0-9A-Fa-f]'
    if($MACRegex.match($mac).Success){
        return $mac
    } else {
        return $false
    }


}
function AssembleCIData{
param(
    [hashtable]$paramhash
)
    LLTraceMsg -InvocationInfo $MyInvocation

    $CIHash = @{}
    
    if($paramhash.ContainsKey("hostname")){
        $oci = OPB_GetCMDBCI -fqdn $paramhash.Get_Item("hostname")
        $CIHash.Add("default_gateway",$oci.opb_default_route)
    }

    $CIHash.Add("number",$paramhash.Get_Item("number"))
    $CIHash.Add("cpu_core_count",$paramhash.Get_Item("cpu_socket"))
    $CIHash.Add("cpu_count",$paramhash.Get_Item("cpu_core"))

    $CIHash.Add("disk_space",$paramhash.Get_Item("disk"))
    if($paramhash.ContainsKey("hostname")){
        $namearray = $paramhash.Get_Item("hostname") -split "\."
        $shortname = $namearray[0]
        $hostname = $paramhash.Get_Item("hostname")
        if(-not $hostname.Contains(".")){
            $hostname = ($hostname,$paramhash.Get_Item("domain")) -join "."
        }
    }
    $CIHash.Add("host_name",$shortname)
    $CIHash.Add("name",$paramhash.Get_Item("hostname"))
    $CIHash.Add("os",$paramhash.Get_Item("operating_system"))
    #$CIHash.Add("os_domain",$paramhash.Get_Item("domain"))
    if( (-not $paramhash.Get_Item("domain")) -or $paramhash.Get_Item("domain").IndexOf(".") -lt 1){

        $hostarray = $hostname -split "\."
        $domain = $hostarray[1]
        for($i=2;$i -lt $hostarray.Count;$i++){
            $domain = ($domain,$hostarray[$i]) -join "."
        }
        $CIHash.Set_Item("os_domain", $domain)
    }
    $CIHash.Add("dns_domain",$domain)
    $CIHash.Add("ram",$paramhash.Get_Item("mem"))
    $CIHash.Add("ip_address",$paramhash.Get_Item("ip"))

    switch($paramhash.Get_Item("hostname")[0]){
        "d" { $CIHash.Add("used_for","dev") }
        "q" { $CIHash.Add("used_for","qa") }
        "l" { $CIHash.Add("used_for","Load Testing") }
        "s" { $CIHash.Add("used_for","staging") }
        "t" { $CIHash.Add("used_for","tools") }
        "p" { $CIHash.Add("used_for","prod") }
        "r" { $CIHash.Add("used_for","Disaster recovery") }
    }
    $mac = ConvertIP2MAC -os $paramhash.Get_Item("operating_system") -ip $paramhash.Get_Item("ip")
    if($mac){
        $CIHash.Add("mac_address",$mac)
    } else {
        return $false
    }

    return $CIHash
}
function CallProvisioner{
param(
    [string]$action,
    [string]$fqdn,
    [string]$os_type
)
    LLTraceMsg -InvocationInfo $MyInvocation

    $RITMID = GetRITMID -RITM $Request.Number

    
    LLToLog -EventID $LLINFO -Text "Starting $action of server $fqdn."
    try {
		if([Environment]::Is64BitProcess){
			$retval = Invoke-Expression "c:\windows\SysWow64\WindowsPowershell\v1.0\Powershell.exe -file d:\scripts\opsbrain\opb_build_vm.ps1 -fqdn $fqdn -task_type $action -system_type $os_type -LogLevel $LogLevel" -ErrorAction Stop
		} else {
			$retval = d:\scripts\opsbrain\opb_build_vm.ps1 -fqdn $fqdn -task_type $action -system_type $os_type -LogLevel $LogLevel -ErrorAction Stop
		}
    } catch {
        LLToLog -EventID $LLERROR -Text "FAILED: $action action for server $fqdn. Reason: $_.Exception"
        UpdateRITM -RITM $RITMID -Comment "$action action for server $fqdn. Reason: $_.Exception" -State $SN_STATE_AWAITRESP
        return $false
    }

    return $true
}
function OPB_GetCMDBCI{
param(
    [string]$fqdn
)
    LLTraceMsg -InvocationInfo $MyInvocation
    $username = 'svc_opsbrain'
    $password = LSGet-AccountPwd -Account $username

    $header = @{"Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($username+":"+$password))}
    $url = "http://$global:opbwebservice/opsbrain/cmdb/$fqdn/json?q=powershell"
    try {
        Invoke-WebRequest -Uri $url -Headers $header -Method Post  -ErrorAction SilentlyContinue | ConvertFrom-Json
    } catch {
        Write-Host "Clean: $_.Exception"
    }
}
function GetValidOpsBrainRequests{

    LLTraceMsg -InvocationInfo $MyInvocation

        # This xml will get unprocessed OpsBrain RITM requests
$xml = [xml]@"
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:u="http://www.service-now.com/sc_req_item">
   <soapenv:Header/>
   <soapenv:Body>
      <getRecords>
         <state>2</state>
         <active>1</active>
         <stage>request_approved</stage>
         <approval>approved</approval>
         <subcategory>Add/Change</subcategory>
         <short_description>Environment Provisioning</short_description>
      </getRecords>
   </soapenv:Body>
</soapenv:Envelope>
"@

    $requestArray = @(GetRequestItems -xml $xml)
    $returnArray = @()

    if($requestArray){
        LLToLog -EventID $LLVERBOSE -Text "$($requestArray.Count) requests returned."
        foreach($Request in $requestArray){
            $RequestHash = ParseDescriptionToHash -Request $Request

            $action = $null
            $fqdn = $null

            if($RequestHash.ContainsKey("task")){
                $action = $RequestHash.Get_Item("task")
            }
            if($RequestHash.ContainsKey("hostname")){
                $fqdn = $RequestHash.Get_Item("hostname")
            }
            if($RequestHash.ContainsKey("ip")){
                $rip = $Requesthash.Get_Item("ip")
            }
            if(isValidRequest -task $action -fqdn $fqdn -ip $rip -RITMID $Request.sys_id ){
                LLToLog -EventID $LLVERBOSE -Text "$action for $fqdn is a valid request."
                $returnArray += $Request
            }
        }
    } else {
        LLToLog -EventID $LLVERBOSE -Text "No requests returned."
    }

    return $returnArray
}
function AssignIP{
param( [string]$fqdn )
    LLTraceMsg -InvocationInfo $MyInvocation
    #Get the opb_cmdb_ci
    $cijson = OPB_GetCMDBCI -fqdn $fqdn
    #If it has opb_default_route and opb_netmask
    if($cijson.opb_default_route -and $cijson.opb_netmask){
        
    #Get a list of IP from Get-IPrange
        $rangeArray = @(Get-IPrange -ip $cijson.opb_default_route -mask $cijson.opb_netmask)
    #For each IP check the cmdb to see if there is a CI with that IP
        foreach($potentialIP in $rangeArray){
    #If IP not in cmdb then return that IP to caller
            $result = GetCMDBCIbyIP $potentialIP
            if(-not $result){
                return $IP
            }
        }
    }
}
function FinalizeJobs{
    LLTraceMsg -InvocationInfo $MyInvocation
    $JobList = Get-Job | Where-Object {$_.State -ne "Running"}
    foreach($Job in $JobLIst){
        $JobResult = Receive-Job $Job.Id
        LLToLog -EventID $LLINFO -Text "$($Job.Name) terminated with these results $JobResult"
        Remove-Job $Job.Id
    }
}
function isJoinedtoDomain{
param([string]$vm)
    
    LLTraceMsg -InvocationInfo $MyInvocation
    if ($(Get-ADComputer "$vm" -ErrorAction SilentlyContinue).distinguishedName){
        return $true
    } else {
        return $false
    }
}
function WaitForServerToJoinDomain{
param([string]$fqdn)

    LLTraceMsg -InvocationInfo $MyInvocation

    $ci = OPB_GetCMDBCI -fqdn $fqdn
    $vm = $ci.host_name

    Import-Module ActiveDirectory

    $EndTime = (Get-Date).AddHours(1)

    while((Get-Date) -lt $EndTime){
        if(-not (isJoinedtoDomain -vm $vm)){
            LLToLog -EventID $LLINFO -Text "Still waiting for $fqdn to join the domain"
            Start-Sleep 600
        } else {
            LLToLog -EventID $LLINFO -Text "$fqdn has joined the domain."
            return $true
        }
    }
    return $false
}
function VerifyNetworkAccess{
param([string]$ip)
    if(Test-Connection $ip -Quiet){
        LLToLog -EventID $LLINFO -Text "$ip is on the network"
        return $true
    } else {
        LLToLog -EventID $LLWARN -Text "$ip was not reachable"
        return $false
    }
        
}
function ForceDomainJoin{
param([string]$fqdn)
    $ci = OPB_GetCMDBCI -fqdn $fqdn
    $username = 'svc_opsbrain'
    $password = LSGet-AccountPwd -Account $username
    $SecurePwd = $password | ConvertTo-SecureString -AsPlainText -Force
    $vcreds = New-Object System.Management.Automation.PSCredential -ArgumentList "bridgepoint\svc_opsbrain", $SecurePwd
    try{
        Add-Computer -DomainName $ci.os_domain -ComputerName $ci.ip_address -Credential $vcreds -Restart -Force -Confirm:$False -ErrorAction Stop
        LLToLog -EventID $LLINFO -Text "Add-Computer $fqdn to domain $($ci.os_domain) did not error out"
    } catch {
        LLToLog -EventID $LLERROR -Text "Add-Computer $fqdn to domain $($ci.os_domain) errored out with $_.Exception"
    }
}
function ValidateServer{
param(  [string]$fqdn,
        [string]$action,
        [string]$os
)

    LLTraceMsg -InvocationInfo $MyInvocation

	$retval = $false

    $ci = OPB_GetCMDBCI -fqdn $fqdn
    if(-not $ci){
        LLToLog -EventID $LLWARN -Text "Unable to find CI for $fqdn"
        return $false
    }
    
    $RITMID = GetRITMID -RITM $Request.Number

    # Connect to the VI Center
    $vcenter = ($ci.opb_vm_endpoint -split "/")[0]
    $result = LVConnect-VIServer -vCenter $vcenter

    $vm = Get-VM $ci.host_name -ErrorAction SilentlyContinue
    if($action -eq "new" -or $action -eq "rebuild"){
        if(-not $vm){
            LLToLog -EventID $LLWARN -Text "VM for $fqdn was not created."
            $result = UpdateRITM -RITM $RITMID -Comment "$action server $fqdn action failed." -State $SN_STATE_AWAITRESP
            return $false
        }
		$EndTime = (Get-Date).AddHours(2)
        while($vm.Guest.IPAddress -ne $ci.IP_Address -and (Get-Date) -lt $EndTime){
            LLToLog -EventID $LLVERBOSE -Text "Still waiting for IP $($ci.IP_Address) on $fqdn to get set."
            Start-Sleep -Seconds 300
            $vm = Get-VM $ci.host_name
        }

        if($vm.Guest.IPAddress -ne $ci.IP_Address){
            LLToLog -EventID $LLWARN -Text "OSCustomization did not take for $fqdn."
        } else {
            if(VerifyNetworkAccess -ip $ci.ip_address){
                $winpatt = [regex]'[Ww]indows.*'
                if($winpatt.Match($os).Success){
                    if(WaitForServerToJoinDomain -fqdn $fqdn) {
                        $result = UpdateRITM -RITM $RITMID -Comment "$action server $fqdn action completed." -State $SN_STATE_COMPLETE 
						$retval = $true
                    } else {
                        LLToLog -EventID $LLERROR -Text "FAILED: $action action for server $fqdn. Reason: server failed to join domain"
                        LLToLog -EventID $LLINFO -Text "Attempting to force domain join"
                        $result = ForceDomainJoin -fqdn $fqdn
                    }
                } else {
					$retval = $true
				}
            }
        }
    }

    if($action -eq "delete"){
        if(-not $vm){
            $result = DeleteCI -fqdn $fqdn
            $result = UpdateRITM -RITM $RITMID -Comment "$action server $fqdn action completed." -State $SN_STATE_COMPLETE
			$retval = $true
        } else {
            LLToLog -EventID $LLERROR -Text "FAILED: $action action for server $fqdn. Reason: server still exists in vCenter $vcenter"
            $result = UpdateRITM -RITM $RITMID -Comment "$action server $fqdn action failed." -State $SN_STATE_AWAITRESP
        }
    }
    $result =Disconnect-VIServer -Server $vcenter -Confirm:$false

	return $retval
}
function SCOMAgentInstall{
param(
	[string]$fqdn,
	[string]$ScriptHome
)
	$ComputerName = ($fqdn -split ("\."))[0]

	$scriptpath = "$ScriptHome\SCOM\SCOMAgentInstall.ps1"

	if(Test-Path $scriptpath){
		&$scriptpath -ComputerName $ComputerName
	} else {
		LLToLog -EventID $LLWARN -Text "Unable to find SCOM Agent Install Script at $scriptpath"
	}
}
function uDeployAgentInstall{
param(
	[string]$fqdn
)
	$scbl = {
		robocopy  \\10.13.0.206\uDeploy_repository\udsource\Windows\Agent\Scripts c:\scripts

		if (!(gwmi Win32_Product | ? {$_.name -like "*Java*"})) {
			.\PS_UDeploy_Install_Java.ps1
		}
		.\PS_UDeploy_AgentInstall.ps1
	}

	$CredUser = "svc_opsbrain"
	$CredPwd = LSGet-AccountPwd -Account $CredUser
	$SecurePwd = $CredPwd | ConvertTo-SecureString -AsPlainText -Force
	$Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $CredUser, $SecurePwd
	invoke-command -ComputerName $fqdn -ScriptBlock $scbl -Credential $Cred
}