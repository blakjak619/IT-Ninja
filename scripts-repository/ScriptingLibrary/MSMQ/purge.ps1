[Reflection.Assembly]::LoadWithPartialName("System.Messaging") | out-null # Load External DLL 



Function DetermineCluster { 
# Purpose: determine if this is a clustered MSMQ instance and perform queue operations accordingly
# returns: none; sets following script-level scoped variables
#     execMSMQ: execute or not (only perform ops on cluster if ownernode matches current name, or if not clustered)
#     cName   : the computer (or cluster) name to check for queues

    $script:execMSMQ = $true
    $script:cName = $Env:COMPUTERNAME

    # cluster?
    try  { 
        $clresource = Get-ClusterResource 
         } catch [exception] { return }

    # filter on MSMQ, get the Client Access Point (CAP) name
    $myCAP =  ($clresource -match "MSMQ").OwnerGroup.name
    $onode = Get-ClusterGroup
    $matchnode = $onode -match "$myCAP"
    # ensure that the current host is the ownernode, otherwise we do no MSMQ ops
    if ($matchnode.OwnerNode.name -ne $env:COMPUTERNAME.tolower() ) { 
        $script:execMSMQ = $false
        return 
    }
    # reference http://technet.microsoft.com/en-us/library/hh405007(v=vs.85).aspx
    $env:_CLUSTER_NETWORK_NAME_ = $myCAP
    $script:cName = $myCAP
}


# 
DetermineCluster
if (!$execMSMQ) { exit 0 } 

$msmq = [System.Messaging.MessageQueue] # Get msmq object 
foreach($mainQueue in $msmq::GetPrivateQueuesByMachine("$cName")) # Loop through each private queue 
{
    $journalQueue = New-Object -TypeName "System.Messaging.MessageQueue" # Create queue object
    $journalQueue.Path = (".\" + $mainQueue.QueueName + ";Journal") # Set path to journal of queue
    $journalQueue.Purge() # Purge queue
}