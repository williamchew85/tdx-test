#!/bin/bash

# TDX Quote Verifier Script
# This script verifies TDX quotes and attestation tokens

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

# Display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -e, --evidence FILE    Verify TDX evidence file"
    echo "  -t, --token FILE       Verify attestation token file"
    echo "  -q, --quote FILE       Verify TDX quote file"
    echo "  -a, --all              Verify all available files"
    echo "  -h, --help             Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --evidence tdx-evidence.json"
    echo "  $0 --token tdx-token.json"
    echo "  $0 --all"
}

# Verify TDX evidence file
verify_evidence() {
    local evidence_file="$1"
    
    log_info "Verifying TDX evidence file: ${evidence_file}"
    
    if [[ ! -f "${evidence_file}" ]]; then
        log_error "Evidence file not found: ${evidence_file}"
        return 1
    fi
    
    local verification_result=""
    local is_valid=false
    
    # Check if file is valid JSON
    if jq empty "${evidence_file}" 2>/dev/null; then
        log_success "Evidence file is valid JSON"
        
        # Check for required fields
        local has_evidence=$(jq -e '.evidence' "${evidence_file}" > /dev/null 2>&1 && echo "true" || echo "false")
        local has_quote=$(jq -e '.evidence.quote' "${evidence_file}" > /dev/null 2>&1 && echo "true" || echo "false")
        local has_report_data=$(jq -e '.evidence.reportData' "${evidence_file}" > /dev/null 2>&1 && echo "true" || echo "false")
        
        if [[ "${has_evidence}" == "true" ]]; then
            log_success "Evidence structure is valid"
            is_valid=true
            
            # Extract and display key information
            local evidence_size=$(jq -r '.evidence | keys | length' "${evidence_file}")
            log_info "Evidence contains ${evidence_size} fields"
            
            if [[ "${has_quote}" == "true" ]]; then
                local quote_size=$(jq -r '.evidence.quote | length' "${evidence_file}")
                log_info "Quote size: ${quote_size} characters"
            fi
            
            if [[ "${has_report_data}" == "true" ]]; then
                local report_data_size=$(jq -r '.evidence.reportData | length' "${evidence_file}")
                log_info "Report data size: ${report_data_size} characters"
            fi
        else
            log_error "Evidence structure is invalid - missing 'evidence' field"
        fi
    else
        log_error "Evidence file is not valid JSON"
    fi
    
    verification_result="{\"file\": \"${evidence_file}\", \"valid\": ${is_valid}, \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    echo "${verification_result}"
}

# Verify attestation token
verify_token() {
    local token_file="$1"
    
    log_info "Verifying attestation token file: ${token_file}"
    
    if [[ ! -f "${token_file}" ]]; then
        log_error "Token file not found: ${token_file}"
        return 1
    fi
    
    local verification_result=""
    local is_valid=false
    
    # Check if file is valid JSON
    if jq empty "${token_file}" 2>/dev/null; then
        log_success "Token file is valid JSON"
        
        # Check for token field
        local has_token=$(jq -e '.token' "${token_file}" > /dev/null 2>&1 && echo "true" || echo "false")
        
        if [[ "${has_token}" == "true" ]]; then
            local token_value=$(jq -r '.token' "${token_file}")
            
            if [[ -n "${token_value}" && "${token_value}" != "null" ]]; then
                log_success "Token is present and non-empty"
                is_valid=true
                
                # Basic token format validation (JWT-like structure)
                local token_parts=$(echo "${token_value}" | tr '.' '\n' | wc -l)
                if [[ ${token_parts} -eq 3 ]]; then
                    log_success "Token appears to be in JWT format (3 parts)"
                else
                    log_warning "Token format is not standard JWT (${token_parts} parts)"
                fi
                
                # Display token preview
                local token_preview=$(echo "${token_value}" | head -c 50)
                log_info "Token preview: ${token_preview}..."
            else
                log_error "Token is empty or null"
            fi
        else
            log_error "Token structure is invalid - missing 'token' field"
        fi
    else
        log_error "Token file is not valid JSON"
    fi
    
    verification_result="{\"file\": \"${token_file}\", \"valid\": ${is_valid}, \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    echo "${verification_result}"
}

# Verify TDX quote file
verify_quote() {
    local quote_file="$1"
    
    log_info "Verifying TDX quote file: ${quote_file}"
    
    if [[ ! -f "${quote_file}" ]]; then
        log_error "Quote file not found: ${quote_file}"
        return 1
    fi
    
    local verification_result=""
    local is_valid=false
    
    # Check file size (TDX quotes are typically several KB)
    local file_size=$(stat -c%s "${quote_file}")
    log_info "Quote file size: ${file_size} bytes"
    
    if [[ ${file_size} -gt 0 ]]; then
        log_success "Quote file is not empty"
        
        # Check if it's a binary file
        if file "${quote_file}" | grep -q "data\|binary"; then
            log_success "Quote file appears to be binary data"
            is_valid=true
        else
            log_warning "Quote file may not be binary data"
            # Check if it's base64 encoded
            if head -c 100 "${quote_file}" | base64 -d > /dev/null 2>&1; then
                log_info "Quote file appears to be base64 encoded"
                is_valid=true
            fi
        fi
        
        # Display first few bytes in hex
        local hex_preview=$(xxd -l 32 "${quote_file}" | head -2)
        log_info "Quote hex preview:"
        echo "${hex_preview}" | while read line; do
            log_info "  ${line}"
        done
    else
        log_error "Quote file is empty"
    fi
    
    verification_result="{\"file\": \"${quote_file}\", \"valid\": ${is_valid}, \"size\": ${file_size}, \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    echo "${verification_result}"
}

# Verify all available files
verify_all() {
    log_info "Verifying all available TDX files..."
    
    local verification_results="[]"
    local files_found=0
    
    # Check for evidence files in both old and new locations
    local evidence_files=(
        "${SCRIPT_DIR}/tdx-evidence.json"
        "${JSON_DIR}/tdx-evidence.json"
        "${JSON_DIR}/tdx-local-evidence.json"
        "${JSON_DIR}/tdx-mock-evidence.json"
    )
    
    for evidence_file in "${evidence_files[@]}"; do
        if [[ -f "${evidence_file}" ]]; then
            log_info "Found evidence file: ${evidence_file}"
            local result=$(verify_evidence "${evidence_file}")
            verification_results=$(echo "${verification_results}" | jq ". + [${result}]")
            ((files_found++))
        fi
    done
    
    # Check for token files in both old and new locations
    local token_files=(
        "${SCRIPT_DIR}/tdx-token.json"
        "${JSON_DIR}/tdx-token.json"
        "${JSON_DIR}/tdx-mock-token.json"
    )
    
    for token_file in "${token_files[@]}"; do
        if [[ -f "${token_file}" ]]; then
            log_info "Found token file: ${token_file}"
            local result=$(verify_token "${token_file}")
            verification_results=$(echo "${verification_results}" | jq ". + [${result}]")
            ((files_found++))
        fi
    done
    
    # Check for quote files in both old and new locations
    local quote_files=(
        "${SCRIPT_DIR}/tdx-quote.bin"
        "${JSON_DIR}/tdx-quote.bin"
        "${JSON_DIR}/tdx-local-quote.bin"
        "${JSON_DIR}/tdx-mock-quote.bin"
    )
    
    for quote_file in "${quote_files[@]}"; do
        if [[ -f "${quote_file}" ]]; then
            log_info "Found quote file: ${quote_file}"
            local result=$(verify_quote "${quote_file}")
            verification_results=$(echo "${verification_results}" | jq ". + [${result}]")
            ((files_found++))
        fi
    done
    
    if [[ ${files_found} -eq 0 ]]; then
        log_warning "No TDX files found to verify"
        log_info "Run the attestation script first to generate files"
        return 1
    fi
    
    # Generate comprehensive verification report
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
}

# Main execution
main() {
    local evidence_file=""
    local token_file=""
    local quote_file=""
    local verify_all_flag=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -e|--evidence)
                evidence_file="$2"
                shift 2
                ;;
            -t|--token)
                token_file="$2"
                shift 2
                ;;
            -q|--quote)
                quote_file="$2"
                shift 2
                ;;
            -a|--all)
                verify_all_flag=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Initialize log file
    echo "=== TDX Verifier Log ===" > "${LOG_FILE}"
    echo "Started at: $(date)" >> "${LOG_FILE}"
    echo >> "${LOG_FILE}"
    
    log_info "Starting TDX Verification Process"
    
    if [[ "${verify_all_flag}" == "true" ]]; then
        verify_all
    else
        local verification_results="[]"
        
        if [[ -n "${evidence_file}" ]]; then
            local result=$(verify_evidence "${evidence_file}")
            verification_results=$(echo "${verification_results}" | jq ". + [${result}]")
        fi
        
        if [[ -n "${token_file}" ]]; then
            local result=$(verify_token "${token_file}")
            verification_results=$(echo "${verification_results}" | jq ". + [${result}]")
        fi
        
        if [[ -n "${quote_file}" ]]; then
            local result=$(verify_quote "${quote_file}")
            verification_results=$(echo "${verification_results}" | jq ". + [${result}]")
        fi
        
        if [[ -z "${evidence_file}" && -z "${token_file}" && -z "${quote_file}" ]]; then
            log_warning "No files specified for verification"
            usage
            exit 1
        fi
    fi
    
    log_success "TDX verification completed!"
    log_info "Verification report: ${VERIFICATION_REPORT}"
    log_info "Log file: ${LOG_FILE}"
    echo
    log_info "Output directories:"
    echo "  - JSON files: ${JSON_DIR}"
    echo "  - Log files: ${LOG_DIR}"
}

# Handle script interruption
trap 'log_error "Script interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"
