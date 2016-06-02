#region Uncoded Functions
function PS3Register-ScheduledTask-User {
	LLTraceMsg -InvocationInfo $MyInvocation
	throw "Register-ScheduledTask User functionality is not yet implemented."
}
function PS3Register-ScheduledTask-Object {
	LLTraceMsg -InvocationInfo $MyInvocation
	throw "Register-ScheduledTask Object functionality is not yet implemented."
}
function PS3Register-ScheduledTask-Principal {
	LLTraceMsg -InvocationInfo $MyInvocation
	throw "Register-ScheduledTask Principal functionality is not yet implemented."
}
#region PS3Set-ScheduledTask-User
function PSSet-ScheduledTask-User {
	LLTraceMsg -InvocationInfo $MyInvocation
	throw "Set-ScheduledTask User functionality is not yet implemented."
}
#endregion
#region PS3Set-ScheduledTask-Principal
function PS3Set-ScheduledTask-Principal {
	LLTraceMsg -InvocationInfo $MyInvocation
	throw "Set-ScheduledTask Principal functionality is not yet implemented."
}
#endregion
#region PS3Unregister-ScheduledTask-InputObject
function PS3Unregister-ScheduledTask-InputObject {
	LLTraceMsg -InvocationInfo $MyInvocation
	throw "PS3Unregister-ScheduledTask InputObject functionality is not yet implemented."
}
#endregion
#region Set-ScheduledTask
#endregion
#endregion
#region PS3Register-ScheduledTask-XML
function PS3Register-ScheduledTask-XML {
param(
	[string]$TaskName,
	[string]$TaskPath = "\",
	[string]$User,
	[string]$Password,
	[string]$xml,
	[Microsoft.Management.Infrastructure.CimSession[]]$CimSession,
	[switch]$AsJob,
	[switch]$Force,
	[Int32]$ThrottleLimit
)
	LLTraceMsg -InvocationInfo $MyInvocation
	
	#Lazily implemented with schtasks.exe
	#schtasks /Create 
	#[/S system [/U username [/P [password]]]]
	#[/RU username [/RP [password]] /SC schedule [/MO modifier] [/D day]
	#[/M months] [/I idletime] /TN taskname /TR taskrun [/ST starttime]
	#[/RI interval] [ {/ET endtime | /DU duration} [/K] 
	#[/XML xmlfile] [/V1]] [/SD startdate] [/ED enddate] [/IT] [/Z] [/F]
	$status = 0

	$cmdstr = "schtasks.exe /Create "
	
	if(-not $TaskName) {
		LLToLog -EventID $LLERROR "You must provide a task name for a scheduled task."
		$stats += 1
	} else {
		$cmdstr += " /TN $TaskPath$TaskName "
	}
	
    #TechNet says "The /u and /p parameters are valid only for changing a task on a remote computer"
	if($User) {
		$cmdstr += " /RU $User"
	}
	
	if($Password) {
        if(-not $User) {
            LLToLog -EventID $LLWARN -Text "You cannot specify password without specifying user name."
            $status += 1
        }
        $AcctRegex = [regex]'@LOOKUPPWD\((.+)\)'
		if($Password -match "@LOOKUPPWD*") {
			$Account = [regex]::match($Password,$AcctRegex).Groups[1].Value
			$Password = LSGet-AccountPwd -Account $Account 
		}
		$cmdstr += " /RP $Password"
	}
	
	if(-not $xml) {
		LLToLog -EventID $LLERROR "You must provide a ScheduledTask XML document."
		$status += 1
	} else {
        $tempfile = [system.io.path]::GetTempFileName()
        Set-Content $tempfile $xml
		$cmdstr += " /XML $tempfile "
	}
	
	if($AsJob) {
		LLToLog -EventID $LLINFO "AsJob parameter ignored in PS3 version of this command."
	}
	
	if($Force) {
		$cmdstr += " /F"
	}
	
	if($ThrottleLimit) {
		#$cmdstr += " /RL HIGHEST"
	} else {
		#$cmdstr += " /RL LIMITED"
	}
	
	#check that command exists
	try {
		$result = $null
		$result = Invoke-Expression "schtasks /?" -ErrorAction Stop
		if(-not $result) {
			LLToLog -EventID $LLERROR "schtasks.exe not found."
			$status += 1
		}
	} catch {
		LLToLog -EventID $LLERROR "schtasks.exe not found."
		$status += 1
	}
	
    if($status -eq 0) {
        try {
    	    $result = Invoke-Expression $cmdstr -ErrorAction Stop
	        LLToLog -EventID $LLINFO -Text "schtasks /create returned: $result"
            if(-not ($result | select-string "SUCCESS:")) {
                LLToLog -EventID $LLERROR -Text "schtasks /create failed."
                $status += 1
            }
        } catch {
            LLToLog -EventID $LLERROR -Text "schtask.exe /create failed with $($_.Exception)"
            $status += 1
        }
    }

    Remove-Item $tempfile -Force

    if($status -eq 0) {
        return $true
    } else {
        return $false
    }
        
}
#endregion
#region PS3Set-ScheduledTask-User
function PS3Set-ScheduledTask-User {
param(
    [string]$User,
	[Microsoft.Management.Infrastructure.CimInstance[]]$Action,
	[Microsoft.Management.Infrastructure.CimInstance[]]$Trigger,
	[Microsoft.Management.Infrastructure.CimInstance[]]$Settings,
	[string]$Password,
	[string]$TaskName,
	[string]$TaskPath,
	[Microsoft.Management.Infrastructure.CimSession[]]$CimSession,
	[switch]$AsJob,
	[Int32]$ThrottleLimit
)

	LLTraceMsg -InvocationInfo $MyInvocation
	#schtasks /Change 
    #[/S system [/U username [/P [password]]]] /TN taskname
    #[/RU runasuser] [/RP runaspassword] [/TR taskrun] [/ST starttime] 
    #[/RI interval] [ {/ET endtime | /DU duration} [/K] ]
    #[/SD startdate] [/ED enddate] [/ENABLE | /DISABLE] [/IT] [/Z] }
	
	$status = 0

	$cmdstr = "schtasks.exe /Change "
	
	if(-not $TaskName) {
		LLToLog -EventID $LLERROR "You must provide a task name for a scheduled task."
		$status += 1
	} else {
		$cmdstr += " /TN '$TaskPath$TaskName' "
	}

    #TechNet says "The /u and /p parameters are valid only for changing a task on a remote computer"
	if($User) {
		$cmdstr += " /RU $User"
	}
	
	if($Password) {
        if(-not $User) {
            LLToLog -EventID $LLWARN -Text "You cannot specify password without specifying user name."
            $status += 1
        }
        $AcctRegex = [regex]'@LOOKUPPWD\((.+)\)'
		if($Password -match "@LOOKUPPWD*") {
			$Account = [regex]::match($Password,$AcctRegex).Groups[1].Value
			$Password = LSGet-AccountPwd -Account $Account 
		}
		$cmdstr += " /RP $Password"
	}
	
    if($status -eq 0) {
        try {
    	    $result = Invoke-Expression $cmdstr -ErrorAction Stop
	        LLToLog -EventID $LLINFO -Text "schtasks /change returned: $result"
            if(-not ($result | select-string "SUCCESS:")) {
                LLToLog -EventID $LLERROR -Text "schtasks /change failed."
                $status += 1
            }
        } catch {
            LLToLog -EventID $LLERROR -Text "schtask.exe /change failed with $($_.Exception)"
            $status += 1
        }
    }
}
#endregion
#region PS3SUnregister-ScheduledTask-ByPath
function PS3SUnregister-ScheduledTask-ByPath {
[CmdletBinding(SupportsShouldProcess=$True)]
param(
	[string]$TaskName,
	[string]$TaskPath,
	
	[switch]$AsJob,
	[Microsoft.Management.Infrastructure.CimSession[]]$CimSession,
	[switch]$PassThru,
	[Int32]$ThrottleLimit	
)
	LLTraceMsg -InvocationInfo $MyInvocation

	#schtasks /Delete 
	#[/S system [/U username [/P [password]]]]
	#[/TN taskname] [/F]
	
	$status = 0

	$cmdstr = "schtasks.exe /Delete /f"
	
	if(-not $TaskName) {
		LLToLog -EventID $LLERROR "You must provide a task name for a scheduled task."
		$status += 1
	} else {
		$cmdstr += " /TN '$TaskPath$TaskName' "
	}

	#/S /U /P /F not passed
	
    if($status -eq 0) {
        try {
    	    $result = Invoke-Expression $cmdstr -ErrorAction Stop
	        LLToLog -EventID $LLINFO -Text "schtasks /delete returned: $result"
            if(-not ($result | select-string "SUCCESS:")) {
                LLToLog -EventID $LLERROR -Text "schtasks /delete failed."
                $status += 1
            }
        } catch {
            LLToLog -EventID $LLERROR -Text "schtask.exe /delete failed with $($_.Exception)"
            $status += 1
        }
    }	
}
#endregion
#region Register-ScheduledTask
function Register-ScheduledTask {
[CmdletBinding(DefaultParameterSetName = "User")]
param(
	[Parameter(ParameterSetName="Object")] [Microsoft.Management.Infrastructure.CimSession[]]$InputObject,

	[Parameter(ParameterSetName="Principal")] [Microsoft.Management.Infrastructure.CimInstance]$Principal,

	[Parameter(ParameterSetName="XML")] [string]$xml,

	[Microsoft.Management.Infrastructure.CimInstance[]]$Action,
	[Microsoft.Management.Infrastructure.CimInstance[]]$Trigger,
	[Microsoft.Management.Infrastructure.CimInstance[]]$Settings,
	[string]$User,
	[string]$Password,
	[string]$Description,
	[string]$TaskName,
	[string]$TaskPath,
	[Microsoft.Management.Infrastructure.CimSession[]]$CimSession,
	[switch]$AsJob,
	[switch]$Force,
	[Int32]$ThrottleLimit
)
	LLTraceMsg -InvocationInfo $MyInvocation
	
	switch($PSCmdlet.ParameterSetName) {
		"User" {
			PS3Register-ScheduledTask-User @PSBoundParameters
		}
		"Object" {
			PS3Register-ScheduledTask-Object @PSBoundParameters
		}
		"Principal" {
			PS3Register-ScheduledTask-Principal @PSBoundParameters
		}
		"XML" {
			PS3Register-ScheduledTask-XML @PSBoundParameters
		}
		Default {
			throw "Unknown Parameter set."
		}
	}
}
#endregion
#region Set-ScheduledTask
function Set-ScheduledTask {
[CmdletBinding(DefaultParameterSetName = "User")]
param(
    [Parameter(ParameterSetName="User")] [string]$User,

	[Parameter(ParameterSetName="InputObject")] [Microsoft.Management.Infrastructure.CimSession[]]$InputObject,

	[Parameter(ParameterSetName="Principal")] [Microsoft.Management.Infrastructure.CimInstance]$Principal,

	[Microsoft.Management.Infrastructure.CimInstance[]]$Action,
	[Microsoft.Management.Infrastructure.CimInstance[]]$Trigger,
	[Microsoft.Management.Infrastructure.CimInstance[]]$Settings,
	[string]$Password,
	[string]$TaskName,
	[string]$TaskPath,
	[Microsoft.Management.Infrastructure.CimSession[]]$CimSession,
	[switch]$AsJob,
	[Int32]$ThrottleLimit
)
	LLTraceMsg -InvocationInfo $MyInvocation
	
	switch($PSCmdlet.ParameterSetName) {
		"User" {
			PS3Set-ScheduledTask-User @PSBoundParameters
		}
		"InputObject" {
			PS3Set-ScheduledTask-InputObject @PSBoundParameters
		}
		"Principal" {
			PS3Set-ScheduledTask-Principal @PSBoundParameters
		}
		Default {
			throw "Unknown Parameter set."
		}
	}
}
#endregion
#region Unregister-ScheduledTask
function Unregister-ScheduledTask {
[CmdletBinding(DefaultParameterSetName = "ByPath",SupportsShouldProcess=$True)]
param(
	[Parameter(ParameterSetName="ByPath")] [string]$TaskName,
	[Parameter(ParameterSetName="ByPath")] [string]$TaskPath,
	
	[Parameter(ParameterSetName="InputObject")] [Microsoft.Management.Infrastructure.CimInstance[]]$InputObject,

	[switch]$AsJob,
	[Microsoft.Management.Infrastructure.CimSession[]]$CimSession,
	[switch]$PassThru,
	[Int32]$ThrottleLimit	
)
	LLTraceMsg -InvocationInfo $MyInvocation
	
	switch($PSCmdlet.ParameterSetName) {
		"ByPath" {
			PS3SUnregister-ScheduledTask-ByPath @PSBoundParameters
		}
		"InputObject" {
			PS3Unregister-ScheduledTask-InputObject @PSBoundParameters
		}
		Default {
			throw "Unknown Parameter set."
		}
	}
}
#endregion

#region Disable-ScheduledTask
function Disable-ScheduledTask {
param(
    [string]$TaskName,
    [string]$ComputerName = "localhost"
)

    $TaskScheduler = New-Object -ComObject Schedule.Service
    $TaskScheduler.Connect($ComputerName)
    $TaskRootFolder = $TaskScheduler.GetFolder('\')
    $Task = $TaskRootFolder.GetTask($TaskName)
    if(-not $?)
    {
        Write-Error "Task $TaskName not found on $ComputerName"
        return
    }
        $Task.Enabled = $False
}
#endregion

#region Enable-ScheduledTask    
function Enable-ScheduledTask {
param(
    [string]$TaskName,
    [string]$ComputerName = "localhost"
)

    $TaskScheduler = New-Object -ComObject Schedule.Service
    $TaskScheduler.Connect($ComputerName)
    $TaskRootFolder = $TaskScheduler.GetFolder('\')
    $Task = $TaskRootFolder.GetTask($TaskName)
    if(-not $?)
    {
        Write-Error "Task $TaskName not found on $ComputerName"
        return
    }
    $Task.Enabled = $True
}
#endregion 


#region Unit Tests

if (($MyInvocation.Line -eq "") -or ($MyInvocation.Line -notmatch "\. ")) {

	$LIBPATH = $env:ScriptLibraryPath
	. $LIBPATH\Includes\LIB-Includes.ps1 -DefaultLibraryPath $env:ScriptLibraryPath -Intentional

	LLInitializeLogging -LogLevel $LLTRACE
	
	[xml]$TextXML = @"
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
      <UserId>BRIDGEPOINT\svc_udeploy</UserId>
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
"@
    $StartTime = Get-Date
	Register-ScheduledTask -TaskName "uDPrunerTask" -XML $TextXML.OuterXML -User "BRIDGEPOINT\svc_udeploy" -Password "@LOOKUPPWD(svc_udeploy)"
    Set-ScheduledTask -TaskName "uDPrunerTask" -User "BRIDGEPOINT\svc_udeploy" -Password "@LOOKUPPWD(svc_udeploy)"
	Unregister-ScheduledTask -TaskName "uDPrunerTask"

    Get-EventLog -LogName Application -After $StartTime | Sort-Object TimeGenerated | Format-Table -AutoSize -Wrap
}
#endregion