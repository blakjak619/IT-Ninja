param ($Help)
$Usage = @"
#-------------------------------------------------------------------------
# Solution: VMExecutiveSummary.ps1
# Author: Sly Stewart
# Updated: 3/4/2013
# Version: 1.0
<#
# Description:
- Generates HTML page for VMWare cluster executive summary.
	No commandline parameters are needed.

#
# Usage: 
		VMExecutiveSummary.ps1 [-Help]
		
	-Help: Show this message.

#>
# Revision History
# Version 1.0 - Initial Commit 
#-------------------------------------------------------------------------

"@

if ($Help) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	throw "Showing Help."
}
function CheckReqSnapIn ($SnapIN) {
	if (!(Get-PSSnapin -Name "$SnapIN" -ErrorAction SilentlyContinue))
		{
			if (Get-PSSnapin -Registered -Name $SnapIN -ErrorAction SilentlyContinue) {
				Add-PSSnapin $SnapIN
			} else {
				Throw "Required snapin is not present"
			}
		}
}

Function GetHTML {
	param($AZ_CPU, $AZ_MEM, $AZ_STOR, `
	$SD_CPU, $SD_MEM, $SD_STOR, $DateStamp)
	
	$OutputHTML = @"
<html>
  <head>
    <!--Load the AJAX API-->
    <script type="text/javascript" src="https://www.google.com/jsapi"></script>
    <script type="text/javascript">

      // Load the Visualization API and the piechart package.
      google.load('visualization', '1.0', {'packages':['corechart']});

      // Set a callback to run when the Google Visualization API is loaded.
      google.setOnLoadCallback(drawObjects);

	  function drawObjects() {
		azCPU();
		azMEM();
		azSTOR();
		sdCPU();
		sdMEM();
		sdSTOR();
	  }
	  
	  function azCPU() {
	   	// Create the data table.
        var azCPUData = new google.visualization.DataTable();
		azCPUData.addColumn('string', 'type');
		azCPUData.addColumn('number', 'snapshot');
        azCPUData.addRows([
			$AZ_CPU
		]);

        // Set chart options
        var azCPUopts = {'title':'Arizona CPU in Mhz:',
		'width':450,
        'height':200};

        // Instantiate and draw our chart, passing in some options.
        var azCPUpie = new google.visualization.PieChart(document.getElementById('azCPU_pie'));
        azCPUpie.draw(azCPUData, azCPUopts);
	  }
	  
	  function azMEM() {
	   	// Create the data table.
        var azMEMData = new google.visualization.DataTable();
		azMEMData.addColumn('string', 'type');
		azMEMData.addColumn('number', 'snapshot');
        azMEMData.addRows([
			$AZ_MEM
		]);

        // Set chart options
        var azMEMopts = {'title':'Arizona Memory in Mb:',
		'width':450,
        'height':200};

        // Instantiate and draw our chart, passing in some options.
        var azMEMpie = new google.visualization.PieChart(document.getElementById('azMEM_pie'));
        azMEMpie.draw(azMEMData, azMEMopts);
	  }
	  
	  function azSTOR() {
	   	// Create the data table.
        var azSTORData = new google.visualization.DataTable();
		azSTORData.addColumn('string', 'type');
		azSTORData.addColumn('number', 'snapshot');
        azSTORData.addRows([
			$AZ_STOR
		]);

        // Set chart options
        var azSTORopts = {'title':'Arizona Storage in GB:',
		'width':450,
        'height':200};

        // Instantiate and draw our chart, passing in some options.
        var azSTORpie = new google.visualization.PieChart(document.getElementById('azSTOR_pie'));
        azSTORpie.draw(azSTORData, azSTORopts);
	  }
	  
	  function sdCPU() {
	   	// Create the data table.
        var sdCPUData = new google.visualization.DataTable();
		sdCPUData.addColumn('string', 'type');
		sdCPUData.addColumn('number', 'snapshot');
        sdCPUData.addRows([
			$SD_CPU
		]);

        // Set chart options
        var sdCPUopts = {'title':'San Diego CPU in Mhz:',
		'width':450,
        'height':200};

        // Instantiate and draw our chart, passing in some options.
        var sdCPUpie = new google.visualization.PieChart(document.getElementById('sdCPU_pie'));
        sdCPUpie.draw(sdCPUData, sdCPUopts);
	  }
	  
	  function sdMEM() {
	   	// Create the data table.
        var sdMEMData = new google.visualization.DataTable();
		sdMEMData.addColumn('string', 'type');
		sdMEMData.addColumn('number', 'snapshot');
        sdMEMData.addRows([
			$SD_MEM
		]);

        // Set chart options
        var sdMEMopts = {'title':'San Diego Memory in Mb:',
		'width':450,
        'height':200};

        // Instantiate and draw our chart, passing in some options.
        var sdMEMpie = new google.visualization.PieChart(document.getElementById('sdMEM_pie'));
        sdMEMpie.draw(sdMEMData, sdMEMopts);
	  }
	  
	  function sdSTOR() {
	   	// Create the data table.
        var sdSTORData = new google.visualization.DataTable();
		sdSTORData.addColumn('string', 'type');
		sdSTORData.addColumn('number', 'snapshot');
        sdSTORData.addRows([
			$SD_STOR
		]);

        // Set chart options
        var sdSTORopts = {'title':'San Diego Storage in GB:',
		'width':450,
        'height':200};

        // Instantiate and draw our chart, passing in some options.
        var sdSTORpie = new google.visualization.PieChart(document.getElementById('sdSTOR_pie'));
        sdSTORpie.draw(sdSTORData, sdSTORopts);
	  }
	</script>
  </head>

  <body>
	<table>
		<tr>
			<td><b>CPU</b><br><hr /></td>
			<td><b>Memory</b><br><hr /></td>
			<td><b>Storage</b><br><hr /></td>
		</tr>
		<tr>
			<td><div id="azCPU_pie"></div></td>
			<td><div id="azMEM_pie"></div></td>
			<td><div id="azSTOR_pie"></div></td>
		</tr>
		<tr>
			<td><div id="sdCPU_pie"></div></td>
			<td><div id="sdMEM_pie"></div></td>
			<td><div id="sdSTOR_pie"></div></td>
		</tr>
		<tr style="display:table-row">
			<td colspan=3><div align="center"><b>This page was generated on $DateStamp</b></div></td>
		</tr>
	</table>	
  </body>
</html>
	  
"@

return $OutputHTML
}

$ReportsFolder = "C:\inetpub\wwwroot"
$ReportName = "ExecutiveSummary.htm"
if (!(Test-Path "$ReportsFolder")) {
	New-Item "$ReportsFolder" -ItemType Directory | Out-Null
}
$Report = Join-Path $ReportsFolder $ReportName
if (Test-Path $Report) {
	rm $Report -Force
}

CheckReqSnapIn "VMware.VimAutomation.Core"
$VCServers = @("bpeca-aevc01", "bpeaz-aevc01")

foreach ($VCS in $VCServers) {

	switch ($VCS) {
		"bpeca-aevc01" {
			$ReportName = "SanDiegoReport.htm" 
			$VHOST_Filter = "bpeca01*"
		}
		
		"bpeaz-aevc01" {
			$ReportName = "ArizonaReport.htm" 
			$VHOST_Filter = "bpeaz01*"
		}
	}

	Connect-VIServer $VCS | Out-Null
	$VCC = (Get-Cluster -name "*vCLOUD-Resources*").name
	$VHosts = Get-VMHost | ? {$_.parent -like "*$VCC*" -and $_.Name -like $VHOST_Filter}
	$DataStores = Get-Datastore -name "AE_*VCloud*"
	
	$RT_DataCS = 0
	$RT_DataFS = 0
	foreach ($DS in $DataStores) {
		$RT_DataCS = $RT_DataCS + $DS.CapacityMB
		$RT_DataFS = $RT_DataFS + $DS.FreeSpaceMB		
	}
	$RT_DataUS = ($RT_DataCS - $RT_DataFS)
	
	switch ($VCS) {
		"bpeca-aevc01" {
$SDDSData = @"
['Free Space GB', $RT_DataFS],
['Used Space GB', $RT_DataUS]
"@
		}
		
		"bpeaz-aevc01" {
$AZDSData = @"
['Free Space GB', $RT_DataFS],
['Used Space GB', $RT_DataUS]
"@
		}
	}
	
	$RT_CPUTOT = 0
	$RT_CPUUSG = 0
	$RT_MEMTOT = 0
	$RT_MEMUSG = 0
	
	foreach ($VH in $VHosts) {
		$RT_CPUUSG = $RT_CPUUSG + $VH.CpuUsageMhz
		$RT_CPUTOT = $RT_CPUTOT + $VH.CpuTotalMhz
		
		$RT_MEMUSG = $RT_MEMUSG + $VH.MemoryUsageMB
		$RT_MEMTOT = $RT_MEMTOT + $VH.MemoryTotalMB
		
	}
	
	$RT_CPUFRE = ($RT_CPUTOT - $RT_CPUUSG)
	$RT_MEMFRE = ($RT_MEMTOT - $RT_MEMUSG)
	
	switch ($VCS) {
		"bpeca-aevc01" {
			$SDMEMData = @"
['Memory Free MB', $RT_MEMFRE],
['Memory Used MB', $RT_MEMUSG]
"@
			$SDCPUData = @"
['CPU Free MB', $RT_CPUFRE],
['CPU Used MB', $RT_CPUUSG]
"@
		}
		
		"bpeaz-aevc01" {
			$AZMEMData = @"
['Memory Free MB', $RT_MEMFRE],
['Memory Used MB', $RT_MEMUSG]
"@
			$AZCPUData = @"
['CPU Free MB', $RT_CPUFRE],
['CPU Used MB', $RT_CPUUSG]
"@
		}
	}
	Disconnect-VIServer -Server $VCS -Confirm:$false
}

$TS = Get-Date

$FOutput = GetHTML -AZ_CPU $AZCPUData -AZ_MEM $AZMEMData -AZ_STOR $AZDSData -SD_CPU $SDCPUData -SD_MEM $SDMEMData -SD_STOR $SDDSData -DateStamp $TS

Add-Content $Report -Value $FOutput

