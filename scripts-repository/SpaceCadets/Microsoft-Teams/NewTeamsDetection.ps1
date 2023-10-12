$logpath = "C:\ProgramData\Intune\Scripts\Sucess.log"
if (Test-Path -Path $logpath) {
    Write-Host "Teams is installed." -ForegroundColor Green
    exit 0  # Success exit code
} else {
    Write-Host "Teams is not installed." -ForegroundColor Red
    exit 1  # Failure exit code
}
