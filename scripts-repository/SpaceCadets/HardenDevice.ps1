#Create Working Directory
New-Item -Path C:\Temp\CIS-Policy -ItemType Directory -Force

# Copying the CIS-Policy Directory
Copy-Item -Path "$psscriptroot\HardeningKitty.psm1." -Destination C:\Temp\CIS-Policy -Force
Copy-Item -Path "$psscriptroot\HardeningKitty.psd1." -Destination C:\Temp\CIS-Policy -Force
Copy-Item -Path "$psscriptroot\Lists\windows_10_enterprise_22h2_machine.csv" -Destination C:\Temp\CIS-Policy\Lists -Force
Copy-Item -Path "$psscriptroot\Lists\windows_10_enterprise_22h2_machine.csv" -Destination C:\Temp\CIS-Policy\Lists -Force

# Change the current working directory to the CIS-Policy folder
Set-Location -Path "C:\Temp\CIS-Policy"

# Importing the HardeningKitty Module from the specified path
Import-Module "C:\Temp\CIS-Policy\HardeningKitty.psm1"

# Get Windows OS name
$WindowsOSName = (Get-CimInstance -ClassName Win32_OperatingSystem).Caption

# Output the detected Windows OS name
Write-Host "Detected Windows OS name: $WindowsOSName"

# Run the appropriate HardeningKitty based on Windows OS name
if ($WindowsOSName -match "Windows 10") {
    Write-Host "Running the HardeningKitty script for Windows 10..."
    Invoke-HardeningKitty -Mode HailMary -Log -Report -FileFindingList "C:\Temp\CIS-Policy\Lists\windows_10_enterprise_22h2_machine.csv" -SkipRestorePoint
}
elseif ($WindowsOSName -match "Windows 11") {
    Write-Host "Running the HardeningKitty script for Windows 11..."
     Invoke-HardeningKitty -Mode HailMary -Log -Report -FileFindingList "C:\Temp\CIS-Policy\Lists\windows_11_enterprise_22h2_machine.csv" -SkipRestorePoint
}
else {
    Write-Host "Unsupported Windows OS: $WindowsOSName"
}