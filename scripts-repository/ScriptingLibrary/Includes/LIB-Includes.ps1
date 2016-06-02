<# 
.SYNOPSIS
	LIB-Includes sources library function files
.DESCRIPTION
	LIB-Includes accepts a LibraryPath and a switch saying NOT to get all includes.
.NOTES  
	Author        : Dan Meier  
	Assumptions   :
		This is a core library function that doesn't rely on any other functions.
		Since there is no LIB-Logging.ps1 in the includes at the time this script runs, this script doesn't log.
	Design Comments
		The intent was to keep this simple. Primarily it's purpose is to determine the Powershell Version and load any version-specific libraries.
		As a convenience, since in most cases it is convenient to just load all libraries, it will also load all libraries.
		However if you have a complicated/non-standard requirement for including libraries, you can specify that only the version-specific libraries
		get included, and then you can handle the rest of the includes in your script.
.PARAMETERS
	$IncludeHash is a hashtable with the following pairs:
	Key = Library Path
	Value = Library file regex
#>
param(
	[string]$DefaultLibraryPath = "\\10.13.0.206\scratch\DML\Scripts",
	[switch]$VersionOnly,
	[switch]$Intentional
)

#Legacy lib includes would include all .ps1 files in the includes folder including this one which would then include the same .ps1 files.
#Throwing the -Intentional switch allows new programs to specify that they want LIB-Includes to handle sourceing files, but would stop legacy scripts from 
#accidently running this script.
if($Intentional) { 
	# include PSVersion Specific
	$psv = $PSVersionTable.PSVersion.Major
    $osv = (Get-CimInstance Win32_OperatingSystem).Version
	switch($psv) {
		3 { #Good until 1/14/2020
			if(Test-Path $DefaultLibraryPath\VersionLibs\PS3-*.ps1) {
				. $DefaultLibraryPath\VersionLibs\PS3-*.ps1
			}
		}
		# Add version 4 when a newer version is released. WMF 5 has already been released for preview 4/2014 and will likely be available as RTM soon. (4/2015?)
		Default { #Do nothing
		}
    }
    # versions listed here: http://en.wikipedia.org/wiki/Ver_(command)
    switch ($osv) {
		6.1.7601 { #Good until 1/14/2020 (Windows 2008 R2 SP1)
			if(Test-Path $DefaultLibraryPath\VersionLibs\6.1.7601-*.ps1) {
				. $DefaultLibraryPath\VersionLibs\6.1.7601-*.ps1
			}
		}
		# Add version 4 when a newer version is released. WMF 5 has already been released for preview 4/2014 and will likely be available as RTM soon. (4/2015?)
		Default { #Do nothing
		}

	}
	if(-not $VersionOnly ) {
		if(Test-Path $DefaultLibraryPath\Includes) {
			Get-ChildItem -Path $DefaultLibraryPath\Includes -Filter "*.ps1" | Where-Object { $_.Name -ne "LIB-Includes.ps1"} | ForEach-Object {
				. $_.FullName
			}
		}
	}
}