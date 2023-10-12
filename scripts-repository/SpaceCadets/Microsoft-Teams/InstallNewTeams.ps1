# Function to generate a timestamp that is added to the log file
function Get-TimeStamp {
    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

# Define the log file location and download location
$LogDirectory = "C:\ProgramData\Intune\Scripts"
$LogFile = Join-Path -Path $LogDirectory -ChildPath "TeamsDeployment.log"
$DownloadPath = "C:\Temp\MicrosoftTeams"

# Function to generate a log file and output to the console
if ((Test-Path -Path $DownloadPath -PathType Container) -ne $true ) {
    mkdir $DownloadPath | Out-Null
}

# Function to generate a log file and output to the console
if ((Test-Path -Path $LogDirectory -PathType Container) -ne $true ) {
    mkdir $LogDirectory | Out-Null
}

function LogWrite {
    Param (
        [string]$logstring,
        [string]$status = "info"
    )
    
    Add-content $Logfile -value "$(Get-Timestamp) $logstring"
    
    switch ($status) {
        "error" {
            Write-Host $logstring -ForegroundColor Red
        }
        "warning" {
            Write-Host $logstring -ForegroundColor DarkYellow
        }
        "success" {
            Write-Host $logstring -ForegroundColor Cyan
        }
        "overall" {
            Write-Host $logstring -ForegroundColor Green
        }
        default {
            Write-Host $logstring
        }
    }
}

LogWrite "** STARTING Uninstall MS Teams Script **" "overall"

# Check for the presence of Teams executables in specific directories and uninstall if found
$TeamsExePaths = @("C:\Program Files (x86)\Teams Installer\Teams.exe", "C:\Program Files\Teams\teams.exe")

foreach ($TeamsExePath in $TeamsExePaths) {
    if (Test-Path $TeamsExePath) {
        LogWrite "Uninstalling Teams at $TeamsExePath..." "info"
        try {
            Start-Process -FilePath $TeamsExePath -ArgumentList "--uninstall" -Wait -NoNewWindow -ErrorAction Stop
            LogWrite "Teams uninstalled from $TeamsExePath." "success"
        } catch {
            LogWrite "Error uninstalling Teams at $TeamsExePath. Error Message:" "error"
            LogWrite $_.Exception.Message "error"
        }
    }
}

# Removal Machine-Wide Installer
Try {
    Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -eq "Teams Machine-wide Installer"} | Remove-WmiObject
    LogWrite "Teams Machine-Wide Installer removed." "success"
} Catch {
    LogWrite "Teams Machine-Wide Installer not found." "warning"
}

LogWrite "** ENDING Uninstall MS Teams Script **" "overall"

LogWrite "** Starting Install MS Teams Script **" "overall"

# Download and install the New Microsoft Teams
$DownloadPath = "C:\Temp\MicrosoftTeams"
$URI = "https://go.microsoft.com/fwlink/?linkid=2243204&clcid=0x409"
$OutFileName = "teamsbootstrapper.exe"

LogWrite "Attempting to download MS Teams installer for Office version $officeVersion from $URI." "info"

Try {
    Invoke-WebRequest -Uri $URI -OutFile "$DownloadPath\$OutFileName" -Verbose
    LogWrite "Successfully downloaded the New Microsoft Teams Desktop Client." "success"
} Catch {
    LogWrite "Error downloading MS Teams installer. Error Message:" "error"
    LogWrite $_.Exception.Message "error"
}

LogWrite "Attempting to install the New Microsoft Teams Desktop Client." "info"

# Define the path for the log file to capture the output
$OutputDirectory = "C:\ProgramData\Intune\Scripts"
$OutputLog = Join-Path $OutputDirectory "TeamsBootstrapperOutput.log"

# Create a process start info with output redirection
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = Join-Path $DownloadPath "teamsbootstrapper.exe"
$psi.Arguments = "-p"
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

# Start the process
$process = [System.Diagnostics.Process]::Start($psi)

# Capture the standard output and standard error
$standardOutput = $process.StandardOutput.ReadToEnd()
$standardError = $process.StandardError.ReadToEnd()

# Check if the standard output is not empty to determine success
if ($standardOutput -ne "") {
    $fileName = "Sucess"
} else {
    $fileName = "Error"
}

# Construct the dynamic log file path
$dynamicLogFile = Join-Path $OutputDirectory "$fileName.log"

# Write the captured output to the dynamic log file
$standardOutput | Out-File -FilePath $dynamicLogFile
$standardError | Out-File -Append -FilePath $dynamicLogFile

# Wait for the process to finish
$process.WaitForExit()

if ($process.ExitCode -eq 0) {
    LogWrite "Successfully installed the New Microsoft Teams Desktop Client." "success"
} else {
    LogWrite "Error installing MS Teams. Exit Code: $($process.ExitCode)" "error"
    LogWrite "Standard Output:`n$standardOutput" "error"
    LogWrite "Standard Error:`n$standardError" "error"
    LogWrite "** ENDING Installation of MS Teams. MS Teams installation Unsuccessful :(**" "overall"
}
# Check if everything was successful
$success = $true
if ((Test-Path "$DownloadPath\$OutFileName") -eq $false) {
    LogWrite "MS Teams installer not found. Installation failed." "error"
    $success = $false
}
if ($success) {
    # Create a success file in the specified directory
    $successFilePath = Join-Path "C:\ProgramData\Intune\Scripts" "TeamsDeployment.txt"
    "MS Teams installation was successful." | Out-File -FilePath $successFilePath
    LogWrite "Successfully created the success file: $successFilePath" "success"

} else {
    LogWrite "Installation of MS Teams encountered errors. No success file created." "error"
}

# Delete the C:\Temp\MicrosoftTeams directory
Remove-Item -Path  "C:\temp\MicrosoftTeams" -Force -Recurse
LogWrite "Deleted the $DownloadPath directory after successful installation." "success"

LogWrite "MS Teams install = Success." "overall"
