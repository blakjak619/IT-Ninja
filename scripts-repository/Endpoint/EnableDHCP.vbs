'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Script to Enable DHCP
'Parameters -
'Remarks -
'Configuration Type - COMPUTER
'==============================================================

 on error resume next
argIndex = 0
retValue = 0
silent = 1

retValue = enableDHCP()
wscript.quit retValue

function enableDHCP()
    on error resume next
	strServerName = "."
	aliveconnection = 0
    Set objWMIService =    GetObject("winmgmts:{impersonationLevel=impersonate}!\\" & strServerName & "\root\cimv2")
    Set colNICConfigs = objWMIService.ExecQuery("SELECT DNSServerSearchOrder, Description FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = True")
    for each objNICConfig in colNICConfigs
		aliveconnection = 1
        OldDNSConfiguration = Join(objNICConfig.DNSServerSearchOrder, ",")
			retval = objNICConfig.EnableDHCP()
			retval = objNICConfig.SetDNSServerSearchOrder(null)			
    next
	setDNS = retValue
END function


sub Display(String)
'wscript.echo String
	if silent = 0 then
		Wscript.echo String
	end if
end sub
