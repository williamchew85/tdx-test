#!/bin/bash

# Simple TDX Verifier Script
# This script performs basic verification without complex processing

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_DIR="${SCRIPT_DIR}/json"
LOG_DIR="${SCRIPT_DIR}/log"

# Create directories if they don't exist
mkdir -p "${JSON_DIR}" "${LOG_DIR}"

VERIFICATION_REPORT="${JSON_DIR}/tdx-verification-report.json"
LOG_FILE="${LOG_DIR}/tdx-verifier.log"

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
    echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}" 2>/dev/null || echo -e "${timestamp} [${level}] ${message}"
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

# Simple file check (no complex processing)
check_file() {
    local file_path="$1"
    local file_name=$(basename "${file_path}")
    
    if [[ -f "${file_path}" ]]; then
        local file_size=$(stat -c%s "${file_path}" 2>/dev/null || echo "0")
        if [[ ${file_size} -gt 0 ]]; then
            log_success "✓ ${file_name} (${file_size} bytes)"
            return 0
        else
            log_warning "⚠ ${file_name} (empty file)"
            return 1
        fi
    else
        log_error "✗ ${file_name} (not found)"
        return 1
    fi
}

# Main verification
main() {
    log_info "Starting Simple TDX File Verification"
    echo
    
    local total_files=0
    local valid_files=0
    
    # Check evidence files
    log_info "=== Evidence Files ==="
    local evidence_files=(
        "${JSON_DIR}/tdx-local-evidence.json"
        "${JSON_DIR}/tdx-mock-evidence.json"
        "${JSON_DIR}/tdx-evidence.json"
    )
    
    for evidence_file in "${evidence_files[@]}"; do
        ((total_files++))
        if check_file "${evidence_file}"; then
            ((valid_files++))
        fi
    done
    
    echo
    
    # Check token files
    log_info "=== Token Files ==="
    local token_files=(
        "${JSON_DIR}/tdx-mock-token.json"
        "${JSON_DIR}/tdx-token.json"
    )
    
    for token_file in "${token_files[@]}"; do
        ((total_files++))
        if check_file "${token_file}"; then
            ((valid_files++))
        fi
    done
    
    echo
    
    # Check quote files
    log_info "=== Quote Files ==="
    local quote_files=(
        "${JSON_DIR}/tdx-local-quote.bin"
        "${JSON_DIR}/tdx-mock-quote.bin"
        "${JSON_DIR}/tdx-quote.bin"
    )
    
    for quote_file in "${quote_files[@]}"; do
        ((total_files++))
        if check_file "${quote_file}"; then
            ((valid_files++))
        fi
    done
    
    echo
    
    # Summary
    log_info "=== Verification Summary ==="
    log_info "Total files checked: ${total_files}"
    log_success "Valid files: ${valid_files}"
    
    if [[ ${valid_files} -gt 0 ]]; then
        log_success "TDX verification completed successfully!"
        return 0
    else
        log_error "No valid TDX files found"
        return 1
    fi
}

# Run main function only if executed directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
