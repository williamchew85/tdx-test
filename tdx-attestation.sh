#!/bin/bash

# Intel TDX Attestation Script for GCP Confidential VMs
# This script performs step-by-step TDX attestation and reporting

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_DIR="${SCRIPT_DIR}/json"
LOG_DIR="${SCRIPT_DIR}/log"

# Create directories if they don't exist
mkdir -p "${JSON_DIR}" "${LOG_DIR}"

LOG_FILE="${LOG_DIR}/tdx-attestation.log"
CONFIG_FILE="${SCRIPT_DIR}/config.json"
REPORT_FILE="${JSON_DIR}/tdx-attestation-report.json"
EVIDENCE_FILE="${JSON_DIR}/tdx-evidence.json"
TOKEN_FILE="${JSON_DIR}/tdx-token.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
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

# Check if running as root for TDX operations
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root for TDX operations"
        log_info "Please run: sudo $0"
        exit 1
    fi
}

# Check if TDX is available on the system
check_tdx_availability() {
    log_info "Checking TDX availability..."
    
    if ! dmesg | grep -i tdx > /dev/null 2>&1; then
        log_error "TDX is not available on this system"
        log_info "Please ensure you're running on a GCP confidential VM with TDX enabled"
        log_info "Expected machine type: c3-standard-4 or similar with TDX support"
        exit 1
    fi
    
    local tdx_info=$(dmesg | grep -i tdx)
    log_success "TDX is available: ${tdx_info}"
}

# Check if Go is installed
check_go_installation() {
    log_info "Checking Go installation..."
    
    if ! command -v go &> /dev/null; then
        log_warning "Go is not installed. Installing Go 1.23.1..."
        install_go
    else
        local go_version=$(go version | cut -d' ' -f3)
        log_success "Go is installed: ${go_version}"
        
        # Check if version is 1.22 or later
        local major_version=$(echo "${go_version}" | cut -d'.' -f2)
        if [[ ${major_version} -lt 22 ]]; then
            log_warning "Go version ${go_version} is too old. Installing Go 1.23.1..."
            install_go
        fi
    fi
}

# Install Go
install_go() {
    log_info "Installing Go 1.23.1..."
    
    cd /tmp
    wget -q https://go.dev/dl/go1.23.1.linux-amd64.tar.gz
    tar -xf go1.23.1.linux-amd64.tar.gz
    sudo mv go /usr/local/
    
    # Add Go to PATH
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    export PATH=$PATH:/usr/local/go/bin
    
    # Verify installation
    if go version | grep -q "go1.23.1"; then
        log_success "Go 1.23.1 installed successfully"
    else
        log_error "Failed to install Go"
        exit 1
    fi
}

# Check if Intel Trust Authority CLI is installed
check_trustauthority_cli() {
    log_info "Checking Intel Trust Authority CLI installation..."
    
    if ! command -v trustauthority-cli &> /dev/null; then
        log_warning "Intel Trust Authority CLI is not installed. Installing..."
        install_trustauthority_cli
    else
        local cli_version=$(trustauthority-cli version 2>/dev/null || echo "unknown")
        log_success "Intel Trust Authority CLI is installed: ${cli_version}"
    fi
}

# Install Intel Trust Authority CLI
install_trustauthority_cli() {
    log_info "Installing Intel Trust Authority CLI..."
    
    curl -sL https://raw.githubusercontent.com/intel/trustauthority-client-for-go/main/release/install-tdx-cli.sh | sudo bash -
    
    if command -v trustauthority-cli &> /dev/null; then
        log_success "Intel Trust Authority CLI installed successfully"
    else
        log_error "Failed to install Intel Trust Authority CLI"
        exit 1
    fi
}

# Create configuration file
create_config() {
    log_info "Creating configuration file..."
    
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log_warning "Configuration file not found. Creating template..."
        cat > "${CONFIG_FILE}" << EOF
{
    "trustauthority_api_url": "https://api.trustauthority.intel.com",
    "trustauthority_api_key": "YOUR_API_KEY_HERE"
}
EOF
        log_warning "Please edit ${CONFIG_FILE} and add your Intel Trust Authority API key"
        log_info "You can get an API key from: https://trustauthority.intel.com"
        exit 1
    fi
    
    # Validate configuration
    if ! jq -e '.trustauthority_api_key' "${CONFIG_FILE}" > /dev/null 2>&1; then
        log_error "Invalid configuration file. Missing trustauthority_api_key"
        exit 1
    fi
    
    local api_key=$(jq -r '.trustauthority_api_key' "${CONFIG_FILE}")
    if [[ "${api_key}" == "YOUR_API_KEY_HERE" ]]; then
        log_error "Please update the API key in ${CONFIG_FILE}"
        exit 1
    fi
    
    log_success "Configuration file is valid"
}

# Generate TDX evidence
generate_evidence() {
    log_info "Generating TDX evidence..."
    
    if trustauthority-cli evidence --tdx -c "${CONFIG_FILE}" > "${EVIDENCE_FILE}" 2>&1; then
        log_success "TDX evidence generated successfully"
        log_info "Evidence saved to: ${EVIDENCE_FILE}"
        
        # Display evidence summary
        if command -v jq &> /dev/null; then
            log_info "Evidence summary:"
            jq -r '.evidence | keys[]' "${EVIDENCE_FILE}" 2>/dev/null || log_info "Raw evidence content available"
        fi
    else
        log_error "Failed to generate TDX evidence"
        log_info "Check the log file for details: ${LOG_FILE}"
        exit 1
    fi
}

# Generate attestation token
generate_token() {
    log_info "Generating attestation token..."
    
    if trustauthority-cli token -c "${CONFIG_FILE}" > "${TOKEN_FILE}" 2>&1; then
        log_success "Attestation token generated successfully"
        log_info "Token saved to: ${TOKEN_FILE}"
        
        # Display token summary
        if command -v jq &> /dev/null; then
            log_info "Token summary:"
            jq -r '.token' "${TOKEN_FILE}" 2>/dev/null | head -c 100 || log_info "Raw token content available"
            echo "..."
        fi
    else
        log_error "Failed to generate attestation token"
        log_info "Check the log file for details: ${LOG_FILE}"
        exit 1
    fi
}

# Generate comprehensive report
generate_report() {
    log_info "Generating comprehensive attestation report..."
    
    local report_data=$(cat << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "system_info": {
        "hostname": "$(hostname)",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)",
        "tdx_status": "$(dmesg | grep -i tdx | head -1 || echo 'Not available')"
    },
    "software_versions": {
        "go_version": "$(go version 2>/dev/null || echo 'Not installed')",
        "trustauthority_cli_version": "$(trustauthority-cli version 2>/dev/null || echo 'Not installed')"
    },
    "attestation_results": {
        "evidence_generated": $(test -f "${EVIDENCE_FILE}" && echo "true" || echo "false"),
        "token_generated": $(test -f "${TOKEN_FILE}" && echo "true" || echo "false"),
        "evidence_file": "${EVIDENCE_FILE}",
        "token_file": "${TOKEN_FILE}"
    },
    "configuration": {
        "config_file": "${CONFIG_FILE}",
        "api_url": "$(jq -r '.trustauthority_api_url' "${CONFIG_FILE}" 2>/dev/null || echo 'Not configured')"
    }
}
EOF
)
    
    echo "${report_data}" | jq '.' > "${REPORT_FILE}" 2>/dev/null || echo "${report_data}" > "${REPORT_FILE}"
    log_success "Comprehensive report generated: ${REPORT_FILE}"
}

# Display summary
display_summary() {
    log_info "=== TDX Attestation Summary ==="
    echo
    log_success "✓ TDX availability verified"
    log_success "✓ Go installation verified"
    log_success "✓ Intel Trust Authority CLI verified"
    log_success "✓ Configuration validated"
    log_success "✓ TDX evidence generated"
    log_success "✓ Attestation token generated"
    log_success "✓ Comprehensive report created"
    echo
    log_info "Files created:"
    echo "  - Evidence: ${EVIDENCE_FILE}"
    echo "  - Token: ${TOKEN_FILE}"
    echo "  - Report: ${REPORT_FILE}"
    echo "  - Log: ${LOG_FILE}"
    echo
    log_info "Output directories:"
    echo "  - JSON files: ${JSON_DIR}"
    echo "  - Log files: ${LOG_DIR}"
    echo
    log_info "Next steps:"
    echo "  1. Review the attestation report: ${REPORT_FILE}"
    echo "  2. Use the token for your application's attestation verification"
    echo "  3. Store the evidence for audit purposes"
}

# Main execution
main() {
    log_info "Starting Intel TDX Attestation Process"
    log_info "Script directory: ${SCRIPT_DIR}"
    
    # Initialize log file
    echo "=== Intel TDX Attestation Log ===" > "${LOG_FILE}"
    echo "Started at: $(date)" >> "${LOG_FILE}"
    echo >> "${LOG_FILE}"
    
    # Check prerequisites
    check_root
    check_tdx_availability
    check_go_installation
    check_trustauthority_cli
    create_config
    
    # Perform attestation
    generate_evidence
    generate_token
    generate_report
    
    # Display summary
    display_summary
    
    log_success "TDX attestation process completed successfully!"
}

# Handle script interruption
trap 'log_error "Script interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"
