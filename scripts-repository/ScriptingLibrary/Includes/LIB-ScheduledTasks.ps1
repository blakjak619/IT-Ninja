#region TSScheduleTask
function TSScheduleTask {
param(
	[System.Xml.XmlElement]$TaskNode
)
	LLTraceMsg -InvocationInfo $MyInvocation
	
	foreach($ScheduledTask in $TaskNode.ScheduledTask) {
		$TaskID = $ScheduledTask.ID
		$Action = $ScheduledTask.Action
		if($Action) {
			$Action = $Action.ToLower()
		}
		$CredUser = $ScheduledTask.Task.Principals.Principal.UserId
        $CredPwd = $ScheduledTask.Password
        $AltUser = $ScheduledTask.User
		
		$ValidRequest = $true
        if($Action -eq "remove") {
            $ValidRequest = $true
        } else {
		    if((-not $CredUser) -and (-not $AltUser)) {
			    LLToLog -EventID $LLERROR -Text "You must specify a Principal that scheduled task $TaskID will run under."
			    $ValidRequest = $false
		    } else {
                if(-not $CredUser) {
                    $CredUser = $AltUser
                }
            }
		
		    if($ValidRequest) {
                if($CredUser -and $CredPwd) {
                    $SecurePwd = $CredPwd | ConvertTo-SecureString -AsPlainText -Force
                    $Cred = New-Object System.Management.Automation.PSCredential -ArgumentList $CredUser, $SecurePwd
                } else {
			        $CredPwd = LSGet-AccountPwd -Account $CredUser #Uses PasswordState API to get a password for a user ID then combines them into a PSCredentialObject
                }
			    if(-not $CredPwd) {
				    LLToLog -EventID $LLERROR -Text "Failed to get credentials for user $CredUser when processing scheduled task $TaskID"
				    $ValidRequest = $false
			    }
		    }
        }
		
		if($ValidRequest) {
			$TaskXML = $ScheduledTask.Task
			switch( $Action ) {
				"add" { 
					$resultobj = Register-ScheduledTask -TaskName $TaskID -XML $TaskXML.OuterXML -user $CredUser -Password $CredPwd -Force
	                if($resultobj.State -eq "Ready") {
	                    LLToLog -EventID $LLINFO -Text "Task $TaskID successfully scheduled."
	                } else {
                        LLToLog -EventID $LLINFO -Text "Task $TaskID scheduling failed with $($resultobj.State)."
                    }
				}
				"remove" {
                    $result = Unregister-ScheduledTask -TaskName $TaskID -Confirm:$false
                    LLToLog -EventID $LLINFO -Text "Task $TaskID successfully removed."
                }
				"setpwd" {
                    $resultobj = Set-ScheduledTask -TaskName $TaskID -User $CredUser -Password $CredPwd
	                if($resultobj.State -eq "Ready") {
	                    LLToLog -EventID $LLINFO -Text "Task $TaskID successfully configured."
	                } else {
                        LLToLog -EventID $LLINFO -Text "Task $TaskID configuration failed with $($resultobj.State)."
                    }
                }
				Default { LLToLog -EventID $LLWARN -Text "No action specified for scheduled task $TaskID" }
			} #switch
		} #if Valid
	} #foreach
}
#endregion
#region Unit Tests
if (($MyInvocation.Line -eq $null) -or ($MyInvocation.Line -notmatch "\. ")) {

	$LIBPATH = $env:ScriptLibraryPath
	. $LIBPATH\Includes\LIB-Includes.ps1 -DefaultLibraryPath $LIBPATH -Intentional
	LLInitializeLogging -LogLevel $LLTRACE
	
	[xml]$TextXML = @"
<TaskScheduler>
<ScheduledTask Action="Add" ID="uDPrunerTask">
<Task xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Date>2014-08-01T10:49:39.6704965</Date>
    <Author>BRIDGEPOINT\admdmeier</Author>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>2014-08-02T00:30:00</StartBoundary>
      <ExecutionTimeLimit>PT2H</ExecutionTimeLimit>
      <Enabled>true</Enabled>
      <ScheduleByDay>
        <DaysInterval>1</DaysInterval>
      </ScheduleByDay>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>svc_udeploy</UserId>
      <LogonType>Password</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>true</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>false</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>P3D</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>Powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass c:\temp\STIG-ServierStandup.ps1 -xmlfile c:\temp\PurgeuDFiles.xml</Arguments>
    </Exec>
  </Actions>
</Task>
</ScheduledTask>
<ScheduledTask Action="SetPwd" ID="uDPrunerTask"  User="svc_udeploy"/>
<ScheduledTask Action="Remove" ID="uDPrunerTask"/>
</TaskScheduler>
"@
    $StartTime = Get-Date
	foreach($TaskElem in $TextXML.TaskScheduler) {
		TSScheduleTask -TaskNode $TaskElem
	}
    Get-EventLog -LogName Application -After $StartTime | Sort-Object TimeGenerated | Format-Table -AutoSize -Wrap
}
#endregion