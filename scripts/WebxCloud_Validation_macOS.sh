#!/usr/bin/env bash
# ============================================================
# GDGC WebxCloud Workshop - macOS Environment Validation Script
# ============================================================
# Lightweight verification script for Day 1+ of WebxCloud Workshop.
# Checks: Homebrew, Git, Node.js LTS 22.x, Docker Desktop, AWS CLI v2.
# NO installations performed - read-only verification.
#
# Author: GDGC Cloud Team (Pratham - Cloud Lead)
# Version: 1.0.0
# Date: February 2026
# Usage: bash WebxCloud_Validation_macOS.sh
# ============================================================

set -euo pipefail

# ============================================================
# GLOBAL CONFIGURATION
# ============================================================
SCRIPT_VERSION="1.0.0"
WORKSHOP_NAME="GDGC WebxCloud Workshop"
ALL_PASSED=true
declare -a VALIDATION_RESULTS

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
    echo "    ║   WebxCloud Workshop - Environment Validation v${SCRIPT_VERSION}           ║"
    echo "    ║   macOS Edition (Read-Only Check)                            ║"
    echo "    ║                                                              ║"
    echo "    ╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

write_check_item() {
    echo ""
    echo -e "${WHITE}>> Checking: ${CYAN}$1${NC}"
}

write_pass() {
    echo -e "   ${GREEN}[✓] $1${NC}"
}

write_fail() {
    echo -e "   ${RED}[✗] $1${NC}"
    ALL_PASSED=false
}

write_warn() {
    echo -e "   ${YELLOW}[!] $1${NC}"
}

# ============================================================
# VALIDATION FUNCTIONS
# ============================================================
test_homebrew() {
    write_check_item "Homebrew"
    
    if command -v brew &>/dev/null; then
        local brew_ver
        brew_ver=$(brew --version | head -1)
        write_pass "$brew_ver"
        VALIDATION_RESULTS+=("Homebrew|PASS|$brew_ver")
        return 0
    fi
    
    write_fail "Homebrew not found in PATH"
    write_warn "Homebrew is required for macOS package management"
    VALIDATION_RESULTS+=("Homebrew|FAIL|Not Installed")
    return 1
}

test_git() {
    write_check_item "Git"
    
    if command -v git &>/dev/null; then
        local git_ver
        git_ver=$(git --version)
        write_pass "$git_ver"
        
        # Check Git config
        local user_name
        user_name=$(git config --global user.name 2>/dev/null || echo "")
        local user_email
        user_email=$(git config --global user.email 2>/dev/null || echo "")
        
        if [ -n "$user_name" ] && [ -n "$user_email" ]; then
            write_pass "Git configured: $user_name <$user_email>"
        else
            write_warn "Git not configured with user.name/user.email"
        fi
        
        VALIDATION_RESULTS+=("Git|PASS|$git_ver")
        return 0
    fi
    
    write_fail "Git not found in PATH"
    VALIDATION_RESULTS+=("Git|FAIL|Not Installed")
    return 1
}

test_nodejs() {
    write_check_item "Node.js LTS 22.x"
    
    if command -v node &>/dev/null; then
        local node_ver
        node_ver=$(node --version)
        
        if [[ "$node_ver" =~ ^v22 ]]; then
            write_pass "Node.js $node_ver (LTS 22.x)"
            
            local npm_ver
            npm_ver=$(npm --version 2>/dev/null || echo "unknown")
            write_pass "npm v$npm_ver"
            
            VALIDATION_RESULTS+=("Node.js|PASS|$node_ver (npm: $npm_ver)")
            return 0
        else
            write_warn "Node.js $node_ver found (expected v22.x LTS)"
            VALIDATION_RESULTS+=("Node.js|WARNING|$node_ver (not v22.x)")
            return 0
        fi
    fi
    
    write_fail "Node.js not found in PATH"
    VALIDATION_RESULTS+=("Node.js|FAIL|Not Installed")
    return 1
}

test_docker() {
    write_check_item "Docker Desktop"
    
    if command -v docker &>/dev/null; then
        local docker_ver
        docker_ver=$(docker --version 2>/dev/null)
        write_pass "$docker_ver"
        
        # Check if Docker daemon is running
        if docker ps &>/dev/null; then
            write_pass "Docker daemon is running"
        else
            write_warn "Docker is installed but daemon not running"
            write_warn "Open Docker Desktop from Applications"
        fi
        
        VALIDATION_RESULTS+=("Docker|PASS|$docker_ver")
        return 0
    fi
    
    # Check if Docker Desktop app exists
    if [ -d "/Applications/Docker.app" ]; then
        write_warn "Docker Desktop installed but not in PATH (not running?)"
        write_warn "Open Docker Desktop from Applications"
        VALIDATION_RESULTS+=("Docker|WARNING|Installed (Not Running)")
        return 0
    fi
    
    write_fail "Docker Desktop not found"
    VALIDATION_RESULTS+=("Docker|FAIL|Not Installed")
    return 1
}

test_awscli() {
    write_check_item "AWS CLI v2"
    
    if command -v aws &>/dev/null; then
        local aws_ver
        aws_ver=$(aws --version 2>/dev/null)
        
        if [[ "$aws_ver" =~ aws-cli/2 ]]; then
            write_pass "$aws_ver"
            VALIDATION_RESULTS+=("AWS CLI|PASS|$aws_ver")
            return 0
        else
            write_warn "AWS CLI v1 found (expected v2): $aws_ver"
            VALIDATION_RESULTS+=("AWS CLI|WARNING|$aws_ver (not v2)")
            return 0
        fi
    fi
    
    write_fail "AWS CLI v2 not found in PATH"
    VALIDATION_RESULTS+=("AWS CLI|FAIL|Not Installed")
    return 1
}

# ============================================================
# SUMMARY REPORT
# ============================================================
show_summary() {
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo -e "${CYAN}VALIDATION SUMMARY${NC}"
    echo -e "${CYAN}============================================================${NC}"
    echo ""
    
    local passed=0
    local warnings=0
    local failed=0
    
    for result in "${VALIDATION_RESULTS[@]}"; do
        IFS='|' read -r tool status version <<< "$result"
        
        case "$status" in
            PASS)
                echo -e "  ${GREEN}[✓]${NC} ${WHITE}$tool:${NC} ${GRAY}$version${NC}"
                passed=$((passed + 1))
                ;;
            WARNING)
                echo -e "  ${YELLOW}[!]${NC} ${WHITE}$tool:${NC} ${GRAY}$version${NC}"
                warnings=$((warnings + 1))
                ;;
            FAIL)
                echo -e "  ${RED}[✗]${NC} ${WHITE}$tool:${NC} ${GRAY}$version${NC}"
                failed=$((failed + 1))
                ;;
        esac
    done
    
    echo ""
    
    local total=$((passed + warnings + failed))
    
    if [ $failed -eq 0 ] && [ $warnings -eq 0 ]; then
        echo -e "  ${GREEN}RESULT: ALL CHECKS PASSED ($passed/$total)${NC}"
        echo -e "  ${GREEN}Your environment is ready for the WebxCloud Workshop!${NC}"
    elif [ $failed -eq 0 ]; then
        echo -e "  ${YELLOW}RESULT: MOSTLY READY ($passed/$total passed, $warnings warnings)${NC}"
        echo -e "  ${YELLOW}Review warnings above. You may proceed with the workshop.${NC}"
    else
        echo -e "  ${RED}RESULT: NEEDS ATTENTION ($failed/$total failed)${NC}"
        echo -e "  ${RED}Run WebxCloud_Setup_macOS.sh to install missing tools.${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    echo ""
}

# ============================================================
# MAIN ENTRY POINT
# ============================================================
main() {
    write_banner
    
    echo -e "${GRAY}Running environment checks (read-only)...${NC}"
    echo -e "${GRAY}This will NOT install or modify anything.${NC}"
    
    # Run all checks
    test_homebrew
    test_git
    test_nodejs
    test_docker
    test_awscli
    
    # Show summary
    show_summary
    
    # Exit code
    if $ALL_PASSED; then
        exit 0
    else
        exit 1
    fi
}

# Run validation
main "$@"
