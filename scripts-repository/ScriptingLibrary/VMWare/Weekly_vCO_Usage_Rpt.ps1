param([Switch]$Help)

$Usage = @"
This script creates 2 reports (SanDiegReport, ArizonaReport) in C:\Reports depicting usage. no Parameters needed.
"@

if ($Help) {
	Write-Host $Usage -ForegroundColor Yellow -BackgroundColor Black
	throw "Showing Help."
}

function CheckReqSnapIn ($SnapIN)
{
	if (!(Get-PSSnapin -Name "$SnapIN" -ErrorAction SilentlyContinue))
		{
			if (Get-PSSnapin -Registered -Name $SnapIN -ErrorAction SilentlyContinue) {
				Add-PSSnapin $SnapIN
			} else {
				Throw "Required snapin is not present"
			}
		}
}

$ReportsFolder = "C:\Reports"
if (!(Test-Path "$ReportsFolder")) {
	New-Item "$ReportsFolder" -ItemType Directory | Out-Null
}

CheckReqSnapIn "VMware.VimAutomation.Core"
$VCServers = @("bpeca-aevc01", "bpeaz-aevc01")

foreach ($VCS in $VCServers) {

	switch ($VCS) {
			"bpeca-aevc01" {
				$ReportName = "SanDiegoReport.xlsx" 
				$VHOST_Filter = "bpeca01*"
			}
			
			"bpeaz-aevc01" {
				$ReportName = "ArizonaReport.xlsx" 
				$VHOST_Filter = "bpeaz01*"
			}
	}
	Connect-VIServer $VCS | Out-Null
	$VCC = (Get-Cluster -name "*vCLOUD-Resources*").name
	$VHosts = Get-VMHost | ? {$_.parent -like "*$VCC*" -and $_.Name -like $VHOST_Filter}
	$VHosts = $VHosts | Sort -property "Name"
	$DataStores = Get-Datastore -name "AE_*VCloud*"
	$DataStores = $DataStores | sort -Property "Name"

	$XLS = New-Object -ComObject "Excel.Application"
	$Workbook = $XLS.WorkBooks.Add()
	$ComputeSheet = $Workbook.WorkSheets.item(1)
	$ComputeSheet.Name = "Compute"

	$StorageSheet = $Workbook.WorkSheets.item(2)
	$StorageSheet.Name = "Storage"

	#Start out on the storage tab...
	$Y = 2 #Vert
	$X = 1 #Horiz

	$StorageSheet.cells.item($y,$x) = "Name"
	$StorageSheet.cells.item($y,$x).Font.Bold = $true
	$X++
	$StorageSheet.cells.item($y,$x) = "CapacityGB"
	$StorageSheet.cells.item($y,$x).Font.Bold = $true
	$X++
	$StorageSheet.cells.item($y,$x) = "FreeSpaceGB"
	$StorageSheet.cells.item($y,$x).Font.Bold = $true
	$X++
	$StorageSheet.cells.item($y,$x) = "UsedSpaceGB"
	$StorageSheet.cells.item($y,$x).Font.Bold = $true
	$X++

	$X++
	$StorageSheet.cells.item($y,$x) = "Totals"
	$StorageSheet.cells.item($y,$x).Font.Bold = $true
	$Y++

	$StorageSheet.cells.item($y,$x) = "FreeSpaceGB"
	$StorageSheet.cells.item($y,$x).Font.Bold = $true
	$Y++

	$StorageSheet.cells.item($y,$x) = "UsedSpaceGB"
	$StorageSheet.cells.item($y,$x).Font.Bold = $true
	$Y++

	$StorageSheet.cells.item($y,$x) = "CapacityGB"
	$StorageSheet.cells.item($y,$x).Font.Bold = $true
	$Y++

	$Y = 3
	$X = 1

	#Running totals
	$RT_DSCapMB = 0
	$RT_DSUMB = 0
	$RT_DSFMB = 0

	foreach ($DS in $DataStores) {
		
		$StorageSheet.cells.item($y,$x) = $DS.Name
		$X++
		
		$StorageSheet.cells.item($y,$x) = $DS.CapacityMB
		$RT_DSCapMB = $RT_DSCapMB + $DS.CapacityMB
		$X++
		
		$StorageSheet.cells.item($y,$x) = $DS.FreeSpaceMB
		$RT_DSFMB = $RT_DSFMB + $DS.FreeSpaceMB
		$X++
		
		$StorageSheet.cells.item($y,$x) = ($DS.CapacityMB - $DS.FreeSpaceMB)
		$RT_DSUMB = $RT_DSUMB + ($DS.CapacityMB - $DS.FreeSpaceMB)
		$X++

		$Y++
		$X = 1
	}
	$Y = 3
	$X = 7

	$StorageSheet.cells.item($y,$x) = $RT_DSFMB
	$Y++
	$StorageSheet.cells.item($y,$x) = $RT_DSUMB
	$Y++
	$StorageSheet.cells.item($y,$x) = $RT_DSCapMB

	$X++
	$PCT = [Math]::Round((( $RT_DSUMB / $RT_DSCapMB) * 100), 2)
	$StorageSheet.cells.item($y,$x) = "$PCT%"

	#Work on the Compute tab.
	$X = 1
	$Y = 3

	$L3Across = @("Name", "ConnectionState", "PowerState", "CpuTotalMhz", "CpuUsageMhz", "CpuFreeMhz", "MemoryTotalMB", "MemoryUsageMB", "MemoryFreeMB")
	foreach ($Head in $L3Across) {
		$ComputeSheet.Cells.Item($Y, $X) = $Head
		$ComputeSheet.Cells.Item($Y, $X).Font.Underline = $true
		$ComputeSheet.Cells.Item($Y, $X).Font.Bold = $true
		[Void]$ComputeSheet.Cells.Item($Y, $X).BorderAround(1,2)
		$X++
	}

	$X = $X + 2

	$CPUDownL = @("CpuFreeMhz", "CpuUsageMhz")
	foreach ($Title in $CPUDownL) {
		$ComputeSheet.Cells.Item($Y, $X) = $Title
		$ComputeSheet.Cells.Item($Y, $X).Font.Underline = $true
		$ComputeSheet.Cells.Item($Y, $X).Font.Bold = $true
		[Void]$ComputeSheet.Cells.Item($Y, $X).BorderAround(1,2)
		$Y++
	}

	$Y++

	$MEMDownL = @("MemoryFreeMB", "MemoryUsageMB")
	foreach ($Title in $MEMDownL) {
		$ComputeSheet.Cells.Item($Y, $X) = $Title
		$ComputeSheet.Cells.Item($Y, $X).Font.Underline = $true
		$ComputeSheet.Cells.Item($Y, $X).Font.Bold = $true
		[Void]$ComputeSheet.Cells.Item($Y, $X).BorderAround(1,2)
		$Y++
	}
	#Running Totals
	$RT_CPUTOT = 0
	$RT_CPUUSG = 0
	$RT_CPUFRE = 0
	$RT_MEMTOT = 0
	$RT_MEMUSG = 0
	$RT_MEMFRE = 0

	$Y = 4


	foreach ($VH in $VHosts) {
		$X = 1
		
		$ComputeSheet.cells.item($y,$x) = $VH.Name
		$X++
		
		$ComputeSheet.cells.item($y,$x) = $VH.ConnectionState.ToString()
		$X++
		
		$ComputeSheet.cells.item($y,$x) = $VH.PowerState.ToString()
		$X++
		
		$ComputeSheet.cells.item($y,$x) = $VH.CpuTotalMhz
		$RT_CPUTOT = $RT_CPUTOT + $VH.CpuTotalMhz
		$X++
		
		$ComputeSheet.cells.item($y,$x) = $VH.CpuUsageMhz
		$RT_CPUUSG = $RT_CPUUSG + $VH.CpuUsageMhz
		$X++
		
		$ComputeSheet.cells.item($y,$x) = ($VH.CpuTotalMhz - $VH.CpuUsageMhz)
		$ComputeSheet.cells.item($y,$x).Font.Bold = $true
		[Void]$ComputeSheet.Cells.Item($Y, $X).BorderAround(1,2)
		$RT_CPUFRE = $RT_CPUFRE + ($VH.CpuTotalMhz - $VH.CpuUsageMhz)
		$X++
		
		$ComputeSheet.cells.item($y,$x) = $VH.MemoryTotalMB
		$RT_MEMTOT = $RT_MEMTOT + $VH.MemoryTotalMB
		$X++
		
		$ComputeSheet.cells.item($y,$x) = $VH.MemoryUsageMB
		$RT_MEMUSG = $RT_MEMUSG + $VH.MemoryUsageMB
		$X++
		
		$ComputeSheet.cells.item($y,$x) = ($VH.MemoryTotalMB - $VH.MemoryUsageMB)
		$ComputeSheet.cells.item($y,$x).Font.Bold = $true
		[Void]$ComputeSheet.Cells.Item($Y, $X).BorderAround(1,2)
		$RT_MEMFRE = $RT_MEMFRE + ($VH.MemoryTotalMB - $VH.MemoryUsageMB)
		$X++
		
		$Y++
	}
	foreach ($cell in 1..9) {
		[Void]$ComputeSheet.Cells.Item($Y, $cell).BorderAround(1,2)
	}
	$Y++
	foreach ($cell in 1..3) {
		[Void]$ComputeSheet.Cells.Item($Y, $cell).BorderAround(1,2)
	}
	$X = 4

	$ComputeSheet.cells.item($y,$x) = $RT_CPUTOT
	$ComputeSheet.cells.item($y,$x).Font.Bold = $true
	[Void]$ComputeSheet.Cells.Item($Y, $X).BorderAround(1,2)
	$X++
	$ComputeSheet.cells.item($y,$x) = $RT_CPUUSG
	$ComputeSheet.cells.item($y,$x).Font.Bold = $true
	[Void]$ComputeSheet.Cells.Item($Y, $X).BorderAround(1,2)
	$X++
	$ComputeSheet.cells.item($y,$x) = $RT_CPUFRE
	$ComputeSheet.cells.item($y,$x).Font.Bold = $true
	[Void]$ComputeSheet.Cells.Item($Y, $X).BorderAround(1,2)
	$X++

	$ComputeSheet.cells.item($y,$x) = $RT_MEMTOT
	$ComputeSheet.cells.item($y,$x).Font.Bold = $true
	[Void]$ComputeSheet.Cells.Item($Y, $X).BorderAround(1,2)
	$X++
	$ComputeSheet.cells.item($y,$x) = $RT_MEMUSG
	$ComputeSheet.cells.item($y,$x).Font.Bold = $true
	[Void]$ComputeSheet.Cells.Item($Y, $X).BorderAround(1,2)
	$X++
	$ComputeSheet.cells.item($y,$x) = $RT_MEMFRE
	$ComputeSheet.cells.item($y,$x).Font.Bold = $true
	[Void]$ComputeSheet.Cells.Item($Y, $X).BorderAround(1,2)
	$X++

	$Y = 3
	$X = 13

	#Right Hand Side totals.
	$ComputeSheet.cells.item($y,$x) = $RT_CPUFRE
	$Y++

	$ComputeSheet.cells.item($y,$x) = $RT_CPUUSG
	$X++
	$CPUPCT = [Math]::Round((($RT_CPUUSG / $RT_CPUTOT) * 100), 2)
	$ComputeSheet.cells.item($y,$x) = "$CPUPCT%"
	$X--

	$Y = $Y + 2

	$ComputeSheet.cells.item($y,$x) = $RT_MEMFRE
	$Y++

	$ComputeSheet.cells.item($y,$x) = $RT_MEMUSG
	$X++
	$CPUPCT = [Math]::Round((($RT_MEMUSG / $RT_MEMTOT) * 100), 2)
	$ComputeSheet.cells.item($y,$x) = "$CPUPCT%"

	
	$DSOutFile = Join-Path $ReportsFolder $ReportName
	$Workbook.SaveAs($DSOutFile)
	$XLS.Quit()
	
	Disconnect-VIServer * -Confirm:$false
}

#}