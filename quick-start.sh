#!/bin/bash

# Quick Start Script for Intel TDX Attestation on GCP
# This script provides a guided setup and execution of TDX attestation

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    echo -e "[${level}] ${message}"
}

log_info() {
    log "INFO" "${BLUE}$*${NC}"
}

log_success() {
    log "SUCCESS" "${GREEN}$*${NC}"
}

log_warning() {
    log "WARNING" "${YELLOW}$*${NC}"
}

log_error() {
    log "ERROR" "${RED}$*${NC}"
}

log_step() {
    log "STEP" "${CYAN}$*${NC}"
}

# Display banner
display_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              Intel TDX Attestation Quick Start              ║"
    echo "║                    GCP Confidential VMs                     ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
}

# Check if running on GCP
check_gcp_environment() {
    log_step "Checking GCP environment..."
    
    if curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone > /dev/null 2>&1; then
        local zone=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | cut -d'/' -f4)
        log_success "Running on GCP in zone: ${zone}"
        return 0
    else
        log_warning "Not running on GCP or metadata service not accessible"
        return 1
    fi
}

# Check TDX availability
check_tdx_availability() {
    log_step "Checking TDX availability..."
    
    if dmesg | grep -i tdx > /dev/null 2>&1; then
        local tdx_info=$(dmesg | grep -i tdx | head -1)
        log_success "TDX is available: ${tdx_info}"
        return 0
    else
        log_error "TDX is not available on this system"
        log_info "Please ensure you're running on a GCP confidential VM with TDX support"
        return 1
    fi
}

# Setup configuration
setup_configuration() {
    log_step "Setting up configuration..."
    
    if [[ ! -f "config.json" ]]; then
        log_info "Creating configuration file..."
        cp config.json.template config.json
        
        log_warning "Please edit config.json and add your Intel Trust Authority API key"
        log_info "You can get an API key from: https://trustauthority.intel.com"
        
        # Try to open the file for editing
        if command -v nano &> /dev/null; then
            log_info "Opening config.json for editing..."
            nano config.json
        elif command -v vim &> /dev/null; then
            log_info "Opening config.json for editing..."
            vim config.json
        else
            log_info "Please edit config.json manually and add your API key"
        fi
        
        # Check if API key was added
        if grep -q "YOUR_API_KEY_HERE" config.json; then
            log_error "Please update the API key in config.json before continuing"
            return 1
        fi
    else
        log_success "Configuration file already exists"
    fi
    
    return 0
}

# Run attestation
run_attestation() {
    log_step "Running TDX attestation..."
    
    if [[ $EUID -ne 0 ]]; then
        log_info "Running attestation with sudo..."
        sudo ./tdx-attestation.sh
    else
        log_info "Running attestation..."
        ./tdx-attestation.sh
    fi
}

# Run verification
run_verification() {
    log_step "Running verification..."
    
    ./tdx-verifier.sh --all
}

# Run test suite
run_test_suite() {
    log_step "Running comprehensive test suite..."
    
    if [[ $EUID -ne 0 ]]; then
        log_info "Running test suite with sudo..."
        sudo ./run-all-tests.sh
    else
        log_info "Running test suite..."
        ./run-all-tests.sh
    fi
}

# Display results
display_results() {
    log_step "Displaying results..."
    
    echo
    log_info "=== Generated Files ==="
    
    local files=(
        "tdx-evidence.json:TDX Evidence"
        "tdx-token.json:Attestation Token"
        "tdx-attestation-report.json:Attestation Report"
        "tdx-verification-report.json:Verification Report"
        "tdx-test-suite-report.json:Test Suite Report"
    )
    
    for file_info in "${files[@]}"; do
        local file=$(echo "${file_info}" | cut -d':' -f1)
        local description=$(echo "${file_info}" | cut -d':' -f2)
        
        if [[ -f "${file}" ]]; then
            log_success "✓ ${file} - ${description}"
        else
            log_warning "✗ ${file} - ${description} (not found)"
        fi
    done
    
    echo
    log_info "=== Next Steps ==="
    echo "1. Review the attestation report: tdx-attestation-report.json"
    echo "2. Use the token for your application's attestation verification"
    echo "3. Store the evidence for audit purposes"
    echo "4. Check the test suite report for detailed test results"
}

# Interactive menu
show_menu() {
    echo
    log_info "What would you like to do?"
    echo "1) Run complete attestation process"
    echo "2) Run verification only"
    echo "3) Run test suite only"
    echo "4) Setup configuration only"
    echo "5) Check system status"
    echo "6) Exit"
    echo
    read -p "Enter your choice (1-6): " choice
    
    case $choice in
        1)
            run_attestation
            run_verification
            display_results
            ;;
        2)
            run_verification
            ;;
        3)
            run_test_suite
            ;;
        4)
            setup_configuration
            ;;
        5)
            check_gcp_environment
            check_tdx_availability
            ;;
        6)
            log_info "Goodbye!"
            exit 0
            ;;
        *)
            log_error "Invalid choice. Please try again."
            show_menu
            ;;
    esac
}

# Main execution
main() {
    display_banner
    
    log_info "Welcome to Intel TDX Attestation Quick Start!"
    echo
    
    # Check prerequisites
    if ! check_gcp_environment; then
        log_warning "This script is designed for GCP confidential VMs"
        log_info "You can still run it, but some features may not work"
    fi
    
    if ! check_tdx_availability; then
        log_error "TDX is required for attestation"
        log_info "Please ensure you're running on a TDX-capable GCP confidential VM"
        exit 1
    fi
    
    # Check if configuration exists
    if [[ ! -f "config.json" ]]; then
        log_info "Configuration file not found. Setting up..."
        if ! setup_configuration; then
            log_error "Configuration setup failed"
            exit 1
        fi
    fi
    
    # Show interactive menu
    show_menu
}

# Handle script interruption
trap 'log_error "Script interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"
