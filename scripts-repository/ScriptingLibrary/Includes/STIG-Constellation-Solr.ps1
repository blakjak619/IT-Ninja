function SolrConfig {
param($MasterSlave, $TomcatRoot, [int]$HTTPServicePort, $ApacheServerXML, $ApacheSolrFolder, $SolrHome, [String]$JavaOpts)
	$Usage = @"
	#TomcatRoot = Local Tomcat installation folder. "C:\Program Files\Apache Software Foundation\Tomcat 7.0"
	#ApacheSolrFolder = temp folder where apache files are downloaded to before installation. 
	#ApacheServerXML = Server.xml file under TomcatRoot. "conf\server.xml"
	#HTTPServicePort = HTTP Service Connector port we need to change to. 8888
	#SolrHome = Local directory where solr files will be installed to. "C:\solr"
"@

	#Config Apache-Tom
	$ApacheTomCfg = join-path $TomcatRoot $ApacheServerXML
	$TomCatWebApps = join-path $TomcatRoot "webapps"
	$SolrExample = Join-Path $ApacheSolrFolder "example\solr"
	$CustFiles = Join-Path $ApacheSolrFolder "SolrFiles"
	if (Test-Path "$ApacheTomCfg") {
		[XML]$ServerXML = gc $ApacheTomCfg
		$HTTPServiceConnector = $ServerXML.Server.Service.Connector | ? {$_.protocol -eq "HTTP/1.1"}
		$HTTPServiceConnector.SetAttribute("port", $HTTPServicePort)
		$HTTPServiceConnector.SetAttribute("URIEncoding", "UTF-8")
		try {
			$ServerXML.Save($ApacheTomCfg)
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "Successfully set HTTP Service Connector to port `'$HTTPServicePort`'"
			}
		} catch [Exception] {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: There was an issue setting HTTP Service Connector to port `'$HTTPServicePort`'"
			}
		}
		
		if (Test-Path $ApacheSolrFolder) {
				try {
					#Copy Solr.War file to Solr Home
					copy "$ApacheSolrFolder\dist\apache-solr-3.3.0.war" $TomCatWebApps
					Rename-Item "$TomCatWebApps\apache-solr-3.3.0.war" "solr.war"
					if (!(Test-Path $SolrHome)) {
						$Quiet = New-Item -ItemType "Directory" $SolrHome -Force
					}
				} catch [Exception] {
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: Unable to copy/rename solr.war file. $_"
					}
				}
				try {
					#copy $SolrExample $SolrHome -Recurse
					$SolrExFiles = (gci $SolrExample)
					if ($SolrExFiles) {
						foreach ($Item in $SolrExFiles) {
							$SEF_FN = $Item.FullName
							copy $SEF_FN -Destination $SolrHome -Recurse
						}
					}
				} catch [Exception] {
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: Unable to copy `'$SolrExample`' example files. $_"
					}
				}
				
				try {
					Copy "$CustFiles\logging.properties" "$TomcatRoot\conf\" -Force
				} catch [Exception] {
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: Unable to copy `'$CustFiles\logging.properties`' file. $_"
					}
				}
				
				
				switch ($MasterSlave) {
					"Master" {
						$SolrCfg = "solrconfig (Master).xml"
						$TempSCFG = Join-Path $CustFiles $SolrCfg
					}
					
					"Slave" {
						$SolrCfg = "solrconfig (slave).xml"
						$TempSCFG = Join-Path $CustFiles $SolrCfg
					}
				}
				if ($SolrCfg) {
					try {
						$LocalSHConf = Join-Path $SolrHome "Conf\"
						Copy $TempSCFG -Destination $LocalSHConf -Force
						$SolrCfgLocal = Join-Path $LocalSHConf $SolrCfg
						$RemoveSHConfig = Join-Path $LocalSHConf "solrconfig.xml"
						Remove-Item $RemoveSHConfig -Force
						Rename-Item $SolrCfgLocal "solrconfig.xml" -Force
					} catch [Exception] {
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "FAILURE:: Unable to copy `'$SolrCfg`' file to `'$LocalSHConf`'. $_"
						}
					}
				}
				#Stopwords
				try {
					$LocalSWDest = Join-Path $SolrHome "Conf\"
					Copy "$CustFiles\stopwords.txt" -Destination $LocalSWDest -Force
				} catch [Exception] {
					if ($LoggingCheck) {
						ToLog -LogFile $LFName -Text "FAILURE:: Unable to copy `'$CustFiles\stopwords.txt`' file to `'$LocalSWDest`'. $_"
					}
				}
				
				#Configure the startup mode and -JVMOptions
				$TomcatBin = Join-Path $TomcatRoot "Bin"
				$CurrentDir = $PWD
				if (Test-Path $TomcatBin) {
					try {
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "Attempting to set up Apache Tomcat. `"tomcat7.exe //US//Tomcat7 --Startup=auto --JvmOptions=`"$JavaOpts`""
						}
						cd $TomcatBin
						Invoke-Expression ".\tomcat7.exe //US//Tomcat7 --Startup=auto --JvmOptions=`"$JavaOpts`""
						cd $CurrentDir
					} catch [Exception] {
						if ($LoggingCheck) {
							ToLog -LogFile $LFName -Text "FAILURE:: Unable to setup tomcat java options. $_"
						}
					}
				}
				Start-Service "Tomcat7"
				if ($LoggingCheck) {
					ToLog -LogFile $LFName -Text "Successfully configured Apache Tomcat."
				}
		} else {
			if ($LoggingCheck) {
				ToLog -LogFile $LFName -Text "FAILURE:: ApacheSolrFolder `'$ApacheSolrFolder`' not found!"
			}
		}
	} else {
		if ($LoggingCheck) {
			ToLog -LogFile $LFName -Text "FAILURE:: Apache server.xml file not found at `'$ApacheTomCfg`'"
		}
	}
}