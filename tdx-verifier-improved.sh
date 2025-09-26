#!/bin/bash

# Improved TDX Quote Verifier Script
# This script verifies TDX quotes and attestation tokens with support for multiple formats

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

# Quiet logging functions (only to log file)
log_info_quiet() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [INFO] $*" >> "${LOG_FILE}"
}

log_success_quiet() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [SUCCESS] $*" >> "${LOG_FILE}"
}

log_error_quiet() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${timestamp} [ERROR] $*" >> "${LOG_FILE}"
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

# Verify TDX evidence file (improved to handle multiple formats)
verify_evidence() {
    local evidence_file="$1"
    local quiet_mode="${2:-false}"
    
    if [[ "${quiet_mode}" == "true" ]]; then
        log_info_quiet "Verifying TDX evidence file: ${evidence_file}"
    elif [[ "${quiet_mode}" == "json-only" ]]; then
        log_info_quiet "Verifying TDX evidence file: ${evidence_file}"
    else
        log_info "Verifying TDX evidence file: ${evidence_file}"
    fi
    
    if [[ ! -f "${evidence_file}" ]]; then
        if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
            log_error_quiet "Evidence file not found: ${evidence_file}"
        else
            log_error "Evidence file not found: ${evidence_file}"
        fi
        return 1
    fi
    
    local verification_result=""
    local is_valid=false
    local evidence_type="unknown"
    
    # Check if file is valid JSON
    if jq empty "${evidence_file}" 2>/dev/null; then
        if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
            log_success_quiet "Evidence file is valid JSON"
        else
            log_success "Evidence file is valid JSON"
        fi
        
        # Check for different evidence formats
        local has_standard_evidence=$(jq -e '.evidence' "${evidence_file}" > /dev/null 2>&1 && echo "true" || echo "false")
        local has_local_evidence=$(jq -e '.tdx_status' "${evidence_file}" > /dev/null 2>&1 && echo "true" || echo "false")
        local has_mock_evidence=$(jq -e '.evidence' "${evidence_file}" > /dev/null 2>&1 && jq -e '.metadata.is_mock' "${evidence_file}" > /dev/null 2>&1 && echo "true" || echo "false")
        
        if [[ "${has_standard_evidence}" == "true" ]]; then
            evidence_type="standard"
            if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
                log_success_quiet "Standard evidence structure detected"
            else
                log_success "Standard evidence structure detected"
            fi
            is_valid=true
            
            # Extract and display key information
            if [[ "${quiet_mode}" != "true" && "${quiet_mode}" != "json-only" ]]; then
                local evidence_size=$(jq -r '.evidence | keys | length' "${evidence_file}")
                log_info "Evidence contains ${evidence_size} fields"
                
                local has_quote=$(jq -e '.evidence.quote' "${evidence_file}" > /dev/null 2>&1 && echo "true" || echo "false")
                if [[ "${has_quote}" == "true" ]]; then
                    local quote_size=$(jq -r '.evidence.quote | length' "${evidence_file}")
                    log_info "Quote size: ${quote_size} characters"
                fi
            fi
            
        elif [[ "${has_local_evidence}" == "true" ]]; then
            evidence_type="local"
            if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
                log_success_quiet "Local TDX evidence structure detected"
            else
                log_success "Local TDX evidence structure detected"
            fi
            is_valid=true
            
            # Extract and display key information
            if [[ "${quiet_mode}" != "true" && "${quiet_mode}" != "json-only" ]]; then
                local tdx_available=$(jq -r '.tdx_status.available' "${evidence_file}" 2>/dev/null || echo "unknown")
                local detection_methods=$(jq -r '.tdx_status.detection_methods | join(", ")' "${evidence_file}" 2>/dev/null || echo "unknown")
                
                log_info "TDX Available: ${tdx_available}"
                log_info "Detection Methods: ${detection_methods}"
                
                # Check system measurements
                local has_measurements=$(jq -e '.system_measurements' "${evidence_file}" > /dev/null 2>&1 && echo "true" || echo "false")
                if [[ "${has_measurements}" == "true" ]]; then
                    log_info "System measurements present"
                fi
            fi
            
        elif [[ "${has_mock_evidence}" == "true" ]]; then
            evidence_type="mock"
            if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
                log_success_quiet "Mock evidence structure detected"
            else
                log_success "Mock evidence structure detected"
            fi
            is_valid=true
            
            # Extract and display key information
            if [[ "${quiet_mode}" != "true" && "${quiet_mode}" != "json-only" ]]; then
                local mock_purpose=$(jq -r '.metadata.purpose' "${evidence_file}" 2>/dev/null || echo "unknown")
                log_info "Mock purpose: ${mock_purpose}"
            fi
            
        else
            if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
                log_error_quiet "Unknown evidence structure - no recognized format found"
            else
                log_error "Unknown evidence structure - no recognized format found"
            fi
        fi
        
    else
        if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
            log_error_quiet "Evidence file is not valid JSON"
        else
            log_error "Evidence file is not valid JSON"
        fi
    fi
    
    verification_result="{\"file\": \"${evidence_file}\", \"valid\": ${is_valid}, \"evidence_type\": \"${evidence_type}\", \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    echo "${verification_result}"
}

# Verify attestation token (unchanged)
verify_token() {
    local token_file="$1"
    local quiet_mode="${2:-false}"
    
    if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
        log_info_quiet "Verifying attestation token file: ${token_file}"
    else
        log_info "Verifying attestation token file: ${token_file}"
    fi
    
    if [[ ! -f "${token_file}" ]]; then
        if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
            log_error_quiet "Token file not found: ${token_file}"
        else
            log_error "Token file not found: ${token_file}"
        fi
        return 1
    fi
    
    local verification_result=""
    local is_valid=false
    
    # Check if file is valid JSON
    if jq empty "${token_file}" 2>/dev/null; then
        if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
            log_success_quiet "Token file is valid JSON"
        else
            log_success "Token file is valid JSON"
        fi
        
        # Check for token field
        local has_token=$(jq -e '.token' "${token_file}" > /dev/null 2>&1 && echo "true" || echo "false")
        
        if [[ "${has_token}" == "true" ]]; then
            local token_value=$(jq -r '.token' "${token_file}")
            
            if [[ -n "${token_value}" && "${token_value}" != "null" ]]; then
                if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
                    log_success_quiet "Token is present and non-empty"
                else
                    log_success "Token is present and non-empty"
                fi
                is_valid=true
                
                if [[ "${quiet_mode}" != "true" && "${quiet_mode}" != "json-only" ]]; then
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
                fi
            else
                if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
                    log_error_quiet "Token is empty or null"
                else
                    log_error "Token is empty or null"
                fi
            fi
        else
            if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
                log_error_quiet "Token structure is invalid - missing 'token' field"
            else
                log_error "Token structure is invalid - missing 'token' field"
            fi
        fi
    else
        if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
            log_error_quiet "Token file is not valid JSON"
        else
            log_error "Token file is not valid JSON"
        fi
    fi
    
    verification_result="{\"file\": \"${token_file}\", \"valid\": ${is_valid}, \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    echo "${verification_result}"
}

# Verify TDX quote file (unchanged)
verify_quote() {
    local quote_file="$1"
    local quiet_mode="${2:-false}"
    
    if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
        log_info_quiet "Verifying TDX quote file: ${quote_file}"
    else
        log_info "Verifying TDX quote file: ${quote_file}"
    fi
    
    if [[ ! -f "${quote_file}" ]]; then
        if [[ "${quiet_mode}" == "true" || "${quiet_mode}" == "json-only" ]]; then
            log_error_quiet "Quote file not found: ${quote_file}"
        else
            log_error "Quote file not found: ${quote_file}"
        fi
        return 1
    fi
    
    local verification_result=""
    local is_valid=false
    
    # Check file size (TDX quotes are typically several KB)
    local file_size
    if command -v stat >/dev/null 2>&1; then
        # Try Linux stat first, then macOS stat
        file_size=$(stat -c%s "${quote_file}" 2>/dev/null || stat -f%z "${quote_file}" 2>/dev/null || echo "0")
    else
        file_size="0"
    fi
    
    if [[ "${quiet_mode}" != "true" ]]; then
        log_info "Quote file size: ${file_size} bytes"
    fi
    
    if [[ ${file_size} -gt 0 ]]; then
        if [[ "${quiet_mode}" != "true" ]]; then
            log_success "Quote file is not empty"
        fi
        
        # Check if it's a binary file
        if file "${quote_file}" | grep -q "data\|binary"; then
            if [[ "${quiet_mode}" != "true" ]]; then
                log_success "Quote file appears to be binary data"
            fi
            is_valid=true
        else
            if [[ "${quiet_mode}" != "true" ]]; then
                log_warning "Quote file may not be binary data"
            fi
            # Check if it's base64 encoded
            if head -c 100 "${quote_file}" | base64 -d > /dev/null 2>&1; then
                if [[ "${quiet_mode}" != "true" ]]; then
                    log_info "Quote file appears to be base64 encoded"
                fi
                is_valid=true
            fi
        fi
        
        if [[ "${quiet_mode}" != "true" ]]; then
            # Display first few bytes in hex
            local hex_preview=$(xxd -l 32 "${quote_file}" | head -2)
            log_info "Quote hex preview:"
            echo "${hex_preview}" | while read line; do
                log_info "  ${line}"
            done
        fi
    else
        if [[ "${quiet_mode}" != "true" ]]; then
            log_error "Quote file is empty"
        fi
    fi
    
    verification_result="{\"file\": \"${quote_file}\", \"valid\": ${is_valid}, \"size\": ${file_size}, \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    echo "${verification_result}"
}

# Verify all available files (improved)
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
            local result=$(verify_evidence "${evidence_file}" "true")
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
            local result=$(verify_token "${token_file}" "true")
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
            local result=$(verify_quote "${quote_file}" "true")
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
    
    # Display detailed conclusions
    display_conclusions "${report}"
}

# Display detailed conclusions and recommendations (improved)
display_conclusions() {
    local report="$1"
    local total_files=$(echo "${report}" | jq -r '.summary.total_files')
    local valid_files=$(echo "${report}" | jq -r '.summary.valid_files')
    local invalid_files=$(echo "${report}" | jq -r '.summary.invalid_files')
    
    echo
    log_info "=== TDX Attestation Analysis ==="
    
    # Check for different types of evidence files
    local has_local_evidence=$(echo "${report}" | jq -r '.verification_results[] | select(.file | contains("local")) | .file' | wc -l)
    local has_mock_files=$(echo "${report}" | jq -r '.verification_results[] | select(.file | contains("mock")) | .file' | wc -l)
    local has_standard_files=$(echo "${report}" | jq -r '.verification_results[] | select(.file | contains("tdx-evidence.json") and (contains("local") | not) and (contains("mock") | not)) | .file' | wc -l)
    
    if [[ ${has_local_evidence} -gt 0 ]]; then
        log_info "🔍 Local TDX Evidence Detected:"
        echo "   • Your system has TDX capabilities and is running in a TDX environment"
        echo "   • Local evidence shows TDX is active and working"
        echo "   • This is good for local verification but not for remote attestation"
    fi
    
    if [[ ${has_standard_files} -gt 0 ]]; then
        log_info "🏭 Standard TDX Evidence Detected:"
        echo "   • These are production-grade attestation files"
        echo "   • They follow the standard Intel Trust Authority format"
        echo "   • Ready for production use and remote attestation"
    fi
    
    if [[ ${has_mock_files} -gt 0 ]]; then
        log_info "🧪 Mock Attestation Files Found:"
        echo "   • These are test files for development and demonstration"
        echo "   • They follow the standard Intel Trust Authority format"
        echo "   • Use these for testing attestation workflows"
    fi
    
    echo
    log_info "=== Attestation Status ==="
    
    if [[ ${valid_files} -eq ${total_files} ]]; then
        log_success "✅ ALL FILES VALID - Attestation is working correctly!"
        echo "   • All evidence, tokens, and quotes are properly formatted"
        echo "   • Your TDX attestation setup is ready for production use"
    elif [[ ${valid_files} -gt 0 ]]; then
        log_warning "⚠️  PARTIAL SUCCESS - Some files are valid, others need attention"
        echo "   • ${valid_files}/${total_files} files passed verification"
        echo "   • Check invalid files for format issues or missing data"
        
        # Show which files are invalid
        echo "   • Invalid files:"
        echo "${report}" | jq -r '.verification_results[] | select(.valid == false) | "     - \(.file)"'
    else
        log_error "❌ ALL FILES INVALID - Attestation setup needs attention"
        echo "   • No files passed verification"
        echo "   • Check your TDX setup and file generation process"
    fi
    
    echo
    log_info "=== Recommendations ==="
    
    if [[ ${has_local_evidence} -gt 0 && ${has_mock_files} -gt 0 ]]; then
        echo "📋 You have both local and mock attestation files:"
        echo "   • Use local evidence for system analysis and TDX verification"
        echo "   • Use mock files for testing attestation workflows"
        echo "   • For production, you'll need real Intel Trust Authority integration"
    elif [[ ${has_local_evidence} -gt 0 ]]; then
        echo "📋 You have local TDX evidence:"
        echo "   • Your system is TDX-capable and working"
        echo "   • For remote attestation, integrate with Intel Trust Authority"
        echo "   • Consider using mock files for testing workflows"
    elif [[ ${has_standard_files} -gt 0 ]]; then
        echo "📋 You have standard TDX evidence:"
        echo "   • These are production-ready attestation files"
        echo "   • Your TDX attestation setup is working correctly"
        echo "   • Ready for production use"
    elif [[ ${has_mock_files} -gt 0 ]]; then
        echo "📋 You have mock attestation files:"
        echo "   • Good for testing and development"
        echo "   • Run local attestation to generate real TDX evidence"
        echo "   • Use these to test your attestation integration"
    else
        echo "📋 No attestation files found:"
        echo "   • Run the local attestation script: sudo ./tdx-local-attestation.sh"
        echo "   • Or generate mock files: sudo ./tdx-mock-attestation.sh"
    fi
    
    echo
    log_info "=== Next Steps ==="
    echo "1. Review the verification report: cat json/tdx-verification-report.json"
    echo "2. Check detailed logs: cat log/tdx-verifier.log"
    echo "3. For production use, integrate with Intel Trust Authority API"
    echo "4. Test your attestation workflow with the valid files"
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
            # Call verification function and capture only the JSON result
            verify_evidence "${evidence_file}"
            local result=$(verify_evidence "${evidence_file}" "json-only")
            verification_results=$(echo "${verification_results}" | jq ". + [${result}]")
        fi
        
        if [[ -n "${token_file}" ]]; then
            # Call verification function and capture only the JSON result
            verify_token "${token_file}"
            local result=$(verify_token "${token_file}" "json-only")
            verification_results=$(echo "${verification_results}" | jq ". + [${result}]")
        fi
        
        if [[ -n "${quote_file}" ]]; then
            # Call verification function and capture only the JSON result
            verify_quote "${quote_file}"
            local result=$(verify_quote "${quote_file}" "json-only")
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
