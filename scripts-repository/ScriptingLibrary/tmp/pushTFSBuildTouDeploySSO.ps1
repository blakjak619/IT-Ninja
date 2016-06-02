
param (
    [Parameter(Mandatory=$True)][string]$appStack, # application stack in uDeploy, this parameter passed in the build definition
    [string]$tfsBuildNumber = $Env:TF_BUILD_BUILDNUMBER, #TFS_BUILD environment variable 
    [string]$srcLocation = $Env:TF_BUILD_SOURCESDIRECTORY,  #TFS_BUILD environment variable 
    [string]$binLocation = $Env:TF_BUILD_BINARIESDIRECTORY  #TFS_BUILD environment variable
    ) 
#this script is used for Bpi.SingleSignOn.CI build only because it does not follow the package naming convention

# first thing first, JAVA_HOME must be set
if (!$env:JAVA_HOME) { 
    $jpath = "C:\Program Files\Java"
    $vj=@("7","8")    # valid versions: 7,8
    # troll the subdirs for a jre
    if (Test-Path $jpath ) { 
        $subdirs =  gci $jpath
        foreach ($dir in $subdirs) {
            if ($dir.FullName.ToString() | Select-String "jre" | Select-String $vj) {  $env:JAVA_HOME = $dir.FullName }
         }
    
    if (!$env:JAVA_HOME) { "Could not find/set JAVA_HOME environment variable!" }
    }
} # end JAVA_HOME


$split = $tfsBuildNumber -split "_"

[string]$buildDefinition = $split[0]
[string]$buildNumber = $split[1]
[string]$udAppType
[string]$componentName


#set value of -base argument, the package item(s) get copied here
[string]$packagePath = md $srcLocation"\temp"
 
 # Determine type of coponent, either APP or CFG, and the package location
    if($buildDefinition -match  "\.CI")
    {
        $udAppType = "APP"
        $componentName = $buildDefinition.TrimEnd(".CI")
        $componentName = $componentName.TrimStart("Bpi.")
       
        #determine the package folder name
        [string[]] $determinePackageFolder = Get-ChildItem ($binLocation + "\_PublishedWebsites") | ?{ $_.PSIsContainer } 

                     
            if($determinePackageFolder -match "_Package")
            {
                [string]$packageFolder = "_Package"                
            }
            else
            {
                Write-Output "Unknown package folder, exit" | Out-File $binLocation\pushBuild.log -Append
                Exit               
            }

            #check package path exists
            if(Test-Path $binLocation\_PublishedWebsites\$componentName$packageFolder)
            {
                #copy the items to be deployed to the temp location
                Copy-Item $binLocation\_PublishedWebsites\$componentName$packageFolder\*.zip $packagePath
                Write-Output "Package found and copied to temp area for upload to uDeploy"  | Out-File $binLocation\pushBuild.log -Append
            }
            else
            {
                Write-Output "Package folder does not exist, build can not be published to uDeploy"  | Out-File $binLocation\pushBuild.log -Append
                Exit
            }
     
    }  
 
    elseif($buildDefinition -match  "\.CFG") 
    {
        $udAppType = "CFG"
        $componentName = $buildDefinition.TrimEnd(".CFG")
        #copy the items to be deployed
        Copy-Item $binLocation\*.xml $packagePath

    }
    else
    {
        Write-Output "This is not a deployable build, ending process"  | Out-File $binLocation\pushBuild.log -Append
        Exit
    }

    #set component name for uDedloy
    [string]$component = $appStack+"_"+$udAppType+"_Bpi."+$componentName 
 
 

# sets globals for powershellscripts to call 
# requires C:\udclient\udclient.cmd
# source the uDeploy globals file
. $srcLocation\Enterprise\Systems\Scripts\Powershell\uDIncludes\uDeployGlobals.ps1


# call udclient, pass base parameters and create version in uDeploy
& $uDCMD $uDBaseParams createVersion -component $component -name $buildNumber -verbose | Out-File $binLocation\pushBuild.log -Append

Sleep 10

# call udclient, pass base parameters and add files to version in uDeploy
& $uDCMD $uDBaseParams addVersionFiles -component $component -version $buildNumber -base $packagePath -verbose | Out-File $binLocation\pushBuild.log -Append     

Sleep 10

#check if the artifact(s) were uploaded and if not add status to version to indicate it is empty. 
if(select-string -path $binLocation\pushBuild.log -pattern "Uploading file"){

    Write-Output "Artifact upload to uDeploy completed successfully" | Out-File $binLocation\pushBuild.log -Append
}
else
{
    Write-Output "Artifact upload to uDeploy was not successful" | Out-File $binLocation\pushBuild.log -Append
    #Unsuccessful upload to udeploy will not fail the TFS build, the build can be manually uploaded from withing uDeploy
	#add a version status in uDeploy 
    & $uDCMD $uDBaseParams addVersionStatus -component $component -version $buildNumber -status "Empty version, do not use" -verbose | Out-File $binLocation\pushBuild.log -Append

} 
Sleep 10

