<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2023 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType

The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode

Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru

Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode

Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging

Disables logging to file for the script. Default is: $false.

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Interactive',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    }
    Catch {
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor = 'Insulet Apps'
    [String]$appName = 'Insulet Co-Op Applications'
    [String]$appVersion = '1'
    [String]$appArch = ''
    [String]$appLang = 'EN'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = '06/17/2023'
    [String]$appScriptAuthor = 'Zach Hayward'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = ''

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.9.3'
    [String]$deployAppScriptDate = '02/05/2023'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'

        ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
        #Show-InstallationWelcome -CloseApps 'iexplore' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Installation tasks here>


        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## Handle Zero-Config MSI Installations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) {
                $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ }
            }
        }
     
    Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\Title-Templates.psm1"
    Import-Module -DisableNameChecking "$PSScriptRoot\..\lib\debloat-helper\Remove-UWPApp.psm1"

    function Remove-BloatwareAppsList() {
    $Apps = @(
        # Default Windows 10+ apps
        "Microsoft.3DBuilder"                    # 3D Builder
        "Microsoft.549981C3F5F10"                # Cortana
        "Microsoft.Appconnector"
        "Microsoft.BingFinance"                  # Finance
        "Microsoft.BingFoodAndDrink"             # Food And Drink
        "Microsoft.BingHealthAndFitness"         # Health And Fitness
        "Microsoft.BingNews"                     # News
        "Microsoft.BingSports"                   # Sports
        "Microsoft.BingTranslator"               # Translator
        "Microsoft.BingTravel"                   # Travel
        "Microsoft.BingWeather"                  # Weather
        "Microsoft.CommsPhone"
        "Microsoft.ConnectivityStore"
        "Microsoft.GetHelp"
        "Microsoft.Getstarted"
        "Microsoft.Messaging"
        "Microsoft.Microsoft3DViewer"
        "Microsoft.MicrosoftOfficeHub"
        "Microsoft.MicrosoftPowerBIForWindows"
        "Microsoft.MicrosoftSolitaireCollection" # MS Solitaire
        "Microsoft.MixedReality.Portal"
        "Microsoft.NetworkSpeedTest"
        "Microsoft.Office.OneNote"               # MS Office One Note
        "Microsoft.Office.Sway"
        "Microsoft.OneConnect"
        "Microsoft.People"                       # People
        "Microsoft.MSPaint"                      # Paint 3D
        "Microsoft.Print3D"                      # Print 3D
        "Microsoft.SkypeApp"                     # Skype (Who still uses Skype? Use Discord)
        "Microsoft.Todos"                        # Microsoft To Do
        "Microsoft.Wallet"
        "Microsoft.Whiteboard"                   # Microsoft Whiteboard
        "Microsoft.WindowsAlarms"                # Alarms
        "microsoft.windowscommunicationsapps"
        "Microsoft.WindowsFeedbackHub"           # Feedback Hub
        "Microsoft.WindowsMaps"                  # Maps
        "Microsoft.WindowsPhone"
        "Microsoft.WindowsReadingList"
        "Microsoft.WindowsSoundRecorder"         # Windows Sound Recorder
        "Microsoft.XboxApp"                      # Xbox Console Companion (Replaced by new App)
        "Microsoft.YourPhone"                    # Your Phone
        "Microsoft.ZuneMusic"                    # Groove Music / (New) Windows Media Player
        "Microsoft.ZuneVideo"                    # Movies & TV

        # Default Windows 11 apps
        "Clipchamp.Clipchamp"				     # Clipchamp – Video Editor
        "MicrosoftWindows.Client.WebExperience"  # Taskbar Widgets
        "MicrosoftTeams"                         # Microsoft Teams / Preview

        # 3rd party Apps
        "ACGMediaPlayer"
        "ActiproSoftwareLLC"
        "AdobePhotoshopExpress"                  # Adobe Photoshop Express
        "Amazon.com.Amazon"                      # Amazon Shop
        "Asphalt8Airborne"                       # Asphalt 8 Airbone
        "AutodeskSketchBook"
        "BubbleWitch3Saga"                       # Bubble Witch 3 Saga
        "CaesarsSlotsFreeCasino"
        "CandyCrush"                             # Candy Crush
        "COOKINGFEVER"
        "CyberLinkMediaSuiteEssentials"
        "DisneyMagicKingdoms"
        "Dolby"                                  # Dolby Products (Like Atmos)
        "DrawboardPDF"
        "Duolingo-LearnLanguagesforFree"         # Duolingo
        "EclipseManager"
        "Facebook"                               # Facebook
        "FarmVille2CountryEscape"
        "FitbitCoach"
        "Flipboard"                              # Flipboard
        "HiddenCity"
        "Hulu"
        "iHeartRadio"
        "Keeper"
        "LinkedInforWindows"
        "MarchofEmpires"
        "Netflix"                                # Netflix
        "NYTCrossword"
        "OneCalendar"
        "PandoraMediaInc"
        "PhototasticCollage"
        "PicsArt-PhotoStudio"
        "Plex"                                   # Plex
        "PolarrPhotoEditorAcademicEdition"
        "RoyalRevolt"                            # Royal Revolt
        "Shazam"
        "Sidia.LiveWallpaper"                    # Live Wallpaper
        "SlingTV"
        "Speed Test"
        "Sway"
        "TuneInRadio"
        "Twitter"                                # Twitter
        "Viber"
        "WinZipUniversal"
        "Wunderlist"
        "XING"

        # Apps which other apps depend on
        "Microsoft.Advertising.Xaml"

       

        # <==========[ DIY ]==========> (Remove the # to Uninstall)

        # [DIY] Default apps i'll keep

        #"Microsoft.FreshPaint"             # Paint
        #"Microsoft.MicrosoftEdge"          # Microsoft Edge
        #"Microsoft.MicrosoftStickyNotes"   # Sticky Notes
        #"Microsoft.WindowsCalculator"      # Calculator
        #"Microsoft.WindowsCamera"          # Camera
        #"Microsoft.ScreenSketch"           # Snip and Sketch (now called Snipping tool, replaces the Win32 version in clean installs)
        #"Microsoft.Windows.Photos"         # Photos

        # [DIY] Common Streaming services

        "SpotifyMusic"                   # Spotify

        # [DIY] Can't be reinstalled

        #"Microsoft.WindowsStore"           # Windows Store

        # Apps which cannot be removed using Remove-AppxPackage
        #"Microsoft.BioEnrollment"
        #"Microsoft.WindowsFeedback"        # Feedback Module
        #"Windows.ContactSupport"
    )

    Remove-UWPApp -AppxPackages $Apps
    }

    # List all Packages:
    #Get-AppxPackage | Select-Object -Property Name, Architecture, Version, Publisher, InstallLocation, IsFramework, IsBundle, IsDevelopmentMode, NonRemovable, SignatureKind, Status, Dependencies | Sort-Object Publisher, Name, Architecture | Format-Table

    # List all Provisioned Packages:
    #Get-AppxProvisionedPackage -Online | Select-Object -Property DisplayName, Architecture, Version, PublisherId, InstallLocation, Region, ResourceId | Sort-Object PublisherId, DisplayName, Architecture | Format-Table

    Remove-BloatwareAppsList # Remove the main Bloat from Pre-installed Apps



        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>

        ## Display a message at the end of the install
        If (-not $useDefaultMsi) {
            Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait
        }
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Uninstallation tasks here>


        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        ## Handle Zero-Config MSI Uninstallations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }

        ## <Perform Uninstallation tasks here>


        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>


    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        ## Handle Zero-Config MSI Repairs
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }
        ## <Perform Repair tasks here>

        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}
