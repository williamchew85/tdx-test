#!/bin/bash

# TDX Quote Generator Script
# This script generates TDX quotes for local verification and testing

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_DIR="${SCRIPT_DIR}/json"
LOG_DIR="${SCRIPT_DIR}/log"

# Create directories if they don't exist
mkdir -p "${JSON_DIR}" "${LOG_DIR}"

QUOTE_FILE="${JSON_DIR}/tdx-quote.bin"
QUOTE_INFO_FILE="${JSON_DIR}/tdx-quote-info.json"
LOG_FILE="${LOG_DIR}/tdx-quote-generator.log"

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

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root for TDX operations"
        log_info "Please run: sudo $0"
        exit 1
    fi
}

# Check TDX availability
check_tdx_availability() {
    log_info "Checking TDX availability..."
    
    if ! dmesg | grep -i tdx > /dev/null 2>&1; then
        log_error "TDX is not available on this system"
        exit 1
    fi
    
    local tdx_info=$(dmesg | grep -i tdx | head -1)
    log_success "TDX is available: ${tdx_info}"
}

# Check if TDX tools are available
check_tdx_tools() {
    log_info "Checking TDX tools availability..."
    
    # Check for TDX device
    if [[ ! -e /dev/tdx_guest ]]; then
        log_warning "TDX guest device not found at /dev/tdx_guest"
        log_info "This is normal for some TDX implementations"
    else
        log_success "TDX guest device found"
    fi
    
    # Check for TDX-related kernel modules
    if lsmod | grep -i tdx > /dev/null 2>&1; then
        log_success "TDX kernel modules loaded"
        lsmod | grep -i tdx | while read line; do
            log_info "  - ${line}"
        done
    else
        log_warning "No TDX kernel modules found"
    fi
}

# Generate TDX quote using Intel Trust Authority CLI
generate_quote_with_cli() {
    log_info "Generating TDX quote using Intel Trust Authority CLI..."
    
    if ! command -v trustauthority-cli &> /dev/null; then
        log_error "Intel Trust Authority CLI not found"
        log_info "Please run the main attestation script first to install dependencies"
        exit 1
    fi
    
    # Create a minimal config for quote generation
    local temp_config="${SCRIPT_DIR}/temp-config.json"
    cat > "${temp_config}" << EOF
{
    "trustauthority_api_url": "https://api.trustauthority.intel.com",
    "trustauthority_api_key": "dummy_key_for_quote_generation"
}
EOF
    
    # Generate evidence (which includes quote information)
    if trustauthority-cli evidence --tdx -c "${temp_config}" > "${QUOTE_INFO_FILE}" 2>&1; then
        log_success "TDX quote information generated"
        
        # Extract quote data if available
        if command -v jq &> /dev/null; then
            local quote_data=$(jq -r '.evidence.quote // empty' "${QUOTE_INFO_FILE}" 2>/dev/null)
            if [[ -n "${quote_data}" && "${quote_data}" != "null" ]]; then
                echo "${quote_data}" | base64 -d > "${QUOTE_FILE}" 2>/dev/null || {
                    log_warning "Could not decode quote data, saving as text"
                    echo "${quote_data}" > "${QUOTE_FILE}.txt"
                }
                log_success "TDX quote saved to: ${QUOTE_FILE}"
            else
                log_info "Quote data not found in evidence, but evidence file created: ${QUOTE_INFO_FILE}"
            fi
        fi
    else
        log_error "Failed to generate TDX quote"
        exit 1
    fi
    
    # Clean up temp config
    rm -f "${temp_config}"
}

# Generate quote information using system tools
generate_quote_info() {
    log_info "Generating TDX quote information from system..."
    
    local quote_info=$(cat << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "system_info": {
        "hostname": "$(hostname)",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)",
        "cpu_info": "$(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)",
        "tdx_status": "$(dmesg | grep -i tdx | head -1)"
    },
    "tdx_capabilities": {
        "tdx_guest_device": $(test -e /dev/tdx_guest && echo "true" || echo "false"),
        "tdx_modules": $(lsmod | grep -i tdx | wc -l),
        "tdx_dmesg_entries": $(dmesg | grep -i tdx | wc -l)
    },
    "memory_info": {
        "total_memory": "$(free -h | grep '^Mem:' | awk '{print $2}')",
        "available_memory": "$(free -h | grep '^Mem:' | awk '{print $7}')"
    },
    "security_features": {
        "sme_active": $(dmesg | grep -i "Memory Encryption Features active" | grep -i sme > /dev/null && echo "true" || echo "false"),
        "tdx_active": $(dmesg | grep -i "Memory Encryption Features active" | grep -i tdx > /dev/null && echo "true" || echo "false")
    }
}
EOF
)
    
    echo "${quote_info}" | jq '.' > "${QUOTE_INFO_FILE}" 2>/dev/null || echo "${quote_info}" > "${QUOTE_INFO_FILE}"
    log_success "TDX quote information saved to: ${QUOTE_INFO_FILE}"
}

# Display quote information
display_quote_info() {
    log_info "=== TDX Quote Information ==="
    
    if [[ -f "${QUOTE_INFO_FILE}" ]]; then
        if command -v jq &> /dev/null; then
            jq '.' "${QUOTE_INFO_FILE}"
        else
            cat "${QUOTE_INFO_FILE}"
        fi
    else
        log_warning "No quote information file found"
    fi
    
    echo
    log_info "=== TDX System Status ==="
    log_info "TDX dmesg entries:"
    dmesg | grep -i tdx | head -5 | while read line; do
        log_info "  ${line}"
    done
    
    echo
    log_info "TDX kernel modules:"
    lsmod | grep -i tdx | while read line; do
        log_info "  ${line}"
    done
}

# Main execution
main() {
    log_info "Starting TDX Quote Generation"
    
    # Initialize log file
    echo "=== TDX Quote Generator Log ===" > "${LOG_FILE}"
    echo "Started at: $(date)" >> "${LOG_FILE}"
    echo >> "${LOG_FILE}"
    
    # Check prerequisites
    check_root
    check_tdx_availability
    check_tdx_tools
    
    # Generate quote information
    generate_quote_info
    
    # Try to generate actual quote if CLI is available
    if command -v trustauthority-cli &> /dev/null; then
        generate_quote_with_cli
    else
        log_warning "Intel Trust Authority CLI not available, generating system information only"
    fi
    
    # Display results
    display_quote_info
    
    log_success "TDX quote generation completed!"
    log_info "Files created:"
    echo "  - Quote info: ${QUOTE_INFO_FILE}"
    if [[ -f "${QUOTE_FILE}" ]]; then
        echo "  - Quote binary: ${QUOTE_FILE}"
    fi
    echo "  - Log: ${LOG_FILE}"
    echo
    log_info "Output directories:"
    echo "  - JSON files: ${JSON_DIR}"
    echo "  - Log files: ${LOG_DIR}"
}

# Handle script interruption
trap 'log_error "Script interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"
