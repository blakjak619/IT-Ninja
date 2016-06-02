#region FileInUseBy
function FileInUseBy {
param(
	[string]$File
)
	LLTraceMsg -InvocationInfo $MyInvocation

	if(Test-Path -Path $File){
		$lockedFile=$File
		$FileIsLocked = $False
		$ProcessList = Get-Process
		foreach($Process in $ProcessList) {
			$processVar = $Process
			$ModuleList = $Process.Modules
			foreach($Module in $ModuleList){
				if($Module.FileName -eq $lockedFile){
					$processVar.Name
					LLToLog -EventID $LLINFO -Text "File $File is locked by $($processVar.Name) + " PID:" + $($processVar.id)"
					$FileIsLocked = $True
				}
			}
		}
	}

	#if that isn't a valid file then it can't be locked, obviously; and if we didn't return when we found the locking process then it must not be locked.
	return $False 
}
#endregion
#region Test-PathVarContains
Function Test-PathVarContains {
param (
	[Parameter(Mandatory=$True)] [string]$PathContents,
	[Parameter(Mandatory=$True)] [string]$TestContents
)
	LLTraceMsg -InvocationInfo $MyInvocation

	#Split path up by ;'s
	$PathElements = $PathContents -split (";")

	foreach($PathElement in $PathElements) {
		if($PathElement -eq $TestContents) { return 1}
	}

	return 0
}
#endregion
#region Set-EnvironmentVariable
Function Process-EnvVarNode{
param( [System.Xml.XMLElement]$EnvVars )
	foreach ($Var in $EnvVars.Var) {
		$Action = $Var.Action
		$Variable = $Var.Variable
		$VarValue = $Var.Value
		$Target = $Var.Target
		if($Action -and $Variable -and $VarValue -and $Target) {
			LLToLog -EventID $LLTRACE -Text "Set-EnvironmentVariable $Action $Variable $VarValue $Target"
			$retval = Set-EnvironmentVariable -Action $Action -Variable $Variable -Value $VarValue -Target $Target 
		}
	}
}
<# 
.SYNOPSIS
	Set-EnvironmentVariable sets an environment variable  
.DESCRIPTION
	Set-EnvironmentVariable sets an environment variable 
.NOTES  
	Author        : Dan Meier  
	Assumptions   :
		
.EXAMPLE
	$EnvNode = $XMLParams.params.EnvVar
	if ($ENVNode) {
		Set-EnvironmentVariable -Action "Add" -Variable "Path" -Value "D:\Program Files\Microsoft SQL Server\110\Tools\Binn" -Target "Machine"
	}
.INPUTS
    [Parameter(Mandatory=$True)] [ValidateSet("Add","Set","Del") [string]$Action
	[Parameter(Mandatory=$True)] [string]$Variable,
	[Parameter(Mandatory=$True)] [string]$Value,
	[Parameter(Mandatory=$True)] [ValidateSet("Machine","User")] [string]$Target 
	<EnvVariable Action="Add" Variable="Path" Value="D:\Program Files\Microsoft SQL Server\110\Tools\Binn" Target="Machine" \>
	<EnvVariable Action="Set" Variable="Path" Value="D:\Program Files\Microsoft SQL Server\110\Tools\Binn" Target="User" \>
	
	Assumes these variables are defined (by calling script):
	$LoggingCheck
	$LFName

.OUTPUTS
    Returns a 0 for success; 1 for failure. Writes to the console any failure messages, logs to a log file other informational messages.
#>
Function Set-EnvironmentVariable {
param (
	[Parameter(Mandatory=$True)] [ValidateSet("Add","Set","Del")] [string]$Action,
	[Parameter(Mandatory=$True)] [string]$Variable,
	[Parameter(Mandatory=$True)] [string]$Value,
	[Parameter(Mandatory=$True)] [ValidateSet("Machine","User")] [string]$Target 
)
	LLTraceMsg -InvocationInfo $MyInvocation
if ($LoggingCheck) { ToLog -LogFile $LFName -EventID 2 -Text "Environment variable $Variable requested to be set." }

#	I need the variable
#	the value to set it to
#	and whether it is machine or user

	switch($Action) {
		"Add" { 
			$cvar = [Environment]::GetEnvironmentVariable($Variable,$Target)
			$compexist = $cvar.ToLower()
			$compadd = $value.ToLower()
			if( Test-PathVarContains $compexist $compadd ) {
				 ToLog -LogFile $LFName -EventID 2 -Text "Environment variable $Variable already contains <$Value>." 
			} else {
				$cvar = [Environment]::GetEnvironmentVariable($Variable,$Target) + ";" + $Value 
			}
		}
		"Set" { $cvar = $Value }
		"Del" { $cvar = $null }
	}
	try {
		[Environment]::SetEnvironmentVariable($Variable, $cvar, $Target)
		$retval = 0
	} catch {
		ToLog -LogFile $LFName -EventID 3 -Text "Environment variable $Variable failed to set. Exception $_.Exception"
		$retval = 1
	}
	
	return $retval
}
#endregion
#region isServer2012orLater
Function isServer2012orLater {
	LLTraceMsg -InvocationInfo $MyInvocation

	$vstr = (Get-CimInstance Win32_OperatingSystem).version
	$vary = $vstr -split "\."

	if ($vary[0] -gt 6) {
		return $true
	}

	if (($vary[0] -eq 6) -and ($vary[1] -ge 2)) {
			return $true
	}

	return $false
}
#endregion
#region isPSv4orLater
Function IsPSv4orLater {
	LLTraceMsg -InvocationInfo $MyInvocation

	$retval = $false
	if($PSVersionTable.PSVersion.Major-ge 4) {
		$retval = $true
	}

	return $retval
}
#endregion
#region PageFileXMLParser
function PageFileXMLParser{
param(
    [System.Xml.XMlElement]$PageFileConfigNode
)
    foreach($Config in $PageFileConfigNode.Config){
		$ParamHash = @{}
		#Determine ParameterSet
		if($Config.InitialSizeMB -and $Config.MaximumSizeMB -and $Config.DriveLetter){
			$ParamHash.Add("-InitialSize",$Config.InitialSizeMB)
			$ParamHash.Add("-MaximumSize",$Config.MaximumSizeMB)
			$ParamHash.Add("-DriveLetter",$Config.DriveLetter)
			if($Config.Reboot){
				$ParamHash.Add("-Reboot",$true)
			}
		}
		
		if($Config.NoPageFile -and -not $ParamHash.Count){
			$ParamHash.Add("-DriveLetter",$Config.DriveLetter)
			$ParamHash.Add("-None",$true)
		}
		
		if($Config.SystemManagedSize -and -not $ParamHash.Count){
			$ParamHash.Add("-DriveLetter",$Config.DriveLetter)
			$ParamHash.Add("-SystemManagedSize",$true)
		}
		
		if($Config.AutoConfigure -and -not $ParamHash.Count){
			$ParamHash.Add("-DriveLetter",$Config.DriveLetter)
			$ParamHash.Add("-Autoconfigure",$true)
		}
		
		try{
			Set-OSCVirtualMemory @ParamHash
		} catch {
			LLToLog -EventID $LLERROR -Text "$_.Exception.Message"
		}
    }
}
#endregion
#region Set-OSCVirtualMemory
Function Set-OSCVirtualMemory{
<#
 	.SYNOPSIS
        Set-OSCVirtualMemory is an advanced function which can be used to adjust virtual memory page file size.
    .DESCRIPTION
        Set-OSCVirtualMemory is an advanced function which can be used to adjust virtual memory page file size.
    .PARAMETER  <InitialSize>
		Setting the paging file's initial size.
	.PARAMETER  <MaximumSize>
		Setting the paging file's maximum size..
	.PARAMETER  <DriveLetter>
		Specifies the drive letter you want to configure.
	.PARAMETER  <SystemManagedSize>
		Allow Windows to manage page files on this computer.
	.PARAMETER  <None>		
		Disable page files setting.
	.PARAMETER  <Reboot>		
		Reboot the computer so that configuration changes take effect.
	.PARAMETER  <AutoConfigure>
		Automatically configure the initial size and maximumsize.
    .EXAMPLE
        C:\PS> Set-OSCVirtualMemory -InitialSize 1024 -MaximumSize 2048 -DriveLetter "C:","D:"

		Execution Results: Set page file size on "C:" successful.
		Execution Results: Set page file size on "D:" successful.

		Name            InitialSize(MB) MaximumSize(MB)
		----            --------------- ---------------
		C:\pagefile.sys            1024            2048
		D:\pagefile.sys            1024            2048
		E:\pagefile.sys            2048            2048
	.LINK
		Get-WmiObject
		http://technet.microsoft.com/library/hh849824.aspx
#>
	[cmdletbinding(SupportsShouldProcess=$true,DefaultParameterSetName="SetPageFileSize")]
	Param
	(
		# Paramater Set - Set Page File Size
		[Parameter(Mandatory=$true,Position=0,ParameterSetName="SetPageFileSize")] [Int32]$InitialSize,
		[Parameter(Mandatory=$true,Position=1,ParameterSetName="SetPageFileSize")] [Int32]$MaximumSize,
		[Parameter(Mandatory=$true,Position=2)] [String[]]$DriveLetter,
		
		# Parameter Set - None
		[Parameter(Mandatory=$true,Position=3,ParameterSetName="None")] [Switch]$None,
		
		# Parameter Set - System Managed Size
		[Parameter(Mandatory=$true,Position=4,ParameterSetName="SystemManagedSize")] [Switch]$SystemManagedSize,
		
		# Optional Switches
		[Parameter(Mandatory=$false,Position=5)] [Switch]$Reboot,
		
		# Parameter Set - Auto Configure
		[Parameter(Mandatory=$true,Position=6,ParameterSetName="AutoConfigure")] [Switch]$AutoConfigure
	)
	
	If($PSCmdlet.ShouldProcess("Setting the virtual memory page file size"))
	{
		Foreach($DL in $DriveLetter)
		{		
			If($None)
			{
				$PageFile = Get-WmiObject -Query "Select * From Win32_PageFileSetting Where Name='$DL\\pagefile.sys'" -EnableAllPrivileges
				If($PageFile -ne $null)
				{
					$PageFile.Delete()
				}
				Else
				{
					Write-Warning """$DL"" is already set None!"
				}
			}
			ElseIf($SystemManagedSize)
			{
				$InitialSize = 0
				$MaximumSize = 0
				
				Set-PageFileSize -DL $DL -InitialSize $InitialSize -MaximumSize $MaximumSize
			}						
			ElseIf($AutoConfigure)
			{
				$InitialSize = 0
				$MaximumSize = 0
				
				#Getting total physical memory size
				Get-WmiObject -Class Win32_PhysicalMemory | Where-Object{$_.DeviceLocator -ne "SYSTEM ROM"} | `
				ForEach-Object{$TotalPhysicalMemorySize += [Double]($_.Capacity)/1GB}
				
				<#
				By default, the minimum size on a 32-bit (x86) system is 1.5 times the amount of physical RAM if physical RAM is less than 1 GB, 
				and equal to the amount of physical RAM plus 300 MB if 1 GB or more is installed. The default maximum size is three times the amount of RAM, 
				regardless of how much physical RAM is installed. 
				#>
				If($TotalPhysicalMemorySize -lt 1)
				{
					$InitialSize = 1.5*1024
					$MaximumSize = 1024*3
					Set-PageFileSize -DL $DL -InitialSize $InitialSize -MaximumSize $MaximumSize
				}
				Else
				{
					$InitialSize = 1024+300
					$MaximumSize = 1024*3
					Set-PageFileSize -DL $DL -InitialSize $InitialSize -MaximumSize $MaximumSize
				}
			}
			Else
			{
				Set-PageFileSize -DL $DL -InitialSize $InitialSize -MaximumSize $MaximumSize
			}
			
			If($Reboot)
			{
				Restart-Computer -ComputerName $Env:COMPUTERNAME -Force
			}
		}
		
		#get current page file size information
		Get-WmiObject -Class Win32_PageFileSetting -EnableAllPrivileges|Select-Object Name, `
		@{Name="InitialSize(MB)";Expression={if($_.InitialSize -eq 0){"System Managed"}else{$_.InitialSize}}}, `
		@{Name="MaximumSize(MB)";Expression={if($_.MaximumSize -eq 0){"System Managed"}else{$_.MaximumSize}}}| `
		Format-Table -AutoSize
	}
}
#endregion
#region Set-PageFileSize
Function Set-PageFileSize{
	Param($DL,$InitialSize,$MaximumSize)
	
	#The AutomaticManagedPagefile property determines whether the system managed pagefile is enabled. 
	#This capability is not available on windows server 2003,XP and lower versions.
	#Only if it is NOT managed by the system and will also allow you to change these.
	$IsAutomaticManagedPagefile = Get-WmiObject -Class Win32_ComputerSystem |Foreach-Object{$_.AutomaticManagedPagefile}
	If($IsAutomaticManagedPagefile)
	{
		#We must enable all the privileges of the current user before the command makes the WMI call.
		$SystemInfo=Get-WmiObject -Class Win32_ComputerSystem -EnableAllPrivileges
		$SystemInfo.AutomaticManagedPageFile = $false
		[Void]$SystemInfo.Put()
	}
	
	Write-Verbose "Setting pagefile on $DL"
	
	#configuring the page file size
	$PageFile = Get-WmiObject -Class Win32_PageFileSetting -Filter "SettingID='pagefile.sys @ $DL'"
	
	Try
	{
		If($PageFile -ne $null)
		{
			$PageFile.Delete()
		}
			Set-WmiInstance -Class Win32_PageFileSetting -Arguments @{name="$DL\pagefile.sys"; InitialSize = 0; MaximumSize = 0} `
			-EnableAllPrivileges |Out-Null
			
			$PageFile = Get-WmiObject Win32_PageFileSetting -Filter "SettingID='pagefile.sys @ $DL'"
			
			$PageFile.InitialSize = $InitialSize
			$PageFile.MaximumSize = $MaximumSize
			[Void]$PageFile.Put()
			
			Write-Host  "Execution Results: Set page file size on ""$DL"" successful."
			Write-Warning "Pagefile configuration changed on computer '$Env:COMPUTERNAME'. The computer must be restarted for the changes to take effect."
	}
	Catch
	{
		Write-Host "Execution Results: No Permission - Failed to set page file size on ""$DL"""
	}
}
#endregion
#region SetPowerOptions
function SetPowerOptions{
}
#endregion
#region GetEnvFromHostname
function GetEnvFromHostname{
param([string]$Hostname)

	if((-not $Hostname) -or $Hostname.Length -lt 1){
		$Hostname = $env:computername
	}
	
	#Strip hostname down to shortname
	$Hostname = ($Hostname -split "\.")[0]

	#And make it all lowercase to simplify regex
	$Hostname = $Hostname.ToLower()
	
	#Prod start with "prod"
	#dev/qa/stage ends with d/q/s
	#or starts with d/q/s/l
	#tools start with "tool"
	switch -regex ($Hostname){
		"^prod.*" {$EnvName = "prod"}
		"^tool" {$EnvName = "tools"}
		"d$"	{$EnvName = "dev"}
		"^d"	{$EnvName = "dev"}
		"q$"	{$EnvName = "qa"}
		"^q"	{$EnvName = "aq"}		
		"s$"	{$EnvName = "stage"}
		"^s"	{$EnvName = "stage"}
		"l$"	{$EnvName = "plt"}
		"^l"	{$EnvName = "plt"}
		default {$EnvName = $null}
	}

	return $EnvName
}
#endregion