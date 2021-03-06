<# 
.SYNOPSIS
	BPE_msmq_monitor.ps1 is script to check DLQ and poison queues for a given host (currently set to localhost)
.DESCRIPTION
	
.NOTES  
	Author        : Albert Coba
	Assumptions   :
		Must be run by a user that has access to remote private queues for the given host
.OUTPUTS
    Write to Event Log with Queue information so that SCOM can pick up the event and alert off of it
#>

# add reference
$Assem = ( 
    "System.Messaging"
    ) 
# CSharp code
$source = @"
using System.Messaging;
namespace BPE.Enterprise.Common.MSMQ
{
	public class MSMQHelper
	{
		public static int GetMessageCount(string queuepath)
	    {
	        int count = 0;
	        // Get a specific MSMQ queue by name.
			try
			{
			    using(System.Messaging.MessageQueue q = new System.Messaging.MessageQueue(queuepath))
				{
			        System.Messaging.Message[] messages = q.GetAllMessages();
			        count = messages.Length;

			        // Return the tally.
			        return count;
				}
			}
			catch
			{
				return 0;
			}
	    }
		
		public static bool GetMSMQStatus(string queueName) {
			try
			{
	            using (var queue = new System.Messaging.MessageQueue(queueName)) 
				{
	                System.Messaging.Message latestMessage = PeekWithoutTimeout(queue); 
	                return (latestMessage != null ? true : false);
            	}
			}
			catch
			{
				return false;
			}
        }
		
		private static System.Messaging.Message PeekWithoutTimeout(System.Messaging.MessageQueue q) {
            System.Messaging.Message ret = null;
            try 
			{
                ret = q.Peek(new System.TimeSpan(1), q.CreateCursor(), PeekAction.Current);
            } 
			catch 
			{
                throw;                
            }
            return ret;
        }
	}
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies $Assem -Language CSharp
# custom enum
Add-Type -TypeDefinition @"
	public enum QueueType
	{
		MAIN,
		DLQ,
		JOURNAL,
		POISON,
		RETRY,		
		OTHER,
		SYSTEM
	}
"@


Function DetermineCluster { 
# Purpose: determine if this is a clustered MSMQ instance and perform queue operations accordingly
# returns: none; sets following script-level scoped variables
#     execMSMQ: execute or not (only perform ops on cluster if ownernode matches current name, or if not clustered)
#     cName   : the computer (or cluster) name to check for queues

    $script:execMSMQ = $true
    $script:srv = $Env:COMPUTERNAME

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
    $script:srv = $myCAP.ToUpper()
}

# responsible for logging events to event log
function LogQueueEvent
{	
	param($EventLogName, $Source, $EntryType, $EventID, $Text)
	
	# Check if Log exists
	if([System.Diagnostics.EventLog]::Exists($EventLogName) -eq $true)
	{
		# Check if Source exists
		if([System.Diagnostics.EventLog]::SourceExists($Source) -eq $false)
		{			
			# create new event log
			New-EventLog -LogName $EventLogName -Source $Source
		}
	}
	else
	{
		# create new event log
		New-EventLog -LogName $EventLogName -Source $Source
	}
	# write to event log
	Write-EventLog -LogName $EventLogName -Source $Source -EntryType $EntryType -EventId $EventID -Message $Text -ErrorAction Continue
}


# check an individual queue based on queue path, return count only if there are messages in it, else return 0
function CheckQueue
{
	param($queuePath)
	#Write-Host("`tAnalyzing : " + $queuePath)
	$hasMessage = [BPE.Enterprise.Common.MSMQ.MSMQHelper]::GetMSMQStatus($queuePath)
	if($hasMessage -eq $true)
	{				
		#Queue check
		$msgCount = [BPE.Enterprise.Common.MSMQ.MSMQHelper]::GetMessageCount($queuePath)					
		return $msgCount
	}
	return 0
}

# Get transactional dead letter queue count
Function CheckSystemQueue
{
	param($srv, $NumberOfMessages, $EventLogName, $EntryType, $EventID)
	
	$qPath = "formatname:DIRECT=OS:{0}\SYSTEM$;DEADXACT" -f $srv 
	$Source = "SYSTEM$;DEADXACT"
	
	Write-Host $qPath		
	$msgCount = CheckQueue($qPath)
	$queueType = [QueueType]::SYSTEM
		
	# if there are messages in queue then log them to event log
	if($msgCount -gt $NumberOfMessages) 
	{		
		if($srv -like "*SIS*" -Or $srv -like "*SPO*" )
		{
			$channel = "STUDENT"
		}
		elseif($srv -like "*SMK*" -Or $srv -like "*SMC*" -Or $srv -like "*SSV*" -Or $srv -like "*SEI*")
		{
			$channel = "LEAD"
		}	
        else
        {        
			$channel = "ALL"
        }			
		
		#write to event log
		$Text = "`nServer=[{0}]`nType=[{1}]`nQueuePath=[{2}]`nCount=[{3}]`nChannel=[{4}]`nSource=[{5}]"  -f $srv, $queueType, $qPath, $msgCount, $channel, $Source
		LogQueueEvent $EventLogName $Source $EntryType $EventID $Text
        Write-host $Text		
	}	
}

# Get all private queues for the host and iterate through each individually
Function CheckQueues
{
	param($srv, $NumberOfMessages, $EventLogName, $EntryType, $EventID)
	Write-Host("Checking : " + $srv)
	$Result = [System.Messaging.MessageQueue]::GetPrivateQueuesByMachine($srv)
	
	if ($Result -ne $null)
	{	
		foreach ($a in $Result)
		{
			$poisonQueue = $a.Path + ";poison"			
			$msgCount = 0
			$queueType = [QueueType]::MAIN
			$srcPath = $a.QueueName
			$path = $srcPath.Replace("private$\", "")
			
			#poison checks																			
			if($poisonQueue -notlike "*.dlq*")
			{										
				$msgCount = CheckQueue($poisonQueue)				
				$queueType = [QueueType]::POISON
				$idx = $path.IndexOf("`/")
				if($idx -gt 0)
				{
					$Source = $path.Substring(0, $idx)
				}
				else
				{
					$source = $path
				}
			}
			# dlq check
			else
			{					
				$msgCount = CheckQueue($a.Path)
				$queueType = [QueueType]::DLQ				
				$Source = $path.Replace(".dlq", "")				
			}
			
			# if there are messages in queue then log them to event log
			if($msgCount -gt $NumberOfMessages) 
			{	
				if($srv -like "*SIS*" -Or $srv -like "*SPO*" )
				{
					$channel = "STUDENT"
				}
				elseif($srv -like "*SMK*" -Or $srv -like "*SMC*" -Or $srv -like "*SSV*" -Or $srv -like "*SEI*")
				{
					$channel = "LEAD"
				}	
                else
                {        
					#Student
					foreach($queue in $json.Queues[0].Paths)
					{
						if($a.Path.Contains($queue))
	                    {
	                        $channel = "STUDENT"
	                    }
					}
					
					#Lead
					foreach($queue in $json.Queues[1].Paths)
					{
						if($a.Path.Contains($queue))
	                    {
	                        $channel = "LEAD"
	                    }
					}
                }			
							
				#write to event log
				$Text = "`Server=[{0}]`nType=[{1}]`nQueuePath=[{2}]`nCount=[{3}]`nChannel=[{4}]`nSource=[{5}]"  -f $srv, $queueType, $Path, $msgCount, $channel, $Source
				LogQueueEvent $EventLogName $Source $EntryType $EventID $Text
                Write-host $Text
			}
		}
	}	
}


# global variables
$messageLimit = 0
$aEventLogName = "BPILogs"
$aEntryType = "Warning"
$aEventID = 19021

#Write-Host $srv
$json = (Get-Content "C:\udeploy-agent\var\work\Powershell_Scripts\MSMQ\Queues.json" -Raw) | ConvertFrom-Json

DetermineCluster

#Write-host $execMSMQ
if (!$execMSMQ) 
{
	$srv = $($env:COMPUTERNAME).ToUpper()	
}

# script execution
CheckQueues $srv $messageLimit $aEventLogName $aEntryType $aEventID
CheckSystemQueue $srv $messageLimit $aEventLogName $aEntryType $aEventID


