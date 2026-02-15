#!/usr/bin/env bash
# ============================================================
# GDGC WebxCloud Workshop - Linux Environment Setup Script
# ============================================================
# Automated setup for Day 1 of the WebxCloud 3-Day Sprint.
# Installs: Git, Node.js LTS 22.x, Docker Engine (CE), AWS CLI v2.
# Supports: Ubuntu, Debian, Fedora, CentOS, RHEL
#
# Author: GDGC Cloud Team (Pratham - Cloud Lead)
# Version: 1.0.0
# Date: February 2026
# Usage: sudo bash WebxCloud_Setup.sh
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
RESTART_REQUIRED=false
declare -A INSTALL_RESULTS

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

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
    echo "    ║   Linux Edition                                              ║"
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
$WORKSHOP_NAME - Environment Setup Log
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
        echo "[$(date +%H:%M:%S)] [RETRY] $operation attempt $attempt failed" >> "$LOG_FILE"
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
# DISTRO DETECTION
# ============================================================
PKG_MANAGER=""
DISTRO_NAME=""
DISTRO_ID=""

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_NAME="${NAME:-Unknown}"
        DISTRO_ID="${ID:-unknown}"
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO_NAME="${DISTRIB_DESCRIPTION:-Unknown}"
        DISTRO_ID="${DISTRIB_ID,,}"
    else
        DISTRO_NAME="Unknown"
        DISTRO_ID="unknown"
    fi

    # Detect package manager
    if command -v apt-get &>/dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf &>/dev/null; then
        PKG_MANAGER="dnf"
    elif command -v yum &>/dev/null; then
        PKG_MANAGER="yum"
    else
        write_error "No supported package manager found (apt/dnf/yum)."
        exit 1
    fi

    write_success "Distro: $DISTRO_NAME ($DISTRO_ID)"
    write_success "Package Manager: $PKG_MANAGER"
}

# ============================================================
# SECTION 1: PRE-FLIGHT CHECKS
# ============================================================
pre_flight_checks() {
    write_step "Pre-Flight Checks"

    # 1. Root/sudo check
    if [ "$EUID" -ne 0 ]; then
        write_error "This script must be run with sudo!"
        write_error "Usage: sudo bash WebxCloud_Setup.sh"
        exit 1
    fi
    write_success "Running with root privileges"

    # 2. Detect distro
    detect_distro

    # 3. System resources
    local ram_mb
    ram_mb=$(free -m | awk '/Mem:/ {print $2}')
    local ram_gb
    ram_gb=$(echo "scale=1; $ram_mb / 1024" | bc)

    if [ "$ram_mb" -lt 4096 ]; then
        write_warn "RAM: ${ram_gb} GB (4 GB minimum recommended)"
    else
        write_success "RAM: ${ram_gb} GB"
    fi

    local cpu_name
    cpu_name=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
    local cpu_cores
    cpu_cores=$(nproc)
    write_success "CPU: ${cpu_name} (${cpu_cores} cores)"

    # 4. Disk space
    local free_space_gb
    free_space_gb=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')

    if [ "$free_space_gb" -lt 10 ]; then
        write_error "Free disk space: ${free_space_gb} GB (Minimum 10 GB required)"
        exit 1
    elif [ "$free_space_gb" -lt 25 ]; then
        write_warn "Free disk space: ${free_space_gb} GB (25 GB recommended)"
    else
        write_success "Free disk space: ${free_space_gb} GB"
    fi

    # 5. Internet connectivity
    write_info "Checking internet connectivity..."
    if ping -c 1 -W 5 github.com &>/dev/null; then
        write_success "Internet: Connected (github.com reachable)"
    elif curl -s --connect-timeout 10 https://www.google.com &>/dev/null; then
        write_success "Internet: Connected (HTTP check passed)"
    else
        write_error "No internet connection detected!"
        exit 1
    fi

    # 6. Architecture
    local arch
    arch=$(uname -m)
    write_success "Architecture: $arch"

    return 0
}

# ============================================================
# SECTION 2: GIT INSTALLATION
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

    write_info "Installing Git..."
    case "$PKG_MANAGER" in
        apt)
            DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>/dev/null || true
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git
            ;;
        dnf)
            dnf install -y -q git
            ;;
        yum)
            yum install -y -q git
            ;;
    esac

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
# SECTION 3: GIT GLOBAL CONFIGURATION
# ============================================================
configure_git() {
    write_step "Git Global Configuration"

    if ! command -v git &>/dev/null; then
        write_warn "Git not found. Skipping configuration."
        return 1
    fi

    # Run as the original user (not root)
    local real_user="${SUDO_USER:-$(whoami)}"
    local existing_name
    existing_name=$(sudo -u "$real_user" git config --global user.name 2>/dev/null || echo "")
    local existing_email
    existing_email=$(sudo -u "$real_user" git config --global user.email 2>/dev/null || echo "")

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
        write_warn "Empty input. Skipping Git configuration."
        return 1
    fi

    sudo -u "$real_user" git config --global user.name "$git_name"
    sudo -u "$real_user" git config --global user.email "$git_email"
    sudo -u "$real_user" git config --global init.defaultBranch main

    write_success "Git configured: $git_name <$git_email>"
    write_success "Default branch: main"
}

# ============================================================
# SECTION 4: NODE.JS LTS 22.x INSTALLATION
# ============================================================
install_nodejs() {
    write_step "Node.js LTS 22.x Installation"

    if command -v node &>/dev/null; then
        local node_ver
        node_ver=$(node --version)
        if [[ "$node_ver" =~ ^v22 ]]; then
            write_success "Node.js already installed: $node_ver (LTS 22.x)"
            local npm_ver
            npm_ver=$(npm --version 2>/dev/null || echo "unknown")
            write_success "npm: v$npm_ver"
            INSTALL_RESULTS["NodeJS"]="Already Installed ($node_ver)"
            return 0
        else
            write_warn "Node.js $node_ver found. Installing LTS 22.x..."
        fi
    fi

    write_info "Installing Node.js LTS 22.x via NodeSource..."

    case "$PKG_MANAGER" in
        apt)
            # Install prerequisites
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ca-certificates curl gnupg 2>&1 | grep -v "cnf-update-db" || true
            # Add NodeSource repository
            mkdir -p /etc/apt/keyrings
            curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg 2>/dev/null
            echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list
            DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>/dev/null || true
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nodejs
            ;;
        dnf)
            curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
            dnf install -y -q nodejs
            ;;
        yum)
            curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -
            yum install -y -q nodejs
            ;;
    esac

    if command -v node &>/dev/null; then
        local node_ver
        node_ver=$(node --version)
        local npm_ver
        npm_ver=$(npm --version 2>/dev/null || echo "unknown")
        write_success "Node.js installed: $node_ver"
        write_success "npm: v$npm_ver"
        INSTALL_RESULTS["NodeJS"]="Installed ($node_ver)"
    else
        write_error "Node.js installation failed. Install from https://nodejs.org"
        INSTALL_RESULTS["NodeJS"]="Failed"
        return 1
    fi
}

# ============================================================
# SECTION 5: DOCKER ENGINE (CE) INSTALLATION
# ============================================================
install_docker() {
    write_step "Docker Engine Installation"

    if command -v docker &>/dev/null; then
        local docker_ver
        docker_ver=$(docker --version)
        write_success "Docker already installed: $docker_ver"
        INSTALL_RESULTS["Docker"]="Already Installed ($docker_ver)"
        return 0
    fi

    write_info "Installing Docker Engine (CE)..."

    case "$PKG_MANAGER" in
        apt)
            # Remove old versions
            apt-get remove -y -qq docker docker-engine docker.io containerd runc 2>/dev/null || true

            # Install prerequisites
            DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>/dev/null || true
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ca-certificates curl gnupg lsb-release 2>&1 | grep -v "cnf-update-db" || true

            # Add Docker GPG key
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL "https://download.docker.com/linux/${DISTRO_ID}/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
            chmod a+r /etc/apt/keyrings/docker.gpg

            # Add Docker repository
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRO_ID} $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list

            # Install Docker Engine
            DEBIAN_FRONTEND=noninteractive apt-get update -qq 2>/dev/null || true
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        dnf)
            dnf remove -y -q docker docker-client docker-client-latest docker-common docker-latest 2>/dev/null || true
            dnf install -y -q dnf-plugins-core
            dnf config-manager --add-repo "https://download.docker.com/linux/${DISTRO_ID}/docker-ce.repo"
            dnf install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
        yum)
            yum remove -y -q docker docker-client docker-client-latest docker-common docker-latest 2>/dev/null || true
            yum install -y -q yum-utils
            yum-config-manager --add-repo "https://download.docker.com/linux/${DISTRO_ID}/docker-ce.repo"
            yum install -y -q docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
            ;;
    esac

    # Start and enable Docker
    systemctl start docker 2>/dev/null || true
    systemctl enable docker 2>/dev/null || true

    # Add current user to docker group
    local real_user="${SUDO_USER:-$(whoami)}"
    if [ "$real_user" != "root" ]; then
        usermod -aG docker "$real_user"
        write_info "User '$real_user' added to docker group"
        write_warn "Log out and back in for docker group to take effect"
    fi

    if command -v docker &>/dev/null; then
        local docker_ver
        docker_ver=$(docker --version)
        write_success "Docker installed: $docker_ver"
        INSTALL_RESULTS["Docker"]="Installed ($docker_ver)"
    else
        write_error "Docker installation failed."
        write_error "Install from https://docs.docker.com/engine/install/"
        INSTALL_RESULTS["Docker"]="Failed"
        return 1
    fi
}

# ============================================================
# SECTION 6: AWS CLI V2 INSTALLATION
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
        else
            write_warn "AWS CLI v1 detected. Upgrading to v2..."
        fi
    fi

    write_info "Installing AWS CLI v2..."

    local arch
    arch=$(uname -m)
    local aws_url

    case "$arch" in
        x86_64)
            aws_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip"
            ;;
        aarch64)
            aws_url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip"
            ;;
        *)
            write_error "Unsupported architecture: $arch"
            INSTALL_RESULTS["AWSCLI"]="Failed (Unsupported arch)"
            return 1
            ;;
    esac

    # Install prerequisites
    case "$PKG_MANAGER" in
        apt) DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unzip curl ;;
        dnf) dnf install -y -q unzip curl ;;
        yum) yum install -y -q unzip curl ;;
    esac

    local tmp_dir
    tmp_dir=$(mktemp -d)
    cd "$tmp_dir"

    if invoke_with_retry "AWS CLI Download" curl -fsSL "$aws_url" -o "awscliv2.zip"; then
        unzip -q awscliv2.zip
        if [ -f /usr/local/bin/aws ]; then
            ./aws/install --update
        else
            ./aws/install
        fi
        write_success "AWS CLI v2 installed"
        INSTALL_RESULTS["AWSCLI"]="Installed"
    else
        write_error "AWS CLI v2 installation failed."
        INSTALL_RESULTS["AWSCLI"]="Failed"
        cd /
        rm -rf "$tmp_dir"
        return 1
    fi

    cd /
    rm -rf "$tmp_dir"

    if command -v aws &>/dev/null; then
        local aws_ver
        aws_ver=$(aws --version 2>/dev/null)
        write_success "AWS CLI verified: $aws_ver"
    fi

    write_info "Note: AWS credentials will be configured on Day 2/3."
}

# ============================================================
# SECTION 7: POST-INSTALLATION VALIDATION
# ============================================================
show_validation() {
    write_step "Post-Installation Validation"

    local passed=0
    local failed=0

    # Git
    if command -v git &>/dev/null; then
        write_success "Git: $(git --version)"
        passed=$((passed + 1))
    else
        write_error "Git: NOT FOUND"
        failed=$((failed + 1))
    fi

    # Node.js
    if command -v node &>/dev/null; then
        local nv
        nv=$(node --version)
        if [[ "$nv" =~ ^v22 ]]; then
            write_success "Node.js: $nv (LTS 22.x)"
        else
            write_warn "Node.js: $nv (expected v22.x)"
        fi
        passed=$((passed + 1))
    else
        write_error "Node.js: NOT FOUND"
        failed=$((failed + 1))
    fi

    # npm
    if command -v npm &>/dev/null; then
        write_success "npm: v$(npm --version)"
        passed=$((passed + 1))
    else
        write_error "npm: NOT FOUND"
        failed=$((failed + 1))
    fi

    # Docker
    if command -v docker &>/dev/null; then
        write_success "Docker: $(docker --version)"
        passed=$((passed + 1))
    else
        write_error "Docker: NOT FOUND"
        failed=$((failed + 1))
    fi

    # AWS CLI
    if command -v aws &>/dev/null; then
        write_success "AWS CLI: $(aws --version 2>/dev/null)"
        passed=$((passed + 1))
    else
        write_error "AWS CLI: NOT FOUND"
        failed=$((failed + 1))
    fi

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
# SECTION 8: FINAL SUMMARY
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

    # Step 2: Git
    install_git

    # Step 3: Git configuration
    configure_git

    # Step 4: Node.js
    install_nodejs

    # Step 5: Docker Engine
    install_docker

    # Step 6: AWS CLI
    install_awscli

    # Step 7: Validation
    show_validation

    # Step 8: Summary
    local end_time
    end_time=$(date +%s)
    local duration=$(( (end_time - start_time) / 60 ))

    echo "[$(date +%H:%M:%S)] [END] Setup completed in ${duration} minutes" >> "$LOG_FILE"

    show_summary

    write_info "Total time: ${duration} minutes"
}

# Run
main "$@"
