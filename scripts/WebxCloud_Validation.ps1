<#
.SYNOPSIS
    GDGC WebxCloud Workshop - Windows Environment Validation Script
.DESCRIPTION
    Lightweight verification script for Day 1+ of WebxCloud Workshop.
    Checks installations: WSL 2, Git, Node.js LTS 22.x, Docker Desktop, AWS CLI v2.
    NO installations performed - read-only verification.
.NOTES
    Author: GDGC Cloud Team (Pratham - Cloud Lead)
    Version: 1.0.0
    Date: February 2026
    License: MIT
    Run as: Normal user (no admin required)
.LINK
    https://github.com/GDGC-Cloud/WebxCloud-Workshop-Setup
#>

# ============================================================
# GLOBAL CONFIGURATION
# ============================================================
$script:ScriptVersion = "1.0.0"
$script:WorkshopName = "GDGC WebxCloud Workshop"
$script:ValidationResults = @()
$script:AllPassed = $true

# ============================================================
# COLOR & UI HELPERS
# ============================================================
function Write-Banner {
    $banner = @"

    ╔══════════════════════════════════════════════════════════════╗
    ║                                                              ║
    ║   WebxCloud Workshop - Environment Validation v$script:ScriptVersion           ║
    ║   Windows Edition (Read-Only Check)                          ║
    ║                                                              ║
    ╚══════════════════════════════════════════════════════════════╝

"@
    Write-Host $banner -ForegroundColor Cyan
}

function Write-CheckItem {
    param([string]$Tool)
    Write-Host "`n>> Checking: " -NoNewline -ForegroundColor White
    Write-Host $Tool -ForegroundColor Cyan
}

function Write-Pass {
    param([string]$Message)
    Write-Host "   [✓] $Message" -ForegroundColor Green
}

function Write-Fail {
    param([string]$Message)
    Write-Host "   [✗] $Message" -ForegroundColor Red
    $script:AllPassed = $false
}

function Write-Warn {
    param([string]$Message)
    Write-Host "   [!] $Message" -ForegroundColor Yellow
}

# ============================================================
# VALIDATION FUNCTIONS
# ============================================================
function Test-WSL2 {
    Write-CheckItem "WSL 2"
    
    try {
        $wslStatus = wsl --status 2>$null
        if ($LASTEXITCODE -eq 0) {
            if ($wslStatus -match "Default Version.*2" -or $wslStatus -match "default version.*2") {
                Write-Pass "WSL 2 is installed and set as default"
                $script:ValidationResults += [PSCustomObject]@{
                    Tool = "WSL 2"
                    Status = "PASS"
                    Version = "Default Version 2"
                }
                return $true
            }
            else {
                Write-Warn "WSL is installed but not version 2"
                $script:ValidationResults += [PSCustomObject]@{
                    Tool = "WSL 2"
                    Status = "WARNING"
                    Version = "Not Default Version"
                }
                return $true
            }
        }
    }
    catch { }
    
    Write-Fail "WSL 2 not found"
    $script:ValidationResults += [PSCustomObject]@{
        Tool = "WSL 2"
        Status = "FAIL"
        Version = "Not Installed"
    }
    return $false
}

function Test-Git {
    Write-CheckItem "Git"
    
    try {
        $gitVersion = git --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $gitVersion) {
            Write-Pass $gitVersion
            
            # Check Git config
            $userName = git config --global user.name 2>$null
            $userEmail = git config --global user.email 2>$null
            
            if ($userName -and $userEmail) {
                Write-Pass "Git configured: $userName <$userEmail>"
            }
            else {
                Write-Warn "Git not configured with user.name/user.email"
            }
            
            $script:ValidationResults += [PSCustomObject]@{
                Tool = "Git"
                Status = "PASS"
                Version = $gitVersion
            }
            return $true
        }
    }
    catch { }
    
    Write-Fail "Git not found in PATH"
    $script:ValidationResults += [PSCustomObject]@{
        Tool = "Git"
        Status = "FAIL"
        Version = "Not Installed"
    }
    return $false
}

function Test-NodeJS {
    Write-CheckItem "Node.js LTS 22.x"
    
    try {
        $nodeVersion = node --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $nodeVersion) {
            if ($nodeVersion -match "^v22") {
                Write-Pass "Node.js $nodeVersion (LTS 22.x)"
                
                $npmVersion = npm --version 2>$null
                if ($npmVersion) {
                    Write-Pass "npm v$npmVersion"
                }
                
                $script:ValidationResults += [PSCustomObject]@{
                    Tool = "Node.js"
                    Status = "PASS"
                    Version = "$nodeVersion (npm: $npmVersion)"
                }
                return $true
            }
            else {
                Write-Warn "Node.js $nodeVersion found (expected v22.x LTS)"
                $script:ValidationResults += [PSCustomObject]@{
                    Tool = "Node.js"
                    Status = "WARNING"
                    Version = "$nodeVersion (not v22.x)"
                }
                return $true
            }
        }
    }
    catch { }
    
    Write-Fail "Node.js not found in PATH"
    $script:ValidationResults += [PSCustomObject]@{
        Tool = "Node.js"
        Status = "FAIL"
        Version = "Not Installed"
    }
    return $false
}

function Test-Docker {
    Write-CheckItem "Docker Desktop"
    
    try {
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $dockerVersion) {
            Write-Pass $dockerVersion
            
            # Check if Docker daemon is running
            try {
                docker ps 2>$null | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Pass "Docker daemon is running"
                }
                else {
                    Write-Warn "Docker is installed but daemon not running"
                }
            }
            catch {
                Write-Warn "Docker is installed but daemon not accessible"
            }
            
            $script:ValidationResults += [PSCustomObject]@{
                Tool = "Docker"
                Status = "PASS"
                Version = $dockerVersion
            }
            return $true
        }
    }
    catch { }
    
    # Check if Docker Desktop executable exists
    $dockerDesktopPath = "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $dockerDesktopPath) {
        Write-Warn "Docker Desktop installed but not in PATH (not running?)"
        $script:ValidationResults += [PSCustomObject]@{
            Tool = "Docker"
            Status = "WARNING"
            Version = "Installed (Not Running)"
        }
        return $true
    }
    
    Write-Fail "Docker Desktop not found"
    $script:ValidationResults += [PSCustomObject]@{
        Tool = "Docker"
        Status = "FAIL"
        Version = "Not Installed"
    }
    return $false
}

function Test-AWSCLI {
    Write-CheckItem "AWS CLI v2"
    
    try {
        $awsVersion = aws --version 2>$null
        if ($LASTEXITCODE -eq 0 -and $awsVersion) {
            if ($awsVersion -match "aws-cli/2") {
                Write-Pass $awsVersion
                
                $script:ValidationResults += [PSCustomObject]@{
                    Tool = "AWS CLI"
                    Status = "PASS"
                    Version = $awsVersion
                }
                return $true
            }
            else {
                Write-Warn "AWS CLI v1 found (expected v2): $awsVersion"
                $script:ValidationResults += [PSCustomObject]@{
                    Tool = "AWS CLI"
                    Status = "WARNING"
                    Version = "$awsVersion (not v2)"
                }
                return $true
            }
        }
    }
    catch { }
    
    Write-Fail "AWS CLI v2 not found in PATH"
    $script:ValidationResults += [PSCustomObject]@{
        Tool = "AWS CLI"
        Status = "FAIL"
        Version = "Not Installed"
    }
    return $false
}

# ============================================================
# SUMMARY REPORT
# ============================================================
function Show-Summary {
    Write-Host "`n"
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "VALIDATION SUMMARY" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $passed = ($script:ValidationResults | Where-Object { $_.Status -eq "PASS" }).Count
    $warnings = ($script:ValidationResults | Where-Object { $_.Status -eq "WARNING" }).Count
    $failed = ($script:ValidationResults | Where-Object { $_.Status -eq "FAIL" }).Count
    $total = $script:ValidationResults.Count
    
    foreach ($result in $script:ValidationResults) {
        $statusIcon = switch ($result.Status) {
            "PASS"    { "[✓]"; $color = "Green" }
            "WARNING" { "[!]"; $color = "Yellow" }
            "FAIL"    { "[✗]"; $color = "Red" }
        }
        
        Write-Host "  $statusIcon " -NoNewline -ForegroundColor $color
        Write-Host "$($result.Tool): " -NoNewline -ForegroundColor White
        Write-Host $result.Version -ForegroundColor Gray
    }
    
    Write-Host ""
    
    if ($failed -eq 0 -and $warnings -eq 0) {
        Write-Host "  RESULT: ALL CHECKS PASSED ($passed/$total)" -ForegroundColor Green
        Write-Host "  Your environment is ready for the WebxCloud Workshop!" -ForegroundColor Green
    }
    elseif ($failed -eq 0) {
        Write-Host "  RESULT: MOSTLY READY ($passed/$total passed, $warnings warnings)" -ForegroundColor Yellow
        Write-Host "  Review warnings above. You may proceed with the workshop." -ForegroundColor Yellow
    }
    else {
        Write-Host "  RESULT: NEEDS ATTENTION ($failed/$total failed)" -ForegroundColor Red
        Write-Host "  Run WebxCloud_Setup.ps1 to install missing tools." -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

# ============================================================
# MAIN ENTRY POINT
# ============================================================
function Start-Validation {
    Write-Banner
    
    Write-Host "Running environment checks (read-only)..." -ForegroundColor Gray
    Write-Host "This will NOT install or modify anything.`n" -ForegroundColor Gray
    
    # Run all checks
    Test-WSL2
    Test-Git
    Test-NodeJS
    Test-Docker
    Test-AWSCLI
    
    # Show summary
    Show-Summary
    
    # Exit code
    if ($script:AllPassed) {
        exit 0
    }
    else {
        exit 1
    }
}

# Run validation
Start-Validation
