
ipmo servermanager
$Features = @( "MSMQ", "NET-Framework")
$Error_List = @()
foreach ($Feature in $Features) {
	$Feat_Pres = (get-windowsFeature $Feature).Installed
	if (!($Feat_Pres)) {
		$Error_List += $Feature
	}
}

if ((($Error_List).Count) -gt 0) {
	foreach ($Ecount in $Error_List) {
		Write-Host "Feature `'$ECount`' missing!!" -ForegroundColor Red -BackgroundColor White -BackgroundColor White
	}
} else {
	Write-Host "Windows Features good" -ForegroundColor Green
}

$BaseKey = "HKLM:\Software\Microsoft\MSDTC"

$DTCKeys = @{}
$DTCKeys["NetworkDtcAccess"] = "$BaseKey\Security"
$DTCKeys["XaTransactions"] = "$BaseKey\Security"
$DTCKeys["LuTransactions"] = "$BaseKey\Security"
$DTCKeys["NetworkDtcAccessClients"] = "$BaseKey\Security"
$DTCKeys["NetworkDtcAccessAdmin"] = "$BaseKey\Security"
$DTCKeys["NetworkDtcAccessTransactions"] = "$BaseKey\Security"
$DTCKeys["NetworkDtcAccessInbound"] = "$BaseKey\Security"
$DTCKeys["NetworkDtcAccessOutbound"] = "$BaseKey\Security"
$DTCKeys["TurnOffRpcSecurity"] = "$BaseKey"

$err = 0
foreach ($DTKey in ($DTCKeys.Keys)) {
	$KeyPath = $DTCKeys["$DTKey"]
	if (((Get-ItemProperty -Path "$KeyPath" -Name $DTKey).$DTKey) -ne 1) {
		Write-Host "$DTKey is not set!" -ForegroundColor Red -BackgroundColor White
		$err++
	}
}
if ($err -gt 0) {
	Write-Host "There are issues with the DTC Configuration!" -ForegroundColor Red -BackgroundColor White
} else {
	Write-Host "DTC Configuration is correct." -ForegroundColor Green
}
[Reflection.Assembly]::LoadWithPartialName("System.Messaging") | out-null

$err = 0
$QueueNames = @("QueueA", "Queue3")
foreach ($QN in $QueueNames) {
	$QueueString = ".\private`$\$QN"
	try {
		$eCheck = ([System.Messaging.MessageQueue]::Exists($QueueString))
	} catch [Exception] {
		$eCheck = $null
	}
	if (!$eCheck) {
		Write-Host "Queue $QN does not exist!" -ForegroundColor Red -BackgroundColor White
		$err++
	}
}
if ($err -gt 0) {
	Write-Host "There are issues with the MSMQ Configuration!" -ForegroundColor Red -BackgroundColor White
} else {
	Write-Host "MSMQ Queues present." -ForegroundColor Green
}

$err = 0
[String]$cName = $Env:COMPUTERNAME
#[System.Messaging.MessageQueue[]]$PrivateQueues = [System.Messaging.MessageQueue]::GetPrivateQueuesByMachine($cName.ToLower())
	try {
		[System.Messaging.MessageQueue[]]$PrivateQueues = [System.Messaging.MessageQueue]::GetPrivateQueuesByMachine($cName.ToLower())
	} catch [Exception] {
		$PrivateQueues = $null
	}
if (($PrivateQueues).Count -ne 2) {
	$err++
	$QQ = ($PrivateQueues).Count
	if (!$QQ) {
		$QQ = 0
	}
	Write-Host "Queue count is `'$QQ`' and not where it should be! (2)" -ForegroundColor Red -BackgroundColor White
}
	Foreach ($queue in $PrivateQueues) {
		$StringQueueName = $queue.QueueName
		if (!($queue.Transactional)) {
			$err++
			Write-Host "Queue `'$StringQueueName`' is not transactional!" -ForegroundColor Red -BackgroundColor White
		}
		switch($StringQueueName) {
			"private`$\Queue3" {
				if (!($queue.EncryptionRequired)) {
					$err++
					Write-Host "Queue `'$StringQueueName`' is not using encryption!" -ForegroundColor Red -BackgroundColor White
				}
				if ($queue.MaximumQueueSize -ne 10000) {
					$err++
					Write-Host "Queue `'$StringQueueName`' is not set for MaximumQueueSize!" -ForegroundColor Red -BackgroundColor White
				}
				
			}
			"private`$\QueueA" {
				if (!($queue.UseJournalQueue)) {
					$err++
					Write-Host "Queue `'$StringQueueName`' is not using a Journal!" -ForegroundColor Red -BackgroundColor White
				}
			}
			default {
				Write-Host "Extra unknown queues are present! `'$StringQueueName`'" -ForegroundColor Red -BackgroundColor White
			}
		}
	}
if ($err -gt 0) {
	Write-Host "There are issues with the MSMQ Queue Configuration!" -ForegroundColor Red -BackgroundColor White
} else {
	Write-Host "Queue configuration is correct" -ForegroundColor Green
}

if (!(Test-Path "D:\Logfiles\SlyWApp2.evtx")) {
	if (!(Test-Path "D:\Logfiles")) {
		Write-Host "Filesystem has not been configured correctly!" -ForegroundColor Red -BackgroundColor White
	}
	Write-Host "Event Log configuration has failed!" -ForegroundColor Red -BackgroundColor White
} else {
	Write-Host "Filesystem has been configured correctly." -ForegroundColor green
}
if (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Services\eventlog\SlyWApp2") {
	try {
			$KeyCheck = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\eventlog\SlyWApp2"
		} catch [Exception] {
			$KeyCheck = $null
		}
} else {
	$KeyCheck = $null
}
if ((($KeyCheck).Flags) -ne 1) {
	Write-Host "Event Log configuration has failed!" -ForegroundColor Red -BackgroundColor White
} else {
	Write-Host "Event log configuration is correct." -ForegroundColor Green
}
if (!(gwmi Win32_Volume | ? {($_.DriveType -eq 5) -and ($_.DriveLetter -eq "E:")})) {
	Write-Host "CD-Rom MoveFirst has failed!" -ForegroundColor Red -BackgroundColor White
} else {
	Write-Host "CD-Rom MoveFirst is correct." -ForegroundColor Green
}

$Error_List = @()
#Windows Firewall
$FWStates = netsh advfirewall show allprofiles | Select-String "State"
foreach ($ln in $FWStates) {
	[String]$Line = $ln
	$Split = $Line.Split(" ")
	$Last = $Split[-1]
	if ($Last -ne "OFF") {
		$Error_List += 1
	}
}

if (($Error_List).Count -gt 0) {
	Write-Host "Windows fireall not off!!" -ForegroundColor Red -BackgroundColor White	
} else {
	Write-Host "Windows Firewall configured properly." -ForegroundColor Green
}
if (Test-Path "D:\LogFiles") {
	try {
		$ACL_Check = (Get-Acl "D:\LogFiles").Access | ? {(($_.IdentityReference -eq "Bridgepoint\sstewart") -and ($_.FileSystemRights -eq "CreateFiles, Synchronize"))}
	} catch [Exception] {
		$ACL_Check = $null
	}
} else {
	$ACL_Check = $null
}
if (!$ACL_Check) {
	Write-Host "ACL Configuration has failed!!" -ForegroundColor Red -BackgroundColor White	
} else {
	Write-Host "ACL Configuration is correct." -ForegroundColor Green
}
