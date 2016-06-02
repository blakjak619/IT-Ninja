<#
.SYNOPSIS
	WCFMSMQActivator is intended to wake up Subscriber services in a PubSub model
.DESCRIPTION
    WCFMSMQActivator will "wake up" subscriber services with the following criteria:
        Must have msmq enabledProtocols
        Must be a Started service
       #deprecated: Service must be named *Logger* or *Manager* (these are the subscriber services listed in the DB)
    Will log to a local WCFMSMQActivator.log file
    Intended to be executed as a Scheduled Task as a user that has rights to view the queue for the respective environment (e.g. bridgepoint\*svc_msmqAdapter)
.NOTES  
    File Name  : WCFMSMQActivator.ps1 
	Author  : Ryan Zaleski/Todd Pluciennik
    Date	: 3/6/2015
.EXAMPLE
	WCFMSMQActivator.ps1
#>

$sw = [Diagnostics.Stopwatch]::StartNew()
Import-Module WebAdministration
$log = "WCFMSMQActivator.log"
# define the match criteria for services, case insensitive
# $subSvcs='(manager)|(logger)'

# array to contain the urls to flick
$urls = @()

if (Test-Path $log)
{
    Remove-Item $log
}



foreach ($webapp in Get-WebApplication)
{

    if ($webapp.enabledProtocols -like '*msmq*')
    {
        # obtain the corresponding app pool
        $appPool=$webapp.applicationPool

        if ( (Get-WebAppPoolState -name $appPool).value -eq "Started") {

            foreach ($svc in Get-ChildItem $webapp.PhysicalPath -Include "*.svc" -Recurse)
            {
                #if ($svc.Name -match $subSvcs) { 
                    $url = "http://localhost:@@@sitePort@@@" + $webapp.path + "/" + $svc.Name
                    if (!($urls -match $url))
                    {
                        $urls += $url
                    }
                
                 #}

                
            }
        } # only started app pools
    }
}

#region scheduled task
# powershell does not work with the get-webapplication when a scheduled task
if ( !($webapp) ) {
     
     # use appcmd to obtain pool status and config
     $started = cmd /c C:\Windows\System32\inetsrv\appcmd.exe list apppool /state:Started
     $iiscfg = cmd /c C:\Windows\System32\inetsrv\appcmd.exe list config

    foreach ($obj in gci -path D:\WWWROOT\@@@siteRoot@@@\ -filter *.svc -Recurse)
    {
        $webapp = Split-Path -Leaf $obj.Directory 
        $iisMSMq = $iiscfg | Select-String msmq | Select-String $webapp
        $isStarted =  $started | Select-String $webapp
        # see if it's msmq and started
        if ($iisMSMq-and $isStarted ) {$webapp }

         $svc = $obj.Name
        # if ($svc -match $subSvcs) { 
             $url = "http://localhost:@@@sitePort@@@" + "/" + $webapp + "/" + $svc
              if (!($urls -match $url))
                    {
                        $urls += $url
                    }
         #    }
    }

}
#endregion

foreach ($url in $urls)
{
    Add-Content $log $url -Encoding Ascii
    $req = [system.Net.WebRequest]::Create($url)
    $req.UseDefaultCredentials = $true
    $req.Timeout = 10000 # 10 secs

    try
    {
        $res = $req.GetResponse()
        $res.Close()
        
    } catch [System.Net.WebException] {
       $res = $_.Exception.Response
    }
    
    
    Add-Content $log ([int]$res.StatusCode).ToString() -Encoding Ascii
}
$sw.Stop()
# elapsed time
Add-Content $log $sw.Elapsed -Encoding Ascii