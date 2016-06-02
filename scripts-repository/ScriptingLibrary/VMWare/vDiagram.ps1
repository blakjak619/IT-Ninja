Param ($VIServer=$FALSE, $Cluster=$FALSE, $Filter=$False)

#############################################################
#															#
#    vDiagram script by Alan Renouf - Virtu-Al				#
#    Blog: http://teckinfo.blogspot.com/					#
#															#
#    Usage: vDiagram.ps1 -VIServer MYVISERVER				#
#															#
#    Optional paramater of -Cluster MYCLUSTER 	            #
#    Optional parameter of -Filter VMName (exec a -Like *)  #
#		                                                    #
#                                                           #
# Shape file needs to be in 'My Documents\My Shapes' 		#
# folder													#
#															#
# Set the $Savefile as the location you would like the file #
# to be saved												#
#############################################################
$SaveFile = [system.Environment]::GetFolderPath('MyDocuments') + "\My_vDrawing.vsd"
if ($VIServer -eq $FALSE) { $VIServer = Read-Host "Please enter a Virtual Center name or ESX Host to diagram:" }
if ($Filter -eq $false) {$Filter = '*'}
	else {$Filter = '*'+$Filter+'*'}

$shpFile = "\My-VI-Shapes.vss"
$MaximumLeafDepth = 11
$CurrentValue = 1

function add-visioobject ($mastObj, $item)
{
 		Write-Host "Adding item: $mastObj, $x, $y"
		# Drop the selected stencil on the active page, with the coordinates x, y
  		$shpObj = $pagObj.Drop($mastObj, $x, $y)
		# Enter text for the object
  		$shpObj.Text = $item
		#Return the visioobject to be used
		return $shpObj
 }

# Create an instance of Visio and create a document based on the Basic Diagram template.
$AppVisio = New-Object -ComObject Visio.Application
$docsObj = $AppVisio.Documents
$DocObj = $docsObj.Add("Basic Diagram.vst")

# Set the active page of the document to page 1
$pagsObj = $AppVisio.ActiveDocument.Pages
$pagObj = $pagsObj.Item(1)

# Connect to the VI Server
Write-Host "Connecting to $VIServer"
$VIServer = Connect-VIServer $VIServer

# Load a set of stencils and select one to drop
$stnPath = [system.Environment]::GetFolderPath('MyDocuments') + "\My Shapes"
$stnObj = $AppVisio.Documents.Add($stnPath + $shpFile)
$VCObj = $stnObj.Masters.Item("Virtual Center Management Console")
# $HostObj = $stnObj.Masters.Item("ESX Host")
$MSObj = $stnObj.Masters.Item("Microsoft Server")
$LXObj = $stnObj.Masters.Item("Linux Server")
$OtherObj =  $stnObj.Masters.Item("Other Server")
$CluShp = $stnObj.Masters.Item("Cluster")

If ((Get-Cluster) -ne $Null){

	If ($Cluster -eq $FALSE){ $DrawItems = get-cluster }Else {$DrawItems = (Get-Cluster $Cluster)}
		
	$VCLocation = $DrawItems | Get-VMHost
	$x = 1
	$y = 1
	$VCObject = add-visioobject $VCObj $VIServer

	ForEach ($Cluster in $DrawItems)
	{
		$x += 1.5
		$CluVisObj = add-visioobject $CluShp $Cluster
		$x=1
		$y+=1.5
		ForEach ($VMHost in (Get-Cluster $Cluster | Get-VMHost))
		{
			ForEach ($VM in (Get-vmhost $VMHost | get-vm))
			{	
			Write-Host " VMName: $vm"
				If ($vm -like "$Filter") 
				{		
				If ($vm.Guest.OSFUllName -eq $Null)
					{
						$Object2 = add-visioobject $OtherObj $VM
					}
					Else
					{
						If ($vm.Guest.OSFUllName.contains("Microsoft") -eq $True)
						{
							$Object2 = add-visioobject $MSObj $VM
						}
						else
						{
							$Object2 = add-visioobject $LXObj $VM
						}
					}	
					$Object1 = $Object2
					if (($MaximumLeafDepth -ne 0) -and ($CurrentValue -eq $MaximumLeafDepth)) {
						$CurrentValue = 1
						$y += 1.5
						$x = 1
					}
					Else {
						$x += 1.5
						$CurrentValue++ 
					}
				}
			}
		}
	}
}
Else
{
	$DrawItems = Get-VMHost
	
	$x = 0
	$y = 0
	
	$VCObject = add-visioobject $VCObj $VIServer
	
	ForEach ($VMHost in $DrawItems)
	{
		{		
			If ($vm.Guest.OSFUllName -eq $Null)
			{
				$Object2 = add-visioobject $OtherObj $VM
			}
			Else
			{
				If ($vm.Guest.OSFUllName.contains("Microsoft") -eq $True)
				{
					$Object2 = add-visioobject $MSObj $VM
				}
				else
				{
					$Object2 = add-visioobject $LXObj $VM
				}
			}	
			$Object1 = $Object2
		}
	}
}

# Resize to fit page
$pagObj.ResizeToFitContents()


# Zoom to 50% of the drawing - Not working yet
#$Application.ActiveWindow.Page = $pagObj.NameU
#$AppVisio.ActiveWindow.zoom = [double].5

# Save the diagram
$DocObj.SaveAs("$Savefile")

# Quit Visio
#$AppVisio.Quit()
Write-Output "Document saved as $savefile"
Disconnect-VIServer -Server $VIServer -Confirm:$false