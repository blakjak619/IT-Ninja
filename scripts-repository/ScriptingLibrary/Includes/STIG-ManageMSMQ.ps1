# MSMQ functionality
# IMPORTANT: all Queue management related functions must contain the following scriptblock for clustered MSMQ
#            to determine if cluster and ensure MSMQ can continue
<#
DetermineCluster
if (!$execMSMQ) { return } 
#>

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

    # filter on ResourceType -eq MSMQ, get the Client Access Point (CAP) name
    $myCAP = @()
	foreach($Resource in $clresource){
		if($Resource.ResourceType.Name -eq "MSMQ"){
			$myCAP += $Resource.OwnerGroup.name
		}
	}
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


# provide:
#  User (the user to alter the system msmq perms for)
#  ACE Access Control Entry (Allow, Deny, Revoke) 
#  Right (the right to add)
# return: the service to restart (if needed)
Function AlterMSMQSystemPerms {
param(
	[string]$User,
	[string]$ACE,
	[string]$Right
)

	DetermineCluster

	if (!$execMSMQ) { return } 
    # does this need to be applied?
    if (((Get-MsmqQueueManagerACL | Where-Object {$_.AccountName -eq $User}).RightType -contains $Right -eq "True")  -and $ACE -ne "Remove" ) {
         if ($LoggingCheck) {ToLog -LogFile $LFName  -Text "INFO:: [AlterMSMQSystemPerms] `'$ACE`' `'$Right`' for `'$User`' already exists, skipping!" }
         return
    }
    # apply
	switch($ACE) {
		"Allow" { $quiet = Set-MsmqQueueManagerACL -UserName $User -Allow $Right }
		"Deny"  { $quiet = Set-MsmqQueueManagerACL -UserName $User -Deny $Right }
        "Remove"  { $quiet = Set-MsmqQueueManagerACL -UserName $User -Remove $Right }
		Default { if ($LoggingCheck) {ToLog -LogFile $LFName -EventID 3 -Text "ACE for AlterMSMQSystemPerms was not Allow, Deny or Remove, it was `'$ACE`'" }
                  return }
	}
    
      
    # this validates the ACLs adjust
    if ((Get-MsmqQueueManagerACL | Where-Object {$_.AccountName -eq $User}).RightType -contains $Right -ne "True") {
        if ($LoggingCheck -and $ACE -ne "Remove") {
            ToLog -LogFile $LFName -EventID 3 -Text "FAILURE:: AlterMSMQSystemPerms could not apply `'$ACE`' `'$Right`' for `'$User`'" 
            return $restartService
            }
        }
    if ($LoggingCheck) {ToLog -LogFile $LFName -Text "Successfully set `'$ACE`' `'$Right`' for `'$User`'" }
    # return the service to restart
    return "MSMQ"
   
}


Function AlterMSMQPerms {
# Adjust Permissions -
# http://msdn.microsoft.com/en-us/library/x58dfx7z.aspx
param([string]$User, `
[String]$Queue, `
[String]$Public, `
# http://msdn.microsoft.com/en-us/library/system.messaging.accesscontrolentrytype.aspx
# "Allow", "Set", "Deny", "Revoke"
[String]$ACE, `
# http://msdn.microsoft.com/en-us/library/system.messaging.messagequeueaccessrights.aspx
# "DeleteMessage", "PeekMessage", "WriteMessage", "DeleteJournalMessage", "SetQueueProperties", 
# "GetQueueProperties", "DeleteQueue", "GetQueuePermissions", "ChangeQueuePermissions", "TakeQueueOwnership", 
# "ReceiveMessage", "ReceiveJournalMessage", "GenericRead", "GenericWrite", "FullControl"
[String]$Rights)

$Usage = @"
#-------------------------------------------------------------------------
# Solution: AlterMSMQPerms
# Author: Sly Stewart 
# Updated: 12/07/2012
# Version: 1.1
<#
# Description: Alter permissions on an existing MSMQ queue.

- Mandatory Parameters
	[String]-User: User to adjust permissions for. "DOMAIN\USER"
	[String]-Queue: Name of the queue to create. Defaults to private queue unless `'-Public`' is used.
	[String]-ACE: Access Control entry. "Allow" | "Set" | "Deny" | "Revoke"
	[String]-Rights: MessageQueue access rights to grant:
	
"DeleteMessage" | "PeekMessage" | "WriteMessage" | "DeleteJournalMessage" | "SetQueueProperties" | 
"GetQueueProperties" | "DeleteQueue" | "GetQueuePermissions" | "ChangeQueuePermissions" | "TakeQueueOwnership" | 
"ReceiveMessage" | "ReceiveJournalMessage" | "GenericRead" | "GenericWrite" | "FullControl"

- Optional Parameters
	[String]-Public: Alters permissions on a Public queue instead of a Private queue.


#
# Usage:
# - AlterMSMQPerms -Queue "Points" -Public -User "BAD-TEAMS\Raiders" -ACE "Deny" -Rights "FullControl"
#	## Apply Deny "Full Control" permissions to the user "BAD-TEAMS\Raiders" on the "Points" MSMQ Queue.


# - AlterMSMQPerms -Queue "SDPadres" -User "HallOfFame\TGwynn" -ACE "Allow" -Rights "WriteMessage"
	## Apply Allow "Write Message" permissions to the user "HallOfFame\TGwynn" on the "SDPadres" MSMQ Queue.
	
# - AlterMSMQPerms -Queue "SDPadres" -User "SDPadres\THoffman" -ACE "Allow" -Rights "WriteMessage,ReceiveMessage,DeleteQueue,SetQueueProperties"
	## Apply Allow "Write Message, Receive Message, Delete Queue, Set Queue Properties" permissions to the user "SDPadres\THoffman" on the "SDPadres" MSMQ Queue.
	
# Revision History
# Version 1.0 - Initial Commit
# Version 1.1 - Added the ability to grant several permissions in one shot. - SS
#-------------------------------------------------------------------------

"@

    DetermineCluster
    if (!$execMSMQ) { return } 

    $ValidACE = @("Allow", "Set", "Deny", "Revoke")
    $ValidRight = @("DeleteMessage", "PeekMessage", "WriteMessage", "DeleteJournalMessage",`
    "SetQueueProperties", "GetQueueProperties", "DeleteQueue", "GetQueuePermissions", "ChangeQueuePermissions",`
    "TakeQueueOwnership", "ReceiveMessage", "ReceiveJournalMessage", "GenericRead", "GenericWrite", "FullControl")

    if ($PSBoundParameters.Count -eq 0) {
	    Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	    if ($LoggingCheck) {
		    ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to AlterMSMQPerms"
	    }
	    throw
    }
    if ((!$User) -or (!$Queue) -or (!$ACE) -or (!$Rights)) {
	    Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	    if ($LoggingCheck) {
		    ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to AlterMSMQPerms"
	    }
	    throw
    }
    if ($ValidACE -notcontains $ACE) {
	    Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	    if ($LoggingCheck) {
		    ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to AlterMSMQPerms"
	    }
	    throw
    }
    #Allow for a collection of rights in one shot.
    if ($Rights | Select-String ",") {
	    #Rights given are a collection.
	    #Remove any spaces.
	    $Rights = $Rights.Replace(" ", "")
	    $RightArray = $Rights.Split(",")
    } else {
	    $RightArray = @()
	    $RightArray += $Rights
    }
    foreach ($Right in $RightArray) {
	    if ($ValidRight -notcontains $Right) {
		    Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		    if ($LoggingCheck) {
			    ToLog -LogFile $LFName -Text "FAILURE:: Invalid Right: `'$Right`'"
		    }
		    throw "Invalid Right: `'$Right`'"
	    }
    }

	if ($Public -eq "True") {
		[string]$QueuePath = ".\$Queue"
	} else {
		[string]$QueuePath = ".\private`$\$Queue"
	}
	
	

	Add-Type -AssemblyName "System.Messaging" | Out-Null
	
	if ([System.Messaging.MessageQueue]::Exists("$QueuePath")) {
		$QueueObj = New-Object System.Messaging.MessageQueue("$QueuePath")

		do {
			Start-Sleep -Seconds 5
			$QueueID = $QueueObj.ID
		} while (!$QueueID)
			$QueueNM = $QueueObj.QueueName
		
		try {
			foreach ($RightKW in $RightArray) {
				$QueueObj.SetPermissions($User, $RightKW, $ACE)
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "Successfully set `'$User`' permissions on `'$QueuePath`'"
				}
			}
		} catch [Exception] {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: There was an issue setting `'$ACE`' `'$Rights`' permissions for `'$User`' on `'$QueueNM`'. $_"
			}
			Write-Host "There was an issue setting `'$ACE`' `'$Rights`' permissions for `'$User`' on `'$QueueNM`'. `n $_"
		}

		$QueueObj.Close()
	} else {
		#Queue does not exist.
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: The Specified Queue `'$Queue`' Does not exist!."
		}
		Write-Host "The Specified Queue `'$Queue`' Does not exist!."
		throw
	}

}

Function CreateMSMQ {
	Param([String]$QueueName, `
	[String]$Public, `
	#MaxJournalSize in KB
	[int]$MaxJournalSize, `
	[String]$Transactional, `
#	[String]$Permissions, `
	[String]$Authenticated, `
	[string]$EncryptionRequired, `
	#MaxQueueSize in KB
	[int]$MaxQueueSize, `
	[String]$EnableJournal)

$Usage = @"
#-------------------------------------------------------------------------
# Solution: CreateMSMQ
# Author: Sly Stewart 
# Updated: 5/29/2013
# Version: 1.2
<#
# Description: Create an MSMQ Queue.

- Mandatory Parameters
	[String]-QueueName: Name of the queue to create. Defaults to private queue unless `'-Public`' is used.

- Optional Parameters
	[String]-Public: Creates a Public queue instead of a Private queue.
	[int]-MaxJournalSize: Sets the maximum size of the journal queue in Kb.
	[String]-Transactional: Creates a queue that only accepts transactions
	[String]-Authenticated: Sets the queue to only accept authenticated messages.
	[string]-EncryptionRequired: Sets the queue to only accept non-private (non-encrypted) messages.
	[int]-MaxQueueSize: Sets the maximum size of the queue.
	[String]-EnableJournal: Sets the queue to be Journaled.

#
# Usage:
# - CreateMSMQ -QueueName "SDChargers"
#	## Creates a private queue named "SDChargers" 


# - CreateMSMQ -QueueName "Padres" -Public -Transactional -MaxQueueSize 7000
#	## Creates a public queue named "Padres" with the following properties:
		## Transactional
		## Maximum size of the queue is 7000 Kb.
#>
# Revision History
# Version 1.0 - Initial Commit. -SS 12/05/2012
# Version 1.1 - If the Queue already exists, dont throw, just exit quietly. -SS 2/28/2013
# Version 1.2 - Fixed minor bug with EncryptionRequired. -SS 5/29/2013
#-------------------------------------------------------------------------

"@
    DetermineCluster
    if (!$execMSMQ) { return } 

	if ($PSBoundParameters.Count -eq 0) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to CreateMSMQ"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
	}
	if (!$QueueName) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to CreateMSMQ (QueueName)"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
	}

	$ValidEncryption = @("None", "Body", "Optional")
	if ($EncryptionRequired) {
		if ($ValidEncryption -notcontains $EncryptionRequired) {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to CreateMSMQ (EncryptionRequired)"
			}
				Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
				throw
		} else {
			$EREnabled = $true
		}
	}


	Add-Type -AssemblyName "System.Messaging" | Out-Null

	if ($Public -eq "True") {
		[string]$qn = ".\$QueueName"
	} else {
		[string]$qn = ".\private`$\$QueueName"
	}

	#if the queue exists, Don't attempt to create it again.
	if (!([System.Messaging.MessageQueue]::Exists($qn))) {
		#if the queue is transactional, run one command, otherwise, run the other.
		if (!$Transactional -eq "True") {
			try {
				$QueueOperation = [System.Messaging.MessageQueue]::Create($qn)
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "Successfully created non-transactional queue `'$qn`'"
				}
			} catch [Exception] {
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: there was an issue creating non-transactional queue `'$qn`'"
				}
			}
		} else {
			try {
				$QueueOperation = [System.Messaging.MessageQueue]::Create($qn, $true)
				if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "Successfully created transactional queue `'$qn`'"
					}
			} catch [Exception] {
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "FAILURE:: there was an issue creating transactional queue `'$qn`'"
				}
			}
		}
		#Ensure that the queue is created and exists before trying to change any further params...
		Write-Host "Waiting while MSMQ initializes the queue..."
		$wait = "."
		$pos = 1
		do {
			$str = $wait * $pos
			Start-Sleep -Seconds 5
			Write-Host $str -NoNewline
			$pos++
		} while (!([System.Messaging.MessageQueue]::Exists($qn)))
		Write-Host ""
		$QueueOperation.Path = $qn
		$QueueOperation.Label = "$QueueName"
		
		#Just setting some properties if needed.
		if ($MaxJournalSize) {
			$QueueOperation.UseJournalQueue = $true
			$QueueOperation.MaximumJournalSize = $MaxJournalSize
		}
		
		if ($Authenticated -eq "True") {
			$QueueOperation.Authenticate = $true
		}
		
		if ($EREnabled) {
			$QueueOperation.EncryptionRequired = $EncryptionRequired
		}
		
		if ($MaxQueueSize) {
			$QueueOperation.MaximumQueueSize = $MaxQueueSize
		}
		
		if ($EnableJournal -eq "True") {
			$QueueOperation.UseJournalQueue = $true
		}

		$QueueOperation.Close()
	} else {
		#Error and exit out.
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "The `'$qn`' queue already exits!"
		}
		Write-Host "The `"$qn`" queue already exits!" -ForegroundColor Red -BackgroundColor White
		#throw
	}
	
}

Function DeleteMSMQ {
	param([string]$QueueName, `
	[String]$Public)

$Usage = @"
#-------------------------------------------------------------------------
# Solution: DeleteMSMQ
# Author: Sly Stewart 
# Updated: 12/05/2012
# Version: 1.0
<#
# Description: Delete an MSMQ Queue.

- Mandatory Parameters
	[String]-QueueName: Name of the queue to Delete. Defaults to private queue unless `'-Public`' is used.

- Optional Parameters
	[String]-Public: Deletes a Public queue instead of a Private queue.

#
# Usage:
# - DeleteMSMQ -QueueName "LADodgers"
#	## Deletes a private queue named "LADodgers" 


# - DeleteMSMQ -QueueName "Padres" -Public
#	## Deletes a public queue named "Padres"

#>
# Revision History
# Version 1.0 - Initial Commit
#-------------------------------------------------------------------------

"@
    DetermineCluster
    if (!$execMSMQ) { return } 
	if ($PSBoundParameters.Count -eq 0) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to DeleteMSMQ"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
	}
	if (!$QueueName) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to DeleteMSMQ (QueueName)"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
	}
	
	if ($Public -eq "True") {
		[string]$qn = ".\$QueueName"
	} else {
		[string]$qn = ".\private`$\$QueueName"
	}
	
	if ([System.Messaging.MessageQueue]::Exists($qn)) {
		$QueueOperation = [System.Messaging.MessageQueue]::Delete($qn)
		if ($?) {
			Write-Host "Succeded."
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Successfully deleted MSMQ Queue `'$qn`'."
			}
		} else {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: Could not delete `"$qn`" queue. $_"
			}
			Write-Host "Could not delete `"$qn`" queue." -ForegroundColor Red -BackgroundColor White
			throw
		}

	} else {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "The `'$qn`' queue does not exist!"
		}
		Write-Host "The `"$qn`" queue does not exist!" -ForegroundColor Red -BackgroundColor White
		throw
	}
}

function GetAllMSMQQueues {
$Usage = @"
#-------------------------------------------------------------------------
# Solution: GetAllMSMQQueues
# Author: Sly Stewart 
# Updated: 5/13/2013
# Version: 1.0
<#
# Description: Returns a collection of string Local Queue Names.

#
# Usage:
# GetAllMSMQQueues
	#Returns a collection of local QueueNames.

#>
# Revision History
# Version 1.0 - Initial Commit, SS- 5/13/2013
#-------------------------------------------------------------------------

"@
    DetermineCluster
    if (!$execMSMQ) { return } 

	
	[Reflection.Assembly]::LoadWithPartialName("System.Messaging") | out-null
	$AllQueues = @()
	[System.Messaging.MessageQueue[]]$PrivateQueues = [System.Messaging.MessageQueue]::GetPrivateQueuesByMachine($cName.ToLower())
	if($PrivateQueues){ #User story 1198 - PSv2 proofing
		Foreach ($queue in $PrivateQueues) {
			$QueueName = $queue.QueueName
			$AllQueues += $QueueName
		}
	}

	[System.Messaging.MessageQueue[]]$PublicQueues = [System.Messaging.MessageQueue]::GetPublicQueuesByMachine($cName.ToLower())
	if($PublicQueues){ #User story 1198 - PSv2 proofing
		Foreach ($queue in $PublicQueues) {
			$QueueName = $queue.QueueName
			$AllQueues += $QueueName
		}
	}
	
	if ($AllQueues) {
		return $AllQueues
	}
}

function VerifyMSMQDS {

    $Usage = @"
#-------------------------------------------------------------------------
# Solution: VerifyMSMQDS
# Author: Todd Pluciennik
# Updated: 3/13/2014
# Version: 1.0
<#
# Description:Verify MSMQ Directory Services was setup properly
# credit: http://msdn.microsoft.com/en-us/library/ms711341(v=vs.85).aspx
#
# Usage:
# VerifyMSMQDS
	#Verify MSMQ Directory Services Integration works properly (MSMQ-Directory)

#>
# Revision History
# Version 1.0 - Initial Commit, tpluciennik 3/13/2014
#-------------------------------------------------------------------------

"@

    $MyMSMQApp = new-object  –comObject  MSMQ.MSMQApplication 
    $MSMQ_MaxRetries= 900 # timer (seconds) for wait for AD - 15 mins seems ok
    # to string: $MyMSMQApp
    $MSMQ_DS_FailMSG = @"
FAILURE:: MSMQ-Directory feature was requested, however Directory Services Integration failed. Waited $MSMQ_MaxRetries seconds.
FAILURE:: Probable cause:
FAILURE:: - With Directory Services Integration installed for MSMQ and working properly,  if the MSMQ feature is remove/re-installed without deleting the MSMQ computer object first, it will put the server in Workgroup Mode. 
FAILURE:: Solution:
FAILURE:: -Delete the MSMQ object in Active Directory
FAILURE:: -Restart the MSMQ service
FAILURE:: -Reboot the server
"@

    # initial check
    if ($MyMSMQApp.IsDSEnabled) { return }

    Write-host "Waiting up to $MSMQ_MaxRetries seconds for MSMQ object to be available"
    # loop max times waiting for object in AD
    do { 
       $MyMSMQApp = new-object  –comObject  MSMQ.MSMQApplication
       start-sleep 1
       $MSMQ_MaxRetries--
       if ($MSMQ_MaxRetries -eq 0) { break } 
       }

    while (!$MyMSMQApp.IsDSEnabled )

    # last check
    $MyMSMQApp = new-object  –comObject  MSMQ.MSMQApplication
    if (! $MyMSMQApp.IsDSEnabled) {

        if ($LoggingCheck) {
			        ToLog -LogFile $LFName -Text $MSMQ_DS_FailMSG
		        }
		        Write-Host $MSMQ_DS_FailMSG -ForegroundColor Red -BackgroundColor White
    }

}# end function

function AddMSMQCert {
    Param([String]$ADUsername,
	    [String]$Password
    )

    $Usage = @"
#-------------------------------------------------------------------------
# Solution: AddMSMQCert
# Author: Todd Pluciennik
# Updated: 4/24/2014
# Version: 1.0
<#
# Description: Add MSMQ certificate. 
  Reference: http://technet.microsoft.com/en-us/library/hh405012(v=vs.85).aspx

- Mandatory Parameters
	[String]-ADUsername: AD User name
    [String]-Password: Password for adUsername
#
# Usage:
# - AddMSMQCert -ADUsername "bridgepoint\svc_account" -Password "12345!"
#	## Adds (Enables) MSMQ certificate for username on current machine
#      Assumes that the user has the ability to log on to the local system to execute


#>
# Revision History
# Version 1.0 - Initial Commit. 
#-------------------------------------------------------------------------

"@

    if ($PSBoundParameters.Count -eq 0) {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Mandatory parameters not passed to AddMSMQCert"
		}
		Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
		throw
	}
    $credential = New-Object System.Management.Automation.PsCredential("$ADUsername", (ConvertTo-SecureString "$Password" -AsPlainText -Force))
    $results = Start-Job -ScriptBlock {whoami;Get-MSMQCertificate; $ConfirmPreference = 'None'; Enable-MSMQCertificate -RenewInternalCertificate; Get-MSMQCertificate} -Credential $credential |  wait-job 
    try {
        Receive-Job $results -ErrorAction Stop
        $results
     } catch{ 
        if ($LoggingCheck) {
	        ToLog -LogFile $LFName -Text "FAILURE:: there was an issue Adding the MSMQ certificate for user $ADUsername on machine $env:COMPUTERNAME : $_.exception.message "
        }
     }
} # end function