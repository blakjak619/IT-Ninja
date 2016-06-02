function LVGet_VM{
param( [string]$VMName,
        [string[]]$vCenter )

    LLTraceMsg -InvocationInfo $MyInvocation

    LVConnect-VIServer -vCenter $vCenter

    try {
        $vm = Get-VM $VMName -ErrorAction SilentlyContinue
    } catch {
        LLToLog -EventID $LLERROR -Text "Failed to get VM $VMName."
        return $false
    }
    Disconnect-VIServer -Server $vCenter -Confirm:$false

    return $vm

}
function LVConnect-VIServer{
param( [string]$vCenter )

    LLTraceMsg -InvocationInfo $MyInvocation

    $account = "svc_opsbrain"
    $password = LSGet-AccountPwd -Account $account

    #Disconnect any previous connections to avoid stale connections (they tend to just pile up in $DefauleVIServers if you fail to disconnect)
    foreach($vctr in $DefaultVIServers){
        if($vctr.name -eq $vCenter){
            Disconnect-VIServer $vctr.name -Confirm:$false -ErrorAction SilentlyContinue
        }
    }

	foreach($vctr in $vCenter){
		try{
			Connect-VIServer $vcenter -User $Account -Password $password -Force -ErrorAction Stop
		} catch {
			LLToLog -EventID $LLWARN -Text "Failed to access vcenter. vCenter path = [$vCenter]. Reason $_.Exception"
		}
	}

}