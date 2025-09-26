#!/bin/bash

# TDX Verifier Script
# This script verifies TDX files and provides detailed feedback

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_DIR="${SCRIPT_DIR}/json"
LOG_DIR="${SCRIPT_DIR}/log"

# Create directories if they don't exist
mkdir -p "${JSON_DIR}" "${LOG_DIR}"

# Fix permissions for directories
chmod 755 "${LOG_DIR}" 2>/dev/null || true
chown -R $(whoami):$(whoami) "${LOG_DIR}" 2>/dev/null || true

VERIFICATION_REPORT="${JSON_DIR}/tdx-verification-report.json"
LOG_FILE="${LOG_DIR}/tdx-verifier.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function (with permission handling)
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

# Simple file verification (fixed to prevent hanging)
verify_file() {
    local file_path="$1"
    local file_type="$2"
    
    if [[ ! -f "${file_path}" ]]; then
        echo "{\"file\": \"${file_path}\", \"valid\": false, \"error\": \"file_not_found\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
        return 1
    fi
    
    local file_size=$(stat -c%s "${file_path}" 2>/dev/null || echo "0")
    
    if [[ ${file_size} -eq 0 ]]; then
        echo "{\"file\": \"${file_path}\", \"valid\": false, \"error\": \"file_empty\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
        return 1
    fi
    
    # For JSON files, use timeout to prevent hanging
    if [[ "${file_type}" == "json" ]]; then
        if timeout 5 jq empty "${file_path}" 2>/dev/null; then
            echo "{\"file\": \"${file_path}\", \"valid\": true, \"size\": ${file_size}, \"type\": \"json\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
        else
            echo "{\"file\": \"${file_path}\", \"valid\": false, \"error\": \"invalid_json_or_timeout\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
            return 1
        fi
    else
        # For binary files, just check if they exist and have content
        echo "{\"file\": \"${file_path}\", \"valid\": true, \"size\": ${file_size}, \"type\": \"binary\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    fi
}

# Verify all available files
verify_all() {
    log_info "Verifying all available TDX files..."
    
    local verification_results="[]"
    local files_found=0
    
    # Check for evidence files
    local evidence_files=(
        "${JSON_DIR}/tdx-local-evidence.json"
        "${JSON_DIR}/tdx-mock-evidence.json"
        "${JSON_DIR}/tdx-evidence.json"
    )
    
    for evidence_file in "${evidence_files[@]}"; do
        if [[ -f "${evidence_file}" ]]; then
            log_info "Found evidence file: ${evidence_file}"
            local result=$(verify_file "${evidence_file}" "json")
            if [[ -n "${result}" ]]; then
                verification_results=$(echo "${verification_results}" | jq ". + [${result}]" 2>/dev/null || echo "${verification_results}")
                ((files_found++))
            fi
        fi
    done
    
    # Check for token files
    local token_files=(
        "${JSON_DIR}/tdx-mock-token.json"
        "${JSON_DIR}/tdx-token.json"
    )
    
    for token_file in "${token_files[@]}"; do
        if [[ -f "${token_file}" ]]; then
            log_info "Found token file: ${token_file}"
            local result=$(verify_file "${token_file}" "json")
            if [[ -n "${result}" ]]; then
                verification_results=$(echo "${verification_results}" | jq ". + [${result}]" 2>/dev/null || echo "${verification_results}")
                ((files_found++))
            fi
        fi
    done
    
    # Check for quote files
    local quote_files=(
        "${JSON_DIR}/tdx-local-quote.bin"
        "${JSON_DIR}/tdx-mock-quote.bin"
        "${JSON_DIR}/tdx-quote.bin"
    )
    
    for quote_file in "${quote_files[@]}"; do
        if [[ -f "${quote_file}" ]]; then
            log_info "Found quote file: ${quote_file}"
            local result=$(verify_file "${quote_file}" "binary")
            if [[ -n "${result}" ]]; then
                verification_results=$(echo "${verification_results}" | jq ". + [${result}]" 2>/dev/null || echo "${verification_results}")
                ((files_found++))
            fi
        fi
    done
    
    if [[ ${files_found} -eq 0 ]]; then
        log_warning "No TDX files found to verify"
        return 1
    fi
    
    # Generate verification report
    local report=$(cat << EOF
{
    "verification_timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "files_verified": ${files_found},
    "verification_results": ${verification_results},
    "summary": {
        "total_files": ${files_found},
        "valid_files": $(echo "${verification_results}" | jq '[.[] | select(.valid == true)] | length'),
        "invalid_files": $(echo "${verification_results}" | jq '[.[] | select(.valid == false)] | length')
    }
}
EOF
)
    
    echo "${report}" | jq '.' > "${VERIFICATION_REPORT}" 2>/dev/null || echo "${report}" > "${VERIFICATION_REPORT}"
    log_success "Verification report saved to: ${VERIFICATION_REPORT}"
    
    # Display summary
    log_info "=== Verification Summary ==="
    echo "${report}" | jq -r '.summary | "Total files: \(.total_files), Valid: \(.valid_files), Invalid: \(.invalid_files)"'
    
    # Show results
    echo
    log_info "=== File Verification Results ==="
    echo "${report}" | jq -r '.verification_results[] | "\(.file): \(if .valid then "VALID" else "INVALID" end)"'
    
    return 0
}

# Main execution
main() {
    # Initialize log file (with permission handling)
    if touch "${LOG_FILE}" 2>/dev/null; then
        echo "=== TDX Verifier Log ===" > "${LOG_FILE}"
        echo "Started at: $(date)" >> "${LOG_FILE}"
        echo >> "${LOG_FILE}"
    fi
    
    log_info "Starting TDX Verification Process"
    
    verify_all
    
    log_success "TDX verification completed!"
    log_info "Verification report: ${VERIFICATION_REPORT}"
    log_info "Log file: ${LOG_FILE}"
}

# Run main function with timeout protection
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Only run main if this script is executed directly, not sourced
    main "$@"
fi