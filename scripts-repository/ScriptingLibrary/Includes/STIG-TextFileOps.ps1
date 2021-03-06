<# 
.SYNOPSIS
	InsertText will find a starting string in a text file and then insert text after that line. If an ending string is specifed then
	text between the start/end string will be replaced with the provided text.
.DESCRIPTION
	InsertText reads each line in a file and searches for the start string. When it finds the start string it re-writes that line then
	the provided insertion text. If there is an end string specified it will then continue reading lines in the file but not writing
	them until the end string is found. It will then write the end string and any other lines in the file.
	Start and End strings should be Regular Expression syntax for non-ambiguity.
	If the InsertText parameter is not specified and an EndString parameter is, then this function will delete the lines of text between
	StartString and EndString.
	If EndString is not specified then the InsertText will be inserted between the StartString and the next line of text in the file.
.NOTES  
	Author        : Dan Meier  
	Assumptions   :
		Text will be inserted everytime the start string is found.
.EXAMPLE
	InsertText -StartString "<head>" -InsertText "This is the new head section." -EndString "</head>$" -File "c:\wwwroot\index.html"
.OUTPUTS
    Returns a 0 for success; 1 for failure. Writes to the console any failure messages, logs to a log file other informational messages.
#>
Function InsertText {
param (  
	[Parameter()] [string]$StartString, #Required
	[Parameter()] [switch]$IncludeStartString,
	[Parameter()] [string]$SourceFile,
	[Parameter()] [string]$InsertText,  #Optional (if left blank and EndString specified it will DELETE a section of text)
	[Parameter()] [string]$EndString,   #Optional (if left blank then the text will be inserted between the StartString and next line)
	[Parameter()] [switch]$IncludeEndString,
	[Parameter()] [string]$File,        #Required
	[Parameter()] [switch]$IgnoreCase
)
	$ValidParams = $True
	if(!(Test-Path $File)) {
		if ($LoggingCheck) { ToLog -LogFile $LFName -EventID 1 -Text "Unable to find file: $File to Insert Text" }
		$ValidParams = $false
		$retval = 1
	}
	
	If(!$StartString) {
		if ($LoggingCheck) { ToLog -LogFile $LFName -EventID 1 -Text "No StartString specified for Insert Text" }
		$ValidParams = $false
		$retval = 1
	}
	
	If($ValidParams) {
		$tempFile = [System.IO.Path]::GetTempFileName()
		try {
			$NewFile = New-Object System.IO.StreamWriter $tempFile
		} catch {
			if ($LoggingCheck) { ToLog -LogFile $LFName -EventID 1 -Text "InsertText is unable to open the temp file." }
			$ValidParams = $false
		}
	}
	
	If($ValidParams) {
		try {
			$StartRegex = New-Object System.Text.RegularExpressions.Regex($StartString)
			If($EndString) {
				$EndRegex = New-Object System.Text.RegularExpressions.Regex($EndString)
			}
			$FileText = Get-Content $File

			$ReplaceFlag = $false
			
			ForEach($Line in $FileText) {
				If(( $StartRegex.match($Line)).Success ) {
					If(!$IncludeStart) {
						$NewFile.WriteLine( $Line )
					}
					If($SourceFile -and (Test-Path $SourceFile)) {
						(Get-Content $SourceFile) | ForEach { $NewFile.WriteLine($_)}
						$NewFile.Flush()
					} else {
						$NewFile.WriteLine($InsertText)
					}
					If($EndString) {
						$ReplaceFlag = $True
					}
					$SuppressWrite = $true
				}
				If( $EndString -and ($EndRegex.match($Line)).Success ) {
					$ReplaceFlag = $False
					$SuppressWrite = $true
					If(!$IncludeEnd) {
						$NewFile.WriteLine( $Line )
					}
				}
				If(!$SuppressWrite -and !$ReplaceFlag) {
					$NewFile.WriteLine( $Line )
				}
				$SuppressWrite = $false
			}
			
		} catch {
			$NewFile.close()
			if ($LoggingCheck) { ToLog -LogFile $LFName -EventID 1 -Text "Insert Text error: $_.Exception" }
			Remove-Item $tempFile
			$retval = 1
		} finally {
			$NewFile.close()
			if(Test-Path $tempFile) {
				try {
					Move-Item $File "$File.bak" -Force
					Move-Item $tempFile $File -Force
					$retval = 0
				} catch {
					LLToLog -EventID $LLWARN -Text "Failed to move $tempFile to $File"
				}
			} else {
				if ($LoggingCheck) { ToLog -LogFile $LFName -EventID 3 -Text "Insert Text file changes lost" }
				$retval = 1
			}
		}
	}
	return $retval
}
<# 
.SYNOPSIS
	InsertTextXMLNode will accept an XML Element and format the attributes into a function call to InsertText.
.DESCRIPTION
	InsertTextXMLNode will accept an XML Element and format the attributes into a function call to InsertText.
.NOTES  
	Author        : Dan Meier  
	Assumptions   :
		Text will be inserted everytime the start string is found.
.EXAMPLE
	<TextInsert StartString="<head>" InsertText="This is the new header text." EndString="</head>" File="c:\wwwroot\app.config" />
#>
Function InsertTextXMLNode {
param (
	[System.Xml.XmlElement]$Params
)
	$IgnoreCase   = $Params.IgnoreCase
	$StartString  = $Params.StartString
	$IncludeStart = $Params.IncludeStartString
	$EndString    = $Params.EndString
	$IncludeEnd   = $Params.IncludeEndString
	$TargetFile   = $Params.TargetFile
	$InsertText   = $Params.InsertText
	$SourceFile   = $Params.SourceFile

	$ParamHash = @{}
	If($IgnoreCase)   { $ParamHash.Add("-IgnoreCase",$true) }
	If($StartString)  { $ParamHash.Add("-StartString","$StartString") }
	If($IncludeStart) { $ParamHash.Add("-IncludeStartString",$true) }
	If($SourceFile)   { $ParamHash.Add("-SourceFile","$SourceFile") }
	If($InsertText)   { $ParamHash.Add("-InsertText","$InsertText") }
	If($EndString)    { $ParamHash.Add("-EndString","$EndString") }
	If($IncludeEnd)   { $ParamHash.Add("-IncludeEndString",$true) }
	If($TargetFile)   { $ParamHash.Add("-File","$TargetFile") }
	
	InsertText @ParamHash
}
<# 
.SYNOPSIS
	Search will accept an XML Element and replace a string with another string. Used for token replacement.
.DESCRIPTION
	Search will accept an XML Element and replace a string with another string. Used for token replacement.
.NOTES  
	Author        : Dan Meier  
	Assumptions   :
		Text will be inserted everytime the start string is found.
.EXAMPLE
	<TextInsert StartString="<head>" InsertText="This is the new header text." EndString="</head>" File="c:\wwwroot\app.config" />
#>
Function SearchReplace {
param (
	[System.Xml.XmlElement]$SAR
)
$RegexPatt = New-Object System.Text.RegularExpressions.Regex($SAR.FindPattern)

$FileList = Get-ChildItem $SAR.FilePath -Recurse -Filter $SAR.FileFilter
foreach ($File in $FileList) {
	#Sanity check, is the target file -gt 0 bytes?
	$PreSize = $File.Length
    $FileText = (Get-Content $File.FullName)
    $OutFileContents = @()
	$FileText |
        ForEach {
            $Line = $_
            $result = $RegexPatt.match($Line)
		    if ($result.Success -eq "True") {
				$GrpIndex = 1
			    ForEach ($Replacement in $SAR.Item) {
                    if($GrpIndex -lt $result.Groups.Count) {
					    $Line = $Line -replace [regex]::escape($result.Groups[$GrpIndex].Value), $Replacement.ReplaceText
					    $GrpIndex++
                    } else {
                        throw "Too many replacements specified for regex"
                    }
                }
            }
            $OutFileContents += $Line
        }
    }
    $FTS = Get-Date -UFormat "%Y%m%d%H%M%S"
    $BackupFileName = Join-Path $File.Directory  ($File.BaseName + ".$FTS" + $File.Extension)
    Move-Item $File.FullName "$($File.FullName).$FTS"
    $OutFileContents | Set-Content $File.FullName
	#Sanity check, did 'a' file get written? (e.g. non-0 byte file)
	$NewFile = Get-ChildItem $File.FullName
	if($NewFile.Length -gt 0){
		LLToLog -EventID $LLINFO -Text "Apparently successfully updated file $($file.FullName)."
	} else {
		LLToLog -EventID $LLWARN -Text "The file $($File.FullName) could not be written. A backup file was put in c:\temp\$($file.Name)."
		$BackupFile = Join-Path "C:\Temp" $file.Name
		$FileText | Set-Content $BackupFile
		try{
			Copy-Item $BackupFile $File.FullName
		} catch {
			LLToLog -EventID $LLWARN -Text "Tried to copy c:\temp\$($file.Name) to $($File.FullName) but an error occurred. Error $($_.Exception)"
		}
	}
}
Function ReplaceTokens {
param (
    [Parameter(Mandatory=$true)] [string]$XMLFile,
	[Parameter()] [string]$TokenFile
)
    #Get the list of tokens
	# Start with the most specific set of tokens
	# Then fill in any missing tokens from Environment, duplicate tokens will be dropped keeping the more specific tokens
	# Then fill in any missing tokens from Enterprise, again dups will be dropped keeing the more specific tokens (env|custom)

	$TokenHash = @{}
	#Get Specific token hash
	$TokenPath = Join-Path -Path "$script:LocalScriptFolder" -ChildPath "TokenSets"
	$TokenFile = Join-Path -Path $TokenPath -ChildPath $TokenFile
	if (Test-Path $TokenFile){
		LLToLog -EventID $LLTRACE "Using token file $TokenFile"
		$TokenHash = ConvertFrom-StringData ([io.file]::ReadAllText( $TokenFile ))
	} else {
		LLToLog -EventID $LLWARN "No token file found or specified. String specified was [$TokenFile]."
	}
	
	#Get Environment token hash
	$EnvName = GetEnvFromHostname
	if($EnvName){
		$EnvTokFile = "TokenSets\$EnvName.tok"
		$EnvTokPath = Join-Path $script:LocalScriptFolder $EnvTokFile
		if (Test-Path $EnvTokPath){
			$EnvTokenHash += ConvertFrom-StringData ([io.file]::ReadAllText( $EnvTokPath )) #Errors are expected
			foreach($item in $EnvTokenHash.GetEnumerator()){
				if($TokenHash.ContainsKey($item.Name)){
					LLToLog -EventID $LLINFO -Text "'$($item.Name)' in $EnvTokPath was superceded by '$($TokenHash[$item.Name])'"
				} else {
					$TokenHash.Add($item.Name,$item.Value)
				}
			}
		}
	}

	#Get Enterprise/default token hash
	$EntTokFile = "TokenSets\Enterprise.tok"
	$EntTokPath = Join-Path $script:LocalScriptFolder $EntTokFile
	if (Test-Path $EntTokPath){
		$EntTokenHash += ConvertFrom-StringData ([io.file]::ReadAllText( $EntTokPath )) #Errors are expected
		foreach($item in $EntTokenHash.GetEnumerator()){
			if($TokenHash.ContainsKey($item.Name)){
				LLToLog -EventID $LLINFO -Text "'$($item.Name)' in $EntTokPath was superceded by '$($TokenHash[$item.Name])'"
			} else {
				$TokenHash.Add($item.Name,$item.Value)
			}
		}
	}

	$AcctRegex = [regex]'@LOOKUPPWD\((.+)\)'
    $TokenDelimiter = "@@@"


	#ProcessTokenFunctions
	#So right now $TokenHash looks like TokenKeyWord,TokenValue
	#Let's assume some of the TokenValue's look like @LOOKUP(something)
	#We'll use that as a cue to perform a lookup function instead of just using the value
	#So let's search through the $TokenHash and find those.
	($TokenHash.Clone()).GetEnumerator() | foreach {
		if($_.Value -match "@LOOKUPPWD*") {
			#We found a password lookup. Get the username (@LOOKUPPWD(username)) and try to get a password for it
			$Account = [regex]::match($_.Value,$AcctRegex).Groups[1].Value
			$tmpPwd = LSGet-AccountPwd -Account $Account -PasswordFolder "OpsBrain\API Access"
			#Replace @LOOKUPPWD with actual password
			$TokenHash.$($_.Name) = $tmpPwd
		}
	}

	LLToLog -EventID $LLWARN -Text "The following token values will be used for this run: $($TokenHash)"
    #Form the search pattern
    $SearchPattern = ""
    $TokenHash.Keys | foreach {
        $SearchPattern += "$_|"
    }
    #Remove trailing "|"
    $SearchPattern = $SearchPattern.TrimEnd("|")

    $TargetFiles = (Get-ChildItem $script:LocalScriptFolder -recurse | 
        Where-Object {$_.psiscontainer -eq $false} | 
        Where-Object {$_.Extension -eq ".xml" -or $_.Extension -eq ".ini"} |
        Where-Object {!($_.FullName -like "*$TokenFile" )} |
        Where-Object {Get-Content $_.pspath |select-string -pattern "$SearchPattern"})

    foreach ($File in $TargetFiles) {
		Set-ItemProperty $file.fullname -name IsReadOnly -value $false
        Write-Verbose "Replacing tokens in $($File.FullName)"
        (Get-Content $File.FullName) | ForEach-Object {
            $Line = $_
            $TokenHash.GetEnumerator() | ForEach-Object {
                $KeyPattern = $TokenDelimiter + $_.Key + $TokenDelimiter
                if ($Line -match $KeyPattern) {
                    $OldLine = $Line
                    $Line = $Line -replace $KeyPattern, $_.Value
                    LLToLog -EventID $LLTRACE "Replacing [$OldLine] with [$Line]"
                }
            }
            $Line
        } | Set-Content $File.FullName
    }
}
