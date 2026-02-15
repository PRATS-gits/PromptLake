#!/usr/bin/env bash
# ============================================================
# GDGC WebxCloud Workshop - macOS Environment Setup Script
# ============================================================
# Automated setup for Day 1 of the WebxCloud 3-Day Sprint.
# Installs: Homebrew, Git, Node.js LTS 22.x, Docker Desktop, AWS CLI v2.
# Supports: macOS 12+ (Monterey+), Intel & Apple Silicon
#
# Author: GDGC Cloud Team (Pratham - Cloud Lead)
# Version: 1.0.0
# Date: February 2026
# Usage: bash WebxCloud_Setup_macOS.sh
# ============================================================

set -euo pipefail

# ============================================================
# GLOBAL CONFIGURATION
# ============================================================
SCRIPT_VERSION="1.0.0"
WORKSHOP_NAME="GDGC WebxCloud Workshop"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="$HOME/webxcloud_logs"
LOG_FILE="$LOG_DIR/WebxCloud_Setup_$TIMESTAMP.log"
declare -A INSTALL_RESULTS 2>/dev/null || declare INSTALL_RESULTS=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
WHITE='\033[1;37m'
NC='\033[0m'

# ============================================================
# UI HELPERS
# ============================================================
write_banner() {
    echo -e "${CYAN}"
    echo "    ╔══════════════════════════════════════════════════════════════╗"
    echo "    ║                                                              ║"
    echo "    ║   ██████╗ ██████╗  ██████╗  ██████╗                         ║"
    echo "    ║  ██╔════╝ ██╔══██╗██╔════╝ ██╔════╝                         ║"
    echo "    ║  ██║  ███╗██║  ██║██║  ███╗██║                               ║"
    echo "    ║  ██║   ██║██║  ██║██║   ██║██║                               ║"
    echo "    ║  ╚██████╔╝██████╔╝╚██████╔╝╚██████╗                         ║"
    echo "    ║   ╚═════╝ ╚═════╝  ╚═════╝  ╚═════╝                         ║"
    echo "    ║                                                              ║"
    echo "    ║   WebxCloud Workshop - Environment Setup v${SCRIPT_VERSION}            ║"
    echo "    ║   macOS Edition                                              ║"
    echo "    ║                                                              ║"
    echo "    ╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

write_step() {
    local msg="$1"
    echo ""
    echo -e "${WHITE}>> ${msg}${NC}"
    echo -e "${GRAY}$(printf '=%.0s' {1..60})${NC}"
    echo "[$(date +%H:%M:%S)] [STEP] $msg" >> "$LOG_FILE"
}

write_info() {
    echo -e "   ${GRAY}[i] $1${NC}"
    echo "[$(date +%H:%M:%S)] [INFO] $1" >> "$LOG_FILE"
}

write_success() {
    echo -e "   ${GREEN}[OK] $1${NC}"
    echo "[$(date +%H:%M:%S)] [SUCCESS] $1" >> "$LOG_FILE"
}

write_warn() {
    echo -e "   ${YELLOW}[!] $1${NC}"
    echo "[$(date +%H:%M:%S)] [WARN] $1" >> "$LOG_FILE"
}

write_error() {
    echo -e "   ${RED}[X] $1${NC}"
    echo "[$(date +%H:%M:%S)] [ERROR] $1" >> "$LOG_FILE"
}

# ============================================================
# LOGGING SETUP
# ============================================================
init_logging() {
    mkdir -p "$LOG_DIR"
    cat > "$LOG_FILE" << EOF
============================================================
$WORKSHOP_NAME - Environment Setup Log (macOS)
============================================================
Date       : $(date '+%Y-%m-%d %H:%M:%S')
User       : $(whoami)
Hostname   : $(hostname)
Script Ver : $SCRIPT_VERSION
============================================================
EOF
    write_info "Log file: $LOG_FILE"
}

# ============================================================
# RETRY HELPER
# ============================================================
invoke_with_retry() {
    local operation="$1"
    shift
    local max_retries=3
    local attempt=1
    local delay=2

    while [ $attempt -le $max_retries ]; do
        write_info "Attempt $attempt/$max_retries for $operation..."
        if "$@" 2>>"$LOG_FILE"; then
            return 0
        fi
        write_warn "Attempt $attempt failed for $operation"
        if [ $attempt -lt $max_retries ]; then
            local wait_time=$((delay ** attempt))
            write_info "Retrying in ${wait_time}s..."
            sleep "$wait_time"
        fi
        attempt=$((attempt + 1))
    done

    write_error "$operation failed after $max_retries attempts."
    return 1
}

# ============================================================
# SECTION 1: PRE-FLIGHT CHECKS
# ============================================================
pre_flight_checks() {
    write_step "Pre-Flight Checks"

    # 1. macOS version
    local macos_ver
    macos_ver=$(sw_vers -productVersion)
    local major_ver
    major_ver=$(echo "$macos_ver" | cut -d. -f1)

    if [ "$major_ver" -lt 12 ]; then
        write_error "macOS $macos_ver is too old. Minimum: macOS 12 (Monterey)"
        exit 1
    fi
    write_success "macOS: $macos_ver"

    # 2. Architecture
    local arch
    arch=$(uname -m)
    if [ "$arch" = "arm64" ]; then
        write_success "Architecture: Apple Silicon (arm64)"
    else
        write_success "Architecture: Intel (x86_64)"
    fi

    # 3. System resources
    local ram_bytes
    ram_bytes=$(sysctl -n hw.memsize)
    local ram_gb
    ram_gb=$((ram_bytes / 1073741824))

    if [ "$ram_gb" -lt 8 ]; then
        write_warn "RAM: ${ram_gb} GB (8 GB recommended for Docker)"
    else
        write_success "RAM: ${ram_gb} GB"
    fi

    # 4. Disk space
    local free_space_gb
    free_space_gb=$(df -g / | awk 'NR==2 {print $4}')

    if [ "$free_space_gb" -lt 10 ]; then
        write_error "Free disk space: ${free_space_gb} GB (Minimum 10 GB required)"
        exit 1
    elif [ "$free_space_gb" -lt 25 ]; then
        write_warn "Free disk space: ${free_space_gb} GB (25 GB recommended)"
    else
        write_success "Free disk space: ${free_space_gb} GB"
    fi

    # 5. Internet
    write_info "Checking internet connectivity..."
    if ping -c 1 -W 5 github.com &>/dev/null; then
        write_success "Internet: Connected"
    elif curl -s --connect-timeout 10 https://www.google.com &>/dev/null; then
        write_success "Internet: Connected (HTTP)"
    else
        write_error "No internet connection!"
        exit 1
    fi

    # 6. Xcode Command Line Tools
    if xcode-select -p &>/dev/null; then
        write_success "Xcode CLI Tools: Installed"
    else
        write_info "Installing Xcode Command Line Tools..."
        xcode-select --install 2>/dev/null || true
        write_warn "Xcode CLI tools installing. Accept the dialog if shown."
        write_warn "Re-run this script after installation completes."
        read -r -p "   Press Enter to continue after accepting the dialog..."
    fi
}

# ============================================================
# SECTION 2: HOMEBREW INSTALLATION
# ============================================================
install_homebrew() {
    write_step "Homebrew Installation"

    if command -v brew &>/dev/null; then
        local brew_ver
        brew_ver=$(brew --version | head -1)
        write_success "Homebrew already installed: $brew_ver"
        write_info "Updating Homebrew..."
        brew update --quiet 2>/dev/null || true
        INSTALL_RESULTS["Homebrew"]="Already Installed"
        return 0
    fi

    write_info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for Apple Silicon
    local arch
    arch=$(uname -m)
    if [ "$arch" = "arm64" ]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi

    if command -v brew &>/dev/null; then
        write_success "Homebrew installed successfully"
        INSTALL_RESULTS["Homebrew"]="Installed"
    else
        write_error "Homebrew installation failed."
        write_error "Install from https://brew.sh"
        INSTALL_RESULTS["Homebrew"]="Failed"
        exit 1
    fi
}

# ============================================================
# SECTION 3: GIT INSTALLATION
# ============================================================
install_git() {
    write_step "Git Installation"

    if command -v git &>/dev/null; then
        local git_ver
        git_ver=$(git --version)
        write_success "Git already installed: $git_ver"
        INSTALL_RESULTS["Git"]="Already Installed ($git_ver)"
        return 0
    fi

    write_info "Installing Git via Homebrew..."
    brew install git --quiet

    if command -v git &>/dev/null; then
        local git_ver
        git_ver=$(git --version)
        write_success "Git installed: $git_ver"
        INSTALL_RESULTS["Git"]="Installed ($git_ver)"
    else
        write_error "Git installation failed."
        INSTALL_RESULTS["Git"]="Failed"
        return 1
    fi
}

# ============================================================
# SECTION 4: GIT GLOBAL CONFIGURATION
# ============================================================
configure_git() {
    write_step "Git Global Configuration"

    if ! command -v git &>/dev/null; then
        write_warn "Git not found. Skipping."
        return 1
    fi

    local existing_name
    existing_name=$(git config --global user.name 2>/dev/null || echo "")
    local existing_email
    existing_email=$(git config --global user.email 2>/dev/null || echo "")

    if [ -n "$existing_name" ] && [ -n "$existing_email" ]; then
        write_info "Existing Git config:"
        write_info "  Name:  $existing_name"
        write_info "  Email: $existing_email"
        echo ""
        read -r -p "   Keep existing configuration? (Y/N): " keep
        if [[ "$keep" =~ ^[Yy]$ ]]; then
            write_success "Git configuration kept"
            return 0
        fi
    fi

    echo ""
    echo -e "   ${CYAN}Configure Git with your identity:${NC}"
    echo ""
    read -r -p "   Enter your full name: " git_name
    read -r -p "   Enter your GitHub email: " git_email

    if [ -z "$git_name" ] || [ -z "$git_email" ]; then
        write_warn "Empty input. Skipping."
        return 1
    fi

    git config --global user.name "$git_name"
    git config --global user.email "$git_email"
    git config --global init.defaultBranch main
    git config --global credential.helper osxkeychain

    write_success "Git configured: $git_name <$git_email>"
    write_success "Default branch: main | Credential: macOS Keychain"
}

# ============================================================
# SECTION 5: NODE.JS LTS 22.x INSTALLATION
# ============================================================
install_nodejs() {
    write_step "Node.js LTS 22.x Installation"

    if command -v node &>/dev/null; then
        local node_ver
        node_ver=$(node --version)
        if [[ "$node_ver" =~ ^v22 ]]; then
            write_success "Node.js already installed: $node_ver"
            write_success "npm: v$(npm --version 2>/dev/null || echo 'unknown')"
            INSTALL_RESULTS["NodeJS"]="Already Installed ($node_ver)"
            return 0
        else
            write_warn "Node.js $node_ver found. Installing LTS 22.x..."
        fi
    fi

    write_info "Installing Node.js LTS 22.x via Homebrew..."
    brew install node@22 --quiet

    # Link node@22
    brew link --overwrite node@22 2>/dev/null || true

    if command -v node &>/dev/null; then
        local node_ver
        node_ver=$(node --version)
        write_success "Node.js installed: $node_ver"
        write_success "npm: v$(npm --version 2>/dev/null || echo 'unknown')"
        INSTALL_RESULTS["NodeJS"]="Installed ($node_ver)"
    else
        write_error "Node.js installation failed."
        INSTALL_RESULTS["NodeJS"]="Failed"
        return 1
    fi
}

# ============================================================
# SECTION 6: DOCKER DESKTOP INSTALLATION
# ============================================================
install_docker() {
    write_step "Docker Desktop Installation"

    if command -v docker &>/dev/null; then
        local docker_ver
        docker_ver=$(docker --version 2>/dev/null)
        write_success "Docker already installed: $docker_ver"
        INSTALL_RESULTS["Docker"]="Already Installed ($docker_ver)"
        return 0
    fi

    # Check if Docker Desktop app exists
    if [ -d "/Applications/Docker.app" ]; then
        write_success "Docker Desktop is installed (not running)"
        write_info "Open Docker Desktop from Applications."
        INSTALL_RESULTS["Docker"]="Installed (Not Running)"
        return 0
    fi

    write_info "Installing Docker Desktop via Homebrew..."
    write_info "This may take 5-10 minutes..."
    brew install --cask docker --quiet

    if [ -d "/Applications/Docker.app" ]; then
        write_success "Docker Desktop installed"
        INSTALL_RESULTS["Docker"]="Installed"

        echo -e ""
        echo -e "   ${CYAN}+-------------------------------------------------+${NC}"
        echo -e "   ${CYAN}|  DOCKER DESKTOP - IMPORTANT                      |${NC}"
        echo -e "   ${CYAN}+-------------------------------------------------+${NC}"
        echo -e "   ${CYAN}|  1. Open Docker Desktop from Applications        |${NC}"
        echo -e "   ${CYAN}|  2. Accept the license agreement                 |${NC}"
        echo -e "   ${CYAN}|  3. Grant required permissions                   |${NC}"
        echo -e "   ${CYAN}|  4. Wait for Docker to finish starting           |${NC}"
        echo -e "   ${CYAN}+-------------------------------------------------+${NC}"
        echo ""
    else
        write_error "Docker Desktop installation failed."
        write_error "Install from https://www.docker.com/products/docker-desktop/"
        INSTALL_RESULTS["Docker"]="Failed"
        return 1
    fi
}

# ============================================================
# SECTION 7: AWS CLI V2 INSTALLATION
# ============================================================
install_awscli() {
    write_step "AWS CLI v2 Installation"

    if command -v aws &>/dev/null; then
        local aws_ver
        aws_ver=$(aws --version 2>/dev/null)
        if [[ "$aws_ver" =~ aws-cli/2 ]]; then
            write_success "AWS CLI already installed: $aws_ver"
            INSTALL_RESULTS["AWSCLI"]="Already Installed"
            return 0
        fi
    fi

    write_info "Installing AWS CLI v2 via Homebrew..."
    brew install awscli --quiet

    if command -v aws &>/dev/null; then
        local aws_ver
        aws_ver=$(aws --version 2>/dev/null)
        write_success "AWS CLI installed: $aws_ver"
        INSTALL_RESULTS["AWSCLI"]="Installed"
    else
        write_error "AWS CLI v2 installation failed."
        INSTALL_RESULTS["AWSCLI"]="Failed"
        return 1
    fi

    write_info "Note: AWS credentials will be configured on Day 2/3."
}

# ============================================================
# SECTION 8: POST-INSTALLATION VALIDATION
# ============================================================
show_validation() {
    write_step "Post-Installation Validation"

    local passed=0
    local failed=0

    local tools=("brew:Homebrew" "git:Git" "node:Node.js" "npm:npm" "docker:Docker" "aws:AWS CLI")

    for tool_entry in "${tools[@]}"; do
        local cmd="${tool_entry%%:*}"
        local name="${tool_entry##*:}"

        if command -v "$cmd" &>/dev/null; then
            local ver
            ver=$("$cmd" --version 2>/dev/null | head -1)
            write_success "$name: $ver"
            passed=$((passed + 1))
        else
            write_error "$name: NOT FOUND"
            failed=$((failed + 1))
        fi
    done

    echo ""
    local total=$((passed + failed))
    if [ $failed -eq 0 ]; then
        echo -e "   ${GREEN}RESULT: ALL CHECKS PASSED ($passed/$total)${NC}"
    elif [ $failed -le 1 ]; then
        echo -e "   ${YELLOW}RESULT: MOSTLY READY ($passed/$total passed)${NC}"
    else
        echo -e "   ${RED}RESULT: NEEDS ATTENTION ($failed/$total failed)${NC}"
    fi
}

# ============================================================
# SECTION 9: FINAL SUMMARY
# ============================================================
show_summary() {
    echo ""
    echo -e "${CYAN}    ============================================================${NC}"
    echo -e "${CYAN}    INSTALLATION SUMMARY${NC}"
    echo -e "${CYAN}    ============================================================${NC}"
    echo ""

    for key in "${!INSTALL_RESULTS[@]}"; do
        local status="${INSTALL_RESULTS[$key]}"
        if [[ "$status" =~ Failed ]]; then
            echo -e "    ${RED}[X] $key : $status${NC}"
        elif [[ "$status" =~ Already ]]; then
            echo -e "    ${GREEN}[=] $key : $status${NC}"
        else
            echo -e "    ${GREEN}[+] $key : $status${NC}"
        fi
    done

    echo ""
    echo -e "    ${GRAY}Log file: $LOG_FILE${NC}"
    echo ""
    echo -e "${CYAN}    ============================================================${NC}"
    echo -e "${CYAN}    Setup Complete! See you at the WebxCloud Workshop!${NC}"
    echo -e "${CYAN}    ============================================================${NC}"
    echo ""
}

# ============================================================
# MAIN ENTRY POINT
# ============================================================
main() {
    local start_time
    start_time=$(date +%s)

    write_banner
    init_logging

    echo "[$(date +%H:%M:%S)] [START] Setup started" >> "$LOG_FILE"

    # Step 1: Pre-flight checks
    pre_flight_checks

    # Step 2: Homebrew
    install_homebrew

    # Step 3: Git
    install_git

    # Step 4: Git configuration
    configure_git

    # Step 5: Node.js
    install_nodejs

    # Step 6: Docker Desktop
    install_docker

    # Step 7: AWS CLI
    install_awscli

    # Step 8: Validation
    show_validation

    # Step 9: Summary
    local end_time
    end_time=$(date +%s)
    local duration=$(( (end_time - start_time) / 60 ))

    echo "[$(date +%H:%M:%S)] [END] Setup completed in ${duration} minutes" >> "$LOG_FILE"

    show_summary

    write_info "Total time: ${duration} minutes"
}

# Run
main "$@"
