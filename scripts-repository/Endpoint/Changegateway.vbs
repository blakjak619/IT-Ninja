'It is recommended to test the script on a local machine for its purpose and effects. 
'ManageEngine Desktop Central will not be responsible for any 
'damage/loss to the data/setup based on the behavior of the script.

'Description - Sets the gateway address of the local machine.
'Parameters - "<gateway address>"
'Remarks -
'Configuration Type - COMPUTER
'==============================================================

gatewayaddress = WSCript.Arguments.Item(0)
strComputer = "."
Set objWMIService = GetObject("winmgmts:\\" & strComputer & "\root\cimv2")
Set colNetAdapters = objWMIService.ExecQuery _
("Select * from Win32_NetworkAdapterConfiguration where IPEnabled=TRUE")
strGateway = Array(gatewayaddress)
strGatewayMetric = Array(1)
For Each objNetAdapter in colNetAdapters
errGateways = objNetAdapter.SetGateways(strGateway, strGatewaymetric)
Wscript.quit err.number
Next