<#
.SYNOPSIS
    GDGC WebxCloud Workshop - Windows Environment Setup Script
.DESCRIPTION
    Automated setup script for Day 1 of the WebxCloud 3-Day Collaborative Sprint.
    Installs and configures: WSL 2, Git (latest), Node.js LTS 22.x, Docker Desktop (latest), AWS CLI v2.
    Designed for Windows 10 (Build 19041+) and Windows 11.
.NOTES
    Author: GDGC Cloud Team (Pratham - Cloud Lead)
    Version: 1.0.0
    Date: February 2026
    License: MIT
    Run as: Administrator (Required)
.LINK
    https://github.com/GDGC-Cloud/WebxCloud-Workshop-Setup
#>

#Requires -RunAsAdministrator

# ============================================================
# GLOBAL CONFIGURATION
# ============================================================
$script:ScriptVersion = "1.0.0"
$script:WorkshopName = "GDGC WebxCloud Workshop"
$script:Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$script:LogDir = "$env:TEMP\WebxCloud"
$script:LogFile = "$script:LogDir\WebxCloud_Setup_$script:Timestamp.log"
$script:RestartRequired = $false
$script:InstallationResults = @{}

# ============================================================
# COLOR & UI HELPERS
# ============================================================
function Write-Banner {
    $banner = @"

    ╔══════════════════════════════════════════════════════════════╗
    ║                                                              ║
    ║   ██████╗ ██████╗  ██████╗  ██████╗                         ║
    ║  ██╔════╝ ██╔══██╗██╔════╝ ██╔════╝                         ║
    ║  ██║  ███╗██║  ██║██║  ███╗██║                               ║
    ║  ██║   ██║██║  ██║██║   ██║██║                               ║
    ║  ╚██████╔╝██████╔╝╚██████╔╝╚██████╗                         ║
    ║   ╚═════╝ ╚═════╝  ╚═════╝  ╚═════╝                         ║
    ║                                                              ║
    ║   WebxCloud Workshop - Environment Setup v$script:ScriptVersion            ║
    ║   Windows Edition                                            ║
    ║                                                              ║
    ╚══════════════════════════════════════════════════════════════╝

"@
    Write-Host $banner -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Message, [string]$Emoji = ">>")
    $logMsg = "[$(Get-Date -Format 'HH:mm:ss')] [STEP] $Message"
    Write-Host "`n$Emoji  $Message" -ForegroundColor White
    Write-Host ("=" * 60) -ForegroundColor DarkGray
    Add-Content -Path $script:LogFile -Value $logMsg
}

function Write-Info {
    param([string]$Message)
    $logMsg = "[$(Get-Date -Format 'HH:mm:ss')] [INFO] $Message"
    Write-Host "   [i] $Message" -ForegroundColor Gray
    Add-Content -Path $script:LogFile -Value $logMsg
}

function Write-Success {
    param([string]$Message)
    $logMsg = "[$(Get-Date -Format 'HH:mm:ss')] [SUCCESS] $Message"
    Write-Host "   [OK] $Message" -ForegroundColor Green
    Add-Content -Path $script:LogFile -Value $logMsg
}

function Write-Warn {
    param([string]$Message)
    $logMsg = "[$(Get-Date -Format 'HH:mm:ss')] [WARN] $Message"
    Write-Host "   [!] $Message" -ForegroundColor Yellow
    Add-Content -Path $script:LogFile -Value $logMsg
}

function Write-Err {
    param([string]$Message)
    $logMsg = "[$(Get-Date -Format 'HH:mm:ss')] [ERROR] $Message"
    Write-Host "   [X] $Message" -ForegroundColor Red
    Add-Content -Path $script:LogFile -Value $logMsg
}

# ============================================================
# LOGGING SETUP
# ============================================================
function Initialize-Logging {
    if (-not (Test-Path $script:LogDir)) {
        New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
    }

    $header = @"
============================================================
$script:WorkshopName - Environment Setup Log
============================================================
Date       : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
User       : $env:USERNAME
Computer   : $env:COMPUTERNAME
Script Ver : $script:ScriptVersion
============================================================
"@
    Set-Content -Path $script:LogFile -Value $header
    Write-Info "Log file: $script:LogFile"
}

# ============================================================
# RETRY HELPER
# ============================================================
function Invoke-WithRetry {
    param(
        [scriptblock]$ScriptBlock,
        [string]$OperationName = "Operation",
        [int]$MaxRetries = 3,
        [int]$BaseDelaySeconds = 2
    )

    $attempt = 1
    while ($attempt -le $MaxRetries) {
        try {
            Write-Info "Attempt $attempt/$MaxRetries for $OperationName..."
            & $ScriptBlock
            return $true
        }
        catch {
            $errMsg = $_.Exception.Message
            Write-Warn "Attempt $attempt failed: $errMsg"
            Add-Content -Path $script:LogFile -Value "[$(Get-Date -Format 'HH:mm:ss')] [RETRY] $OperationName attempt $attempt failed: $errMsg"

            if ($attempt -lt $MaxRetries) {
                $delay = [math]::Pow($BaseDelaySeconds, $attempt)
                Write-Info "Retrying in $delay seconds..."
                Start-Sleep -Seconds $delay
            }
            $attempt++
        }
    }

    Write-Err "$OperationName failed after $MaxRetries attempts."
    return $false
}

# ============================================================
# REFRESH ENVIRONMENT PATH
# ============================================================
function Update-EnvironmentPath {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
    Write-Info "Environment PATH refreshed."
}

# ============================================================
# SECTION 1: PRE-FLIGHT CHECKS
# ============================================================
function Test-PreFlightChecks {
    Write-Step "Pre-Flight Checks" ">>"

    # 1. Administrator check
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    if (-not $isAdmin) {
        Write-Err "This script must be run as Administrator!"
        Write-Err "Right-click PowerShell -> 'Run as Administrator'"
        exit 1
    }
    Write-Success "Running as Administrator"

    # 2. Windows version check
    $osInfo = Get-CimInstance Win32_OperatingSystem
    $buildNumber = [int]$osInfo.BuildNumber

    if ($buildNumber -lt 19041) {
        Write-Err "Windows Build $buildNumber is too old. Minimum: 19041 (Win10 v2004)"
        exit 1
    }

    $winVersion = if ($buildNumber -ge 22000) { "Windows 11" } else { "Windows 10" }
    Write-Success "OS: $winVersion (Build $buildNumber)"

    # 3. System resources
    $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
    $cpu = Get-CimInstance Win32_Processor
    $cpuName = $cpu.Name.Trim()
    $cpuCores = $cpu.NumberOfCores

    if ($ram -lt 8) {
        Write-Warn "RAM: $ram GB (Minimum 8 GB recommended for Docker)"
    }
    else {
        Write-Success "RAM: $ram GB"
    }
    Write-Success "CPU: $cpuName ($cpuCores Cores)"

    # 4. Disk space check
    $systemDrive = Get-PSDrive -Name ($env:SystemDrive.TrimEnd(':'))
    $freeSpaceGB = [math]::Round($systemDrive.Free / 1GB, 1)

    if ($freeSpaceGB -lt 10) {
        Write-Err "Free disk space: $freeSpaceGB GB (Minimum 10 GB required)"
        exit 1
    }
    elseif ($freeSpaceGB -lt 25) {
        Write-Warn "Free disk space: $freeSpaceGB GB (25 GB recommended)"
    }
    else {
        Write-Success "Free disk space: $freeSpaceGB GB"
    }

    # 5. Internet connectivity
    Write-Info "Checking internet connectivity..."
    try {
        $pingResult = Test-Connection -ComputerName "github.com" -Count 1 -Quiet -ErrorAction Stop
        if ($pingResult) {
            Write-Success "Internet: Connected (github.com reachable)"
        }
        else { throw "Ping failed" }
    }
    catch {
        try {
            $null = Invoke-WebRequest -Uri "https://www.google.com" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
            Write-Success "Internet: Connected (HTTP check passed)"
        }
        catch {
            Write-Err "No internet connection detected!"
            exit 1
        }
    }

    # 6. PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    Write-Success "PowerShell: v$($psVersion.Major).$($psVersion.Minor)"

    return $true
}

# ============================================================
# SECTION 2: VIRTUALIZATION DETECTION
# ============================================================
function Test-Virtualization {
    Write-Step "Virtualization Detection" ">>"

    $vmPlatform = Get-CimInstance Win32_ComputerSystem
    $hypervisorPresent = $vmPlatform.HypervisorPresent

    if ($hypervisorPresent) {
        Write-Success "Hardware Virtualization: Enabled"
        return $true
    }

    $procInfo = Get-CimInstance Win32_Processor
    $virtEnabled = $procInfo.VirtualizationFirmwareEnabled

    if ($virtEnabled) {
        Write-Success "Hardware Virtualization: Enabled (Firmware)"
        return $true
    }

    Write-Err "Hardware Virtualization is DISABLED in BIOS/UEFI"
    Write-Host ""
    Write-Host "   +-------------------------------------------------+" -ForegroundColor Yellow
    Write-Host "   |  HOW TO ENABLE VIRTUALIZATION IN BIOS            |" -ForegroundColor Yellow
    Write-Host "   +-------------------------------------------------+" -ForegroundColor Yellow
    Write-Host "   |  1. Restart your computer                        |" -ForegroundColor Yellow
    Write-Host "   |  2. Press BIOS key during boot:                  |" -ForegroundColor Yellow
    Write-Host "   |     Dell/HP/Lenovo: F2 or F10                    |" -ForegroundColor Yellow
    Write-Host "   |     ASUS/MSI: Del or F2                          |" -ForegroundColor Yellow
    Write-Host "   |     Acer: F2                                     |" -ForegroundColor Yellow
    Write-Host "   |  3. Navigate to: Advanced > CPU Configuration    |" -ForegroundColor Yellow
    Write-Host "   |  4. Enable: Intel VT-x (or AMD-V)               |" -ForegroundColor Yellow
    Write-Host "   |  5. Save and Exit (usually F10)                  |" -ForegroundColor Yellow
    Write-Host "   |  After enabling, re-run this script.             |" -ForegroundColor Yellow
    Write-Host "   |  Need help? Contact GDGC volunteers.             |" -ForegroundColor Yellow
    Write-Host "   +-------------------------------------------------+" -ForegroundColor Yellow
    Write-Host ""

    Add-Content -Path $script:LogFile -Value "[$(Get-Date -Format 'HH:mm:ss')] [CRITICAL] Virtualization disabled in BIOS."

    Write-Warn "WSL 2 and Docker Desktop require virtualization."
    $continueChoice = Read-Host "   Continue without virtualization? (Y/N)"
    if ($continueChoice -ne "Y" -and $continueChoice -ne "y") {
        Write-Info "Exiting. Enable virtualization and re-run."
        exit 0
    }
    return $false
}

# ============================================================
# SECTION 3: WSL 2 INSTALLATION
# ============================================================
function Install-WSL2 {
    Write-Step "WSL 2 Installation" ">>"

    # Check if WSL is already installed and properly configured
    try {
        $wslStatus = wsl --status 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "WSL is already installed"
            if ($wslStatus -match "Default Version.*2" -or $wslStatus -match "default version.*2") {
                Write-Success "WSL 2 is set as the default version"
                $script:InstallationResults["WSL2"] = "Already Installed"
                return $true
            }
            else {
                # WSL installed but not version 2, set default version
                Write-Info "Setting WSL 2 as default version..."
                wsl --set-default-version 2 2>$null
                Write-Success "WSL 2 set as default version"
                $script:InstallationResults["WSL2"] = "Configured"
                return $true
            }
        }
    }
    catch { }

    Write-Info "Installing WSL 2..."

    # Enable WSL feature (with error handling for Windows Insider builds)
    Write-Info "Enabling Windows Subsystem for Linux feature..."
    try {
        $wslFeature = Get-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -ErrorAction Stop
        if ($wslFeature.State -ne "Enabled") {
            $result = Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Windows-Subsystem-Linux" -All -NoRestart -ErrorAction Stop
            if ($result.RestartNeeded) { $script:RestartRequired = $true }
            Write-Success "WSL feature enabled"
        }
        else {
            Write-Success "WSL feature already enabled"
        }
    }
    catch {
        # Fallback for Windows Insider builds where Get-WindowsOptionalFeature may fail
        Write-Warn "Using fallback method (Windows Insider build detected)"
        try {
            dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
            Write-Success "WSL feature enabled via DISM"
        }
        catch {
            Write-Warn "Could not enable WSL feature. Proceeding with wsl --install..."
        }
    }

    # Enable Virtual Machine Platform (with error handling for Windows Insider builds)
    Write-Info "Enabling Virtual Machine Platform..."
    try {
        $vmFeature = Get-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -ErrorAction Stop
        if ($vmFeature.State -ne "Enabled") {
            $result = Enable-WindowsOptionalFeature -Online -FeatureName "VirtualMachinePlatform" -All -NoRestart -ErrorAction Stop
            if ($result.RestartNeeded) { $script:RestartRequired = $true }
            Write-Success "Virtual Machine Platform enabled"
        }
        else {
            Write-Success "Virtual Machine Platform already enabled"
        }
    }
    catch {
        # Fallback for Windows Insider builds
        Write-Warn "Using fallback method (Windows Insider build detected)"
        try {
            dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
            Write-Success "Virtual Machine Platform enabled via DISM"
        }
        catch {
            Write-Warn "Could not enable Virtual Machine Platform. Proceeding with wsl --install..."
        }
    }

    # Modern approach: wsl --install
    Write-Info "Running WSL installation..."
    try {
        wsl --install --no-distribution 2>&1 | Out-Null
        Write-Success "WSL 2 installed via 'wsl --install'"
    }
    catch {
        Write-Warn "Fallback: Downloading WSL 2 kernel update..."
        $wslUpdateUrl = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
        $wslUpdatePath = "$env:TEMP\wsl_update_x64.msi"

        $downloadSuccess = Invoke-WithRetry -ScriptBlock {
            Invoke-WebRequest -Uri $wslUpdateUrl -OutFile $wslUpdatePath -UseBasicParsing
        } -OperationName "WSL 2 Kernel Update Download"

        if ($downloadSuccess) {
            Start-Process msiexec.exe -Wait -ArgumentList "/I $wslUpdatePath /quiet /norestart"
            Write-Success "WSL 2 kernel update installed"
        }
        else {
            Write-Err "Failed to download WSL 2 kernel update"
            $script:InstallationResults["WSL2"] = "Failed"
            return $false
        }
    }

    # Set WSL 2 as default
    Write-Info "Setting WSL 2 as default version..."
    wsl --set-default-version 2 2>$null
    Write-Success "WSL 2 set as default version"

    $script:RestartRequired = $true
    $script:InstallationResults["WSL2"] = "Installed"
    return $true
}

# ============================================================
# SECTION 4: WINGET AVAILABILITY CHECK
# ============================================================
function Test-WingetAvailable {
    Write-Step "Package Manager Detection" ">>"

    try {
        $wingetVersion = winget --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $wingetVersion) {
            Write-Success "winget: Available ($wingetVersion)"
            return $true
        }
    }
    catch { }

    if (Test-Path "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe") {
        Write-Success "winget: Found at WindowsApps"
        return $true
    }

    Write-Warn "winget not found. Will use direct download methods."
    return $false
}

# ============================================================
# SECTION 5: GIT INSTALLATION
# ============================================================
function Install-GitTool {
    param([bool]$WingetAvailable)

    Write-Step "Git Installation" ">>"

    try {
        $gitVersion = git --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitVersion) {
            Write-Success "Git already installed: $gitVersion"
            $script:InstallationResults["Git"] = "Already Installed ($gitVersion)"
            return $true
        }
    }
    catch { }

    Write-Info "Installing Git (latest stable)..."
    $installed = $false

    # Method 1: winget
    if ($WingetAvailable -and -not $installed) {
        Write-Info "Trying winget..."
        try {
            winget install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $installed = $true
                Write-Success "Git installed via winget"
            }
        }
        catch { Write-Warn "winget failed: $($_.Exception.Message)" }
    }

    # Method 2: Direct download
    if (-not $installed) {
        Write-Info "Trying direct download..."
        $downloadSuccess = Invoke-WithRetry -ScriptBlock {
            $gitUrl = "https://github.com/git-for-windows/git/releases/latest/download/Git-2.47.1.2-64-bit.exe"
            $gitPath = "$env:TEMP\GitInstaller.exe"
            Invoke-WebRequest -Uri $gitUrl -OutFile $gitPath -UseBasicParsing
            Start-Process -FilePath $gitPath -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS" -Wait
        } -OperationName "Git Download & Install"
        if ($downloadSuccess) { $installed = $true; Write-Success "Git installed via direct download" }
    }

    if (-not $installed) {
        Write-Err "Git installation failed. Install from https://git-scm.com"
        $script:InstallationResults["Git"] = "Failed"
        return $false
    }

    Update-EnvironmentPath
    try {
        $gitVersion = git --version 2>$null
        Write-Success "Git verified: $gitVersion"
        $script:InstallationResults["Git"] = "Installed ($gitVersion)"
    }
    catch {
        Write-Warn "Git installed but not in PATH yet."
        $script:InstallationResults["Git"] = "Installed (PATH pending)"
    }
    return $true
}

# ============================================================
# SECTION 6: GIT GLOBAL CONFIGURATION
# ============================================================
function Set-GitConfiguration {
    Write-Step "Git Global Configuration" ">>"

    try { git --version 2>$null | Out-Null }
    catch {
        Write-Warn "Git not in PATH. Skipping configuration."
        return $false
    }

    $existingName = git config --global user.name 2>$null
    $existingEmail = git config --global user.email 2>$null

    if ($existingName -and $existingEmail) {
        Write-Info "Existing Git config:"
        Write-Info "  Name:  $existingName"
        Write-Info "  Email: $existingEmail"
        Write-Host ""
        $keep = Read-Host "   Keep existing configuration? (Y/N)"
        if ($keep -eq "Y" -or $keep -eq "y") {
            Write-Success "Git configuration kept"
            return $true
        }
    }

    Write-Host ""
    Write-Host "   Configure Git with your identity:" -ForegroundColor Cyan
    Write-Host ""
    $gitName = Read-Host "   Enter your full name"
    $gitEmail = Read-Host "   Enter your GitHub email"

    if ([string]::IsNullOrWhiteSpace($gitName) -or [string]::IsNullOrWhiteSpace($gitEmail)) {
        Write-Warn "Empty input. Skipping Git configuration."
        return $false
    }

    git config --global user.name "$gitName"
    git config --global user.email "$gitEmail"
    git config --global init.defaultBranch main
    git config --global credential.helper manager

    Write-Success "Git configured: $gitName <$gitEmail>"
    Write-Success "Default branch: main | Credential: Windows Credential Manager"
    return $true
}

# ============================================================
# SECTION 7: NODE.JS LTS 22.x INSTALLATION
# ============================================================
function Install-NodeJS {
    param([bool]$WingetAvailable)

    Write-Step "Node.js LTS 22.x Installation" ">>"

    try {
        $nodeVersion = node --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $nodeVersion) {
            if ($nodeVersion -match "^v22") {
                Write-Success "Node.js already installed: $nodeVersion (LTS 22.x)"
                $npmVersion = npm --version 2>$null
                Write-Success "npm: v$npmVersion"
                $script:InstallationResults["NodeJS"] = "Already Installed ($nodeVersion)"
                return $true
            }
            else {
                Write-Warn "Node.js version $nodeVersion found. Upgrading to LTS 22.x..."
            }
        }
    }
    catch { }

    Write-Info "Installing Node.js LTS 22.x..."
    $installed = $false

    # Method 1: winget
    if ($WingetAvailable -and -not $installed) {
        Write-Info "Trying winget..."
        try {
            winget install --id OpenJS.NodeJS.LTS -e --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $installed = $true
                Write-Success "Node.js installed via winget"
            }
        }
        catch { Write-Warn "winget failed: $($_.Exception.Message)" }
    }

    # Method 2: Direct download MSI
    if (-not $installed) {
        Write-Info "Trying direct download..."
        $downloadSuccess = Invoke-WithRetry -ScriptBlock {
            $nodeUrl = "https://nodejs.org/dist/v22.13.1/node-v22.13.1-x64.msi"
            $nodeMsi = "$env:TEMP\nodejs-installer.msi"
            Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeMsi -UseBasicParsing
            Start-Process msiexec.exe -Wait -ArgumentList "/I `"$nodeMsi`" /quiet /norestart"
        } -OperationName "Node.js Download & Install"
        if ($downloadSuccess) { $installed = $true; Write-Success "Node.js installed via direct download" }
    }

    if (-not $installed) {
        Write-Err "Node.js installation failed. Install from https://nodejs.org"
        $script:InstallationResults["NodeJS"] = "Failed"
        return $false
    }

    Update-EnvironmentPath
    try {
        $nodeVersion = node --version 2>$null
        $npmVersion = npm --version 2>$null
        Write-Success "Node.js verified: $nodeVersion"
        Write-Success "npm verified: v$npmVersion"
        $script:InstallationResults["NodeJS"] = "Installed ($nodeVersion)"
    }
    catch {
        Write-Warn "Node.js installed but not in PATH yet."
        $script:InstallationResults["NodeJS"] = "Installed (PATH pending)"
    }
    return $true
}

# ============================================================
# SECTION 8: DOCKER DESKTOP INSTALLATION
# ============================================================
function Install-DockerDesktop {
    param([bool]$WingetAvailable)

    Write-Step "Docker Desktop Installation" ">>"

    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $dockerVersion) {
            Write-Success "Docker already installed: $dockerVersion"
            $script:InstallationResults["Docker"] = "Already Installed ($dockerVersion)"
            return $true
        }
    }
    catch { }

    # Check if Docker Desktop exe exists but service not running
    $dockerDesktopPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerDesktopPath) {
        Write-Success "Docker Desktop is installed (not running)"
        Write-Info "Start Docker Desktop from Start Menu after setup."
        $script:InstallationResults["Docker"] = "Installed (Not Running)"
        return $true
    }

    Write-Info "Installing Docker Desktop (latest stable)..."
    Write-Info "This may take 5-10 minutes..."
    $installed = $false

    # Method 1: winget
    if ($WingetAvailable -and -not $installed) {
        Write-Info "Trying winget..."
        try {
            winget install --id Docker.DockerDesktop -e --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $installed = $true
                Write-Success "Docker Desktop installed via winget"
            }
        }
        catch { Write-Warn "winget failed: $($_.Exception.Message)" }
    }

    # Method 2: Direct download
    if (-not $installed) {
        Write-Info "Trying direct download..."
        $downloadSuccess = Invoke-WithRetry -ScriptBlock {
            $dockerUrl = "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe"
            $dockerPath = "$env:TEMP\DockerDesktopInstaller.exe"
            Invoke-WebRequest -Uri $dockerUrl -OutFile $dockerPath -UseBasicParsing
            Start-Process -FilePath $dockerPath -ArgumentList "install --quiet --accept-license --backend=wsl-2" -Wait
        } -OperationName "Docker Desktop Download & Install"
        if ($downloadSuccess) { $installed = $true; Write-Success "Docker Desktop installed via direct download" }
    }

    if (-not $installed) {
        Write-Err "Docker Desktop installation failed."
        Write-Err "Install from https://www.docker.com/products/docker-desktop/"
        $script:InstallationResults["Docker"] = "Failed"
        return $false
    }

    $script:RestartRequired = $true
    $script:InstallationResults["Docker"] = "Installed"

    Write-Host ""
    Write-Host "   +-------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "   |  DOCKER DESKTOP - IMPORTANT                      |" -ForegroundColor Cyan
    Write-Host "   +-------------------------------------------------+" -ForegroundColor Cyan
    Write-Host "   |  After setup completes:                          |" -ForegroundColor Cyan
    Write-Host "   |  1. Open Docker Desktop from Start Menu          |" -ForegroundColor Cyan
    Write-Host "   |  2. Accept the license agreement                 |" -ForegroundColor Cyan
    Write-Host "   |  3. Wait for Docker to finish starting           |" -ForegroundColor Cyan
    Write-Host "   |  4. Verify: docker --version                     |" -ForegroundColor Cyan
    Write-Host "   +-------------------------------------------------+" -ForegroundColor Cyan
    Write-Host ""

    return $true
}

# ============================================================
# SECTION 9: AWS CLI V2 INSTALLATION
# ============================================================
function Install-AWSCLI {
    param([bool]$WingetAvailable)

    Write-Step "AWS CLI v2 Installation" ">>"

    try {
        $awsVersion = aws --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $awsVersion) {
            if ($awsVersion -match "aws-cli/2") {
                Write-Success "AWS CLI already installed: $awsVersion"
                $script:InstallationResults["AWSCLI"] = "Already Installed"
                return $true
            }
            else {
                Write-Warn "AWS CLI v1 detected. Upgrading to v2..."
            }
        }
    }
    catch { }

    Write-Info "Installing AWS CLI v2..."
    $installed = $false

    # Method 1: winget
    if ($WingetAvailable -and -not $installed) {
        Write-Info "Trying winget..."
        try {
            winget install --id Amazon.AWSCLI -e --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $installed = $true
                Write-Success "AWS CLI v2 installed via winget"
            }
        }
        catch { Write-Warn "winget failed: $($_.Exception.Message)" }
    }

    # Method 2: Direct download MSI
    if (-not $installed) {
        Write-Info "Trying direct download..."
        $downloadSuccess = Invoke-WithRetry -ScriptBlock {
            $awsUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
            $awsMsi = "$env:TEMP\AWSCLIV2.msi"
            Invoke-WebRequest -Uri $awsUrl -OutFile $awsMsi -UseBasicParsing
            Start-Process msiexec.exe -Wait -ArgumentList "/I `"$awsMsi`" /quiet /norestart"
        } -OperationName "AWS CLI v2 Download & Install"
        if ($downloadSuccess) { $installed = $true; Write-Success "AWS CLI v2 installed via direct download" }
    }

    if (-not $installed) {
        Write-Err "AWS CLI v2 installation failed."
        Write-Err "Install from https://aws.amazon.com/cli/"
        $script:InstallationResults["AWSCLI"] = "Failed"
        return $false
    }

    Update-EnvironmentPath
    try {
        $awsVersion = aws --version 2>$null
        Write-Success "AWS CLI verified: $awsVersion"
        $script:InstallationResults["AWSCLI"] = "Installed"
    }
    catch {
        Write-Warn "AWS CLI installed but not in PATH yet."
        $script:InstallationResults["AWSCLI"] = "Installed (PATH pending)"
    }

    Write-Info "Note: AWS credentials will be configured on Day 2/3."
    return $true
}

# ============================================================
# SECTION 10: POST-INSTALLATION VALIDATION
# ============================================================
function Show-ValidationSummary {
    Write-Step "Post-Installation Validation" ">>"

    Update-EnvironmentPath

    $checks = @(
        @{ Name = "WSL 2";          Cmd = "wsl --version"; Expected = "WSL" },
        @{ Name = "Git";            Cmd = "git --version"; Expected = "git version" },
        @{ Name = "Node.js";        Cmd = "node --version"; Expected = "v22" },
        @{ Name = "npm";            Cmd = "npm --version"; Expected = "" },
        @{ Name = "Docker";         Cmd = "docker --version"; Expected = "Docker" },
        @{ Name = "AWS CLI";        Cmd = "aws --version"; Expected = "aws-cli/2" }
    )

    $passed = 0
    $failed = 0
    $results = @()

    foreach ($check in $checks) {
        try {
            $output = Invoke-Expression $check.Cmd 2>$null
            if ($output) {
                $version = ($output -split "`n")[0].Trim()
                if ($check.Expected -and $version -notmatch [regex]::Escape($check.Expected)) {
                    Write-Warn "$($check.Name): $version (unexpected version)"
                    $results += @{ Name = $check.Name; Status = "WARNING"; Version = $version }
                }
                else {
                    Write-Success "$($check.Name): $version"
                    $results += @{ Name = $check.Name; Status = "PASS"; Version = $version }
                    $passed++
                }
            }
            else {
                throw "No output"
            }
        }
        catch {
            if ($script:InstallationResults.ContainsKey($check.Name) -and $script:InstallationResults[$check.Name] -match "PATH pending") {
                Write-Warn "$($check.Name): Installed (restart terminal to verify)"
                $results += @{ Name = $check.Name; Status = "PENDING"; Version = "PATH pending" }
            }
            else {
                Write-Err "$($check.Name): NOT FOUND"
                $results += @{ Name = $check.Name; Status = "FAIL"; Version = "Not installed" }
                $failed++
            }
        }
    }

    return @{ Passed = $passed; Failed = $failed; Results = $results }
}

# ============================================================
# SECTION 11: INSTALLATION SUMMARY REPORT
# ============================================================
function Show-FinalSummary {
    param($ValidationResults)

    Write-Host ""
    Write-Host ""
    Write-Host "    ============================================================" -ForegroundColor Cyan
    Write-Host "    INSTALLATION SUMMARY" -ForegroundColor Cyan
    Write-Host "    ============================================================" -ForegroundColor Cyan
    Write-Host ""

    # Show installation method results
    foreach ($key in $script:InstallationResults.Keys) {
        $status = $script:InstallationResults[$key]
        if ($status -match "Failed") {
            Write-Host "    [X] $key : $status" -ForegroundColor Red
        }
        elseif ($status -match "Already") {
            Write-Host "    [=] $key : $status" -ForegroundColor DarkGreen
        }
        else {
            Write-Host "    [+] $key : $status" -ForegroundColor Green
        }
    }

    Write-Host ""

    # Validation results
    $passed = $ValidationResults.Passed
    $failed = $ValidationResults.Failed
    $total = $passed + $failed

    if ($failed -eq 0) {
        Write-Host "    RESULT: ALL CHECKS PASSED ($passed/$total)" -ForegroundColor Green
    }
    elseif ($failed -le 1) {
        Write-Host "    RESULT: MOSTLY READY ($passed/$total passed)" -ForegroundColor Yellow
    }
    else {
        Write-Host "    RESULT: NEEDS ATTENTION ($failed/$total failed)" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "    Log file: $script:LogFile" -ForegroundColor Gray
    Write-Host ""

    # Restart prompt
    if ($script:RestartRequired) {
        Write-Host "    +-------------------------------------------------+" -ForegroundColor Yellow
        Write-Host "    |  RESTART REQUIRED                                |" -ForegroundColor Yellow
        Write-Host "    +-------------------------------------------------+" -ForegroundColor Yellow
        Write-Host "    |  A system restart is needed to complete setup.   |" -ForegroundColor Yellow
        Write-Host "    |  After restart, you can re-run this script to    |" -ForegroundColor Yellow
        Write-Host "    |  verify everything is working.                   |" -ForegroundColor Yellow
        Write-Host "    +-------------------------------------------------+" -ForegroundColor Yellow
        Write-Host ""

        $restartNow = Read-Host "    Restart now? (Y/N)"
        if ($restartNow -eq "Y" -or $restartNow -eq "y") {
            Write-Info "Restarting in 10 seconds... (Save your work!)"
            Start-Sleep -Seconds 10
            Restart-Computer -Force
        }
        else {
            Write-Info "Please restart your computer before the workshop."
        }
    }
    else {
        Write-Host "    No restart required. You're all set!" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "    ============================================================" -ForegroundColor Cyan
    Write-Host "    Setup Complete! See you at the WebxCloud Workshop!" -ForegroundColor Cyan
    Write-Host "    ============================================================" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================
# MAIN ENTRY POINT
# ============================================================
function Start-WebxCloudSetup {
    $startTime = Get-Date

    # Display banner
    Write-Banner

    # Initialize logging
    Initialize-Logging

    Add-Content -Path $script:LogFile -Value "[$(Get-Date -Format 'HH:mm:ss')] [START] Setup started"

    # Step 1: Pre-flight checks
    Test-PreFlightChecks

    # Step 2: Virtualization detection
    $virtEnabled = Test-Virtualization

    # Step 3: WSL 2 installation
    if ($virtEnabled) {
        Install-WSL2
    }
    else {
        Write-Warn "Skipping WSL 2 (virtualization disabled)"
        $script:InstallationResults["WSL2"] = "Skipped (No Virtualization)"
    }

    # Step 4: Package manager
    $wingetAvailable = Test-WingetAvailable

    # Step 5: Git
    Install-GitTool -WingetAvailable $wingetAvailable

    # Step 6: Git configuration
    Set-GitConfiguration

    # Step 7: Node.js
    Install-NodeJS -WingetAvailable $wingetAvailable

    # Step 8: Docker Desktop
    if ($virtEnabled) {
        Install-DockerDesktop -WingetAvailable $wingetAvailable
    }
    else {
        Write-Warn "Skipping Docker Desktop (virtualization disabled)"
        $script:InstallationResults["Docker"] = "Skipped (No Virtualization)"
    }

    # Step 9: AWS CLI
    Install-AWSCLI -WingetAvailable $wingetAvailable

    # Step 10: Validation
    $validationResults = Show-ValidationSummary

    # Step 11: Final summary
    $endTime = Get-Date
    $duration = $endTime - $startTime
    Add-Content -Path $script:LogFile -Value "[$(Get-Date -Format 'HH:mm:ss')] [END] Setup completed in $($duration.TotalMinutes.ToString('F1')) minutes"

    Show-FinalSummary -ValidationResults $validationResults

    Write-Info "Total time: $($duration.TotalMinutes.ToString('F1')) minutes"
}

# ============================================================
# RUN THE SETUP
# ============================================================
Start-WebxCloudSetup
