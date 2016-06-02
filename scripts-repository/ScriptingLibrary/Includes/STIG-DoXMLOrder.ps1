<# 
.SYNOPSIS
	CmdEng-XML is a general XML processing engine, similar in function to STIG-ServerStandup.ps1.
.DESCRIPTION
	CmdEng-XML is a general XML processing engine, similar in function to STIG-ServerStandup.ps1; the difference being that CmdEng-XML processes XML elements in
	the order that they appear in the XML file whereas STIG-ServerStandup processes XML elements in the order they are looked for in the script itself.
	This script allows the XML to specify what task AND what order they will be performed in.
	As of the initial check-in of the script CmdEng-XML does not process any of the XML elements that STIG-ServerStandup does, but it is expected they will be
	added as needed.
.NOTES  
	Author        : Dan Meier  
	Assumptions   :
#>
Function DoXMLOrder{
param(
	[xml]$XMLParams
)

	$XMLDoc = $XMLParams


	#region process XML
	[System.Xml.XmlElement]$rootNode = $xmlDoc.get_documentElement()
	foreach($Activity in $rootNode.ChildNodes) {
		LLToLog -EventID $LLTRACE -Text "Processing child node $($Activity.Name)"
		switch(($Activity.Name).ToLower()) {
			"processingorder" { 
				LLToLog -EventID $LLTRACE -Text "Processing Order is $($Activity.InnerText)"
				continue
			} #Ignore. This is not an actionable element
			"#comment" { 
				LLToLog -EventID $LLTRACE -Text "$($Activity)"
				continue
			} #Ignore. This is not an actionable element
			"bindependency" {
				foreach($SubActivity in $Activity.ChildNodes){
					switch($SubActivity.LocalName){
						"ServerBinRoot" {
							$BinServer = $SubActivity.Name
							continue
						}
						"Folder" {
							ProcessFolderActions -FolderInfo $SubActivity
							continue
						}
					}
				}
				continue
			}
			"archive" { $result = RotateLogs -ArchivePath $Activity.dstPath -ArchivePattern $Activity.dstPattern -FileFilter $Activity.File -LogPath $Activity.srcPath }
			"purge" { $result = PurgeFiles -ArchivePath $Activity.Path -DaysToKeep $Activity.Days -FileFilter $Activity.File }
			"taskscheduler" { $result = TSScheduleTask -TaskNode $Activity }
			"removefile" { $result = ProcessRemoveFileDateXML $XMLDoc.CmdEngXML.RemoveFile }
			"Logging" {} #Ignore this one, Logging is handled by the STIG-ServerStandup script.
			"Folders" { } #Ignore this one, Folders is handled by the STIG-ServerStandup script.
			"localrights" {
				$Rights = $XMLParams.params.LocalRights
				if ($Rights) {
					foreach($RightSetting in $Rights) {
						$Action = $RightSetting.Action.ToLower()
						$User = $RightSetting.User
						$Right = $RightSetting.Right
						switch ($Action) {
							"add"    { AddAccountPolicy    -account $User -right $Right }
							"remove" { RemoveAccountPolicy -account $User -right $Right }
							default  { if ($LoggingCheck) {ToLog -LogFile $LFName -EventID $WARNING -Text "Action $Action not support for LocalRights"} }
						}
					}
				}
				continue
			}
			"envvars"{ 
				Process-EnvVarNode $Activity 
				continue
			}
			"IIS" {
				foreach($SubActivity in $Activity.ChildNodes){
					switch($SubActivity.Name){
						"WWWROOT" {$WWWROOT = $SubActivity.InnerText}
						"CreateFolderStr" { ProcessWWWROOT -FStructure $SubActivity }
						"ManageAppPool" {
							foreach($AppPoolElement in $SubActivity.Pool){
								switch($AppPoolElement.Action){
									"Add" {ProcessAppPoolAdd -Pool $AppPoolElement}
									"Delete" {ProcessAppPoolDelete -Pool $AppPoolElement}
								}
							}
							continue
						}
						"WebConfig" {
							foreach($Config in $SubActivity.Config){
								switch($Config.Action){
									"Add"{
										AddWebConfigParser -ConfigInfo $Config
									}
								}
							}
							continue
						}
						"WebSites" {
							foreach($WSite in $SubActivity.Site){
								ProcessSiteAction -Site $WSite
							}
						}
					}
				}
				continue
			}
			"Filesystem" {
				foreach($SubActivity in $Activity.ChildNodes){
					switch($SubActivity.Name){
						"Permissions" { ProcessPerms -AdjustPermissions $Activity }
					}
				}
				continue
			}
			"DSC" { 
				Process-DSC $Activity 
				continue
			}
			Default { LLToLog -EventID $LLWARN -Text "Unknown activity name $($Activity.Name). No action taken." }
		}
	}
	#endregion
	return $true
}