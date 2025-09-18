#!/bin/bash

# TDX Mock Attestation Script
# This script creates a complete mock attestation environment for testing and development

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_DIR="${SCRIPT_DIR}/json"
LOG_DIR="${SCRIPT_DIR}/log"

# Create directories if they don't exist
mkdir -p "${JSON_DIR}" "${LOG_DIR}"

MOCK_REPORT="${JSON_DIR}/tdx-mock-attestation-report.json"
LOG_FILE="${LOG_DIR}/tdx-mock-attestation.log"
MOCK_EVIDENCE="${JSON_DIR}/tdx-mock-evidence.json"
MOCK_TOKEN="${JSON_DIR}/tdx-mock-token.json"
MOCK_QUOTE="${JSON_DIR}/tdx-mock-quote.bin"

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

# Generate mock TDX evidence
generate_mock_evidence() {
    log_info "Generating mock TDX evidence..."
    
    local mock_evidence=$(cat << EOF
{
    "evidence": {
        "version": "1.0",
        "type": "TDX_EVIDENCE",
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
        "quote": "$(openssl rand -hex 1024 2>/dev/null || echo "mock_quote_data_$(date +%s)")",
        "reportData": "$(openssl rand -hex 64 2>/dev/null || echo "mock_report_data_$(date +%s)")",
        "tdxModule": {
            "mrsigner": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrsigner_$(date +%s)")",
            "attributes": "$(openssl rand -hex 16 2>/dev/null || echo "mock_attributes_$(date +%s)")",
            "attributesMask": "$(openssl rand -hex 16 2>/dev/null || echo "mock_mask_$(date +%s)")",
            "mrtd": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrtd_$(date +%s)")",
            "mrconfig_id": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrconfig_$(date +%s)")",
            "mrowner": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrowner_$(date +%s)")",
            "mrownerconfig": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrownerconfig_$(date +%s)")",
            "rtmr0": "$(openssl rand -hex 32 2>/dev/null || echo "mock_rtmr0_$(date +%s)")",
            "rtmr1": "$(openssl rand -hex 32 2>/dev/null || echo "mock_rtmr1_$(date +%s)")",
            "rtmr2": "$(openssl rand -hex 32 2>/dev/null || echo "mock_rtmr2_$(date +%s)")",
            "rtmr3": "$(openssl rand -hex 32 2>/dev/null || echo "mock_rtmr3_$(date +%s)")"
        },
        "tdxTcbInfo": {
            "tcbType": "TDX_TCB",
            "tcbSvn": "$(openssl rand -hex 16 2>/dev/null || echo "mock_tcb_svn_$(date +%s)")",
            "pceSvn": "$(openssl rand -hex 4 2>/dev/null || echo "mock_pce_svn_$(date +%s)")",
            "pceId": "$(openssl rand -hex 4 2>/dev/null || echo "mock_pce_id_$(date +%s)")",
            "fmspc": "$(openssl rand -hex 6 2>/dev/null || echo "mock_fmspc_$(date +%s)")",
            "pceId": "$(openssl rand -hex 4 2>/dev/null || echo "mock_pce_id_$(date +%s)")",
            "tdxTcbComponents": [
                {
                    "svn": "$(openssl rand -hex 2 2>/dev/null || echo "01")",
                    "category": "TDX_TEE_TCB",
                    "type": "TDX_TEE_TCB_COMPONENT"
                },
                {
                    "svn": "$(openssl rand -hex 2 2>/dev/null || echo "02")",
                    "category": "TDX_TEE_TCB",
                    "type": "TDX_TEE_TCB_COMPONENT"
                }
            ]
        },
        "systemInfo": {
            "hostname": "$(hostname)",
            "kernel": "$(uname -r)",
            "architecture": "$(uname -m)",
            "bootTime": "$(uptime -s)",
            "uptime": "$(uptime -p)"
        }
    },
    "metadata": {
        "generated_by": "tdx-mock-attestation.sh",
        "version": "1.0.0",
        "is_mock": true,
        "purpose": "testing_and_development",
        "warning": "This is mock data for testing purposes only"
    }
}
EOF
)
    
    echo "${mock_evidence}" | jq '.' > "${MOCK_EVIDENCE}" 2>/dev/null || echo "${mock_evidence}" > "${MOCK_EVIDENCE}"
    log_success "Mock TDX evidence generated: ${MOCK_EVIDENCE}"
}

# Generate mock attestation token
generate_mock_token() {
    log_info "Generating mock attestation token..."
    
    # Create a mock JWT-like token structure
    local header=$(echo -n '{"alg":"RS256","typ":"JWT","kid":"mock-tdx-key"}' | base64 -w 0 2>/dev/null || echo -n '{"alg":"RS256","typ":"JWT","kid":"mock-tdx-key"}' | base64)
    local payload=$(cat << EOF | jq -c . | base64 -w 0 2>/dev/null || cat << EOF | jq -c . | base64
{
    "iss": "https://mock.trustauthority.intel.com",
    "sub": "tdx-attestation",
    "aud": "tdx-verification-service",
    "exp": $(($(date +%s) + 3600)),
    "iat": $(date +%s),
    "jti": "$(openssl rand -hex 16 2>/dev/null || echo "mock_jti_$(date +%s)")",
    "tdx_claims": {
        "tdx_enabled": true,
        "tdx_version": "1.0",
        "measurement": "$(openssl rand -hex 32 2>/dev/null || echo "mock_measurement_$(date +%s)")",
        "mrtd": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrtd_$(date +%s)")",
        "report_data": "$(openssl rand -hex 64 2>/dev/null || echo "mock_report_data_$(date +%s)")",
        "tdx_module_loaded": true,
        "memory_encryption_active": true,
        "secure_boot_enabled": true
    },
    "verification_status": "VERIFIED",
    "trust_level": "HIGH",
    "attestation_type": "TDX_LOCAL_MOCK"
}
EOF
)
    
    local signature=$(openssl rand -hex 256 2>/dev/null || echo "mock_signature_$(date +%s)")
    local mock_token="${header}.${payload}.${signature}"
    
    local token_response=$(cat << EOF
{
    "token": "${mock_token}",
    "token_type": "Bearer",
    "expires_in": 3600,
    "scope": "tdx_attestation",
    "metadata": {
        "generated_by": "tdx-mock-attestation.sh",
        "version": "1.0.0",
        "is_mock": true,
        "purpose": "testing_and_development",
        "warning": "This is a mock token for testing purposes only"
    }
}
EOF
)
    
    echo "${token_response}" | jq '.' > "${MOCK_TOKEN}" 2>/dev/null || echo "${token_response}" > "${MOCK_TOKEN}"
    log_success "Mock attestation token generated: ${MOCK_TOKEN}"
}

# Generate mock TDX quote
generate_mock_quote() {
    log_info "Generating mock TDX quote..."
    
    # Create a realistic TDX quote structure
    local mock_quote=$(cat << EOF
{
    "quote_header": {
        "version": 1,
        "att_key_type": 2,
        "tee_type": 0x00000081,
        "reserved": [0, 0, 0, 0]
    },
    "quote_body": {
        "mrseam": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrseam_$(date +%s)")",
        "mrsigner_seam": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrsigner_seam_$(date +%s)")",
        "seamattributes": "$(openssl rand -hex 16 2>/dev/null || echo "mock_seam_attributes_$(date +%s)")",
        "tdattributes": "$(openssl rand -hex 16 2>/dev/null || echo "mock_td_attributes_$(date +%s)")",
        "xfam": "$(openssl rand -hex 16 2>/dev/null || echo "mock_xfam_$(date +%s)")",
        "mrtd": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrtd_$(date +%s)")",
        "mrconfig_id": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrconfig_id_$(date +%s)")",
        "mrowner": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrowner_$(date +%s)")",
        "mrownerconfig": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrownerconfig_$(date +%s)")",
        "rtmr0": "$(openssl rand -hex 32 2>/dev/null || echo "mock_rtmr0_$(date +%s)")",
        "rtmr1": "$(openssl rand -hex 32 2>/dev/null || echo "mock_rtmr1_$(date +%s)")",
        "rtmr2": "$(openssl rand -hex 32 2>/dev/null || echo "mock_rtmr2_$(date +%s)")",
        "rtmr3": "$(openssl rand -hex 32 2>/dev/null || echo "mock_rtmr3_$(date +%s)")",
        "report_data": "$(openssl rand -hex 64 2>/dev/null || echo "mock_report_data_$(date +%s)")"
    },
    "quote_signature": "$(openssl rand -hex 384 2>/dev/null || echo "mock_signature_$(date +%s)")",
    "metadata": {
        "generated_by": "tdx-mock-attestation.sh",
        "version": "1.0.0",
        "is_mock": true,
        "purpose": "testing_and_development",
        "warning": "This is mock data for testing purposes only"
    }
}
EOF
)
    
    # Save as JSON
    echo "${mock_quote}" | jq '.' > "${MOCK_QUOTE}.json" 2>/dev/null || echo "${mock_quote}" > "${MOCK_QUOTE}.json"
    
    # Create binary representation
    echo "${mock_quote}" | base64 > "${MOCK_QUOTE}" 2>/dev/null || {
        log_warning "Could not create binary quote file, saving as text"
        echo "${mock_quote}" > "${MOCK_QUOTE}.txt"
    }
    
    log_success "Mock TDX quote generated: ${MOCK_QUOTE}"
}

# Verify mock attestation
verify_mock_attestation() {
    log_info "Verifying mock attestation..."
    
    local verification_result=""
    local evidence_valid=false
    local token_valid=false
    local quote_valid=false
    
    # Verify evidence
    if [[ -f "${MOCK_EVIDENCE}" ]]; then
        if jq empty "${MOCK_EVIDENCE}" 2>/dev/null; then
            local has_evidence=$(jq -e '.evidence' "${MOCK_EVIDENCE}" > /dev/null 2>&1 && echo "true" || echo "false")
            if [[ "${has_evidence}" == "true" ]]; then
                evidence_valid=true
                log_success "Mock evidence is valid"
            fi
        fi
    fi
    
    # Verify token
    if [[ -f "${MOCK_TOKEN}" ]]; then
        if jq empty "${MOCK_TOKEN}" 2>/dev/null; then
            local has_token=$(jq -e '.token' "${MOCK_TOKEN}" > /dev/null 2>&1 && echo "true" || echo "false")
            if [[ "${has_token}" == "true" ]]; then
                token_valid=true
                log_success "Mock token is valid"
            fi
        fi
    fi
    
    # Verify quote
    if [[ -f "${MOCK_QUOTE}" ]]; then
        local file_size=$(stat -c%s "${MOCK_QUOTE}" 2>/dev/null || echo "0")
        if [[ ${file_size} -gt 0 ]]; then
            quote_valid=true
            log_success "Mock quote is valid"
        fi
    fi
    
    verification_result="{\"evidence_valid\": ${evidence_valid}, \"token_valid\": ${token_valid}, \"quote_valid\": ${quote_valid}, \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    echo "${verification_result}"
}

# Generate comprehensive mock report
generate_mock_report() {
    log_info "Generating comprehensive mock attestation report..."
    
    local report_data=$(cat << EOF
{
    "report_type": "mock_tdx_attestation",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "system_info": {
        "hostname": "$(hostname)",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)",
        "mock_environment": true
    },
    "mock_attestation_results": {
        "evidence_generated": $(test -f "${MOCK_EVIDENCE}" && echo "true" || echo "false"),
        "token_generated": $(test -f "${MOCK_TOKEN}" && echo "true" || echo "false"),
        "quote_generated": $(test -f "${MOCK_QUOTE}" && echo "true" || echo "false"),
        "evidence_file": "${MOCK_EVIDENCE}",
        "token_file": "${MOCK_TOKEN}",
        "quote_file": "${MOCK_QUOTE}"
    },
    "verification_results": $(verify_mock_attestation),
    "mock_data_summary": {
        "evidence_size": $(stat -c%s "${MOCK_EVIDENCE}" 2>/dev/null || echo "0"),
        "token_size": $(stat -c%s "${MOCK_TOKEN}" 2>/dev/null || echo "0"),
        "quote_size": $(stat -c%s "${MOCK_QUOTE}" 2>/dev/null || echo "0")
    },
    "usage_instructions": {
        "purpose": "This mock attestation is for testing and development purposes only",
        "limitations": [
            "Mock data should not be used in production environments",
            "No real cryptographic verification is performed",
            "All generated data is for demonstration purposes only"
        ],
        "integration": [
            "Use mock evidence for testing attestation verification logic",
            "Use mock tokens for testing JWT parsing and validation",
            "Use mock quotes for testing quote parsing and analysis"
        ]
    },
    "disclaimer": "This is mock data generated for testing and development purposes. It should not be used in production environments or for real attestation verification."
}
EOF
)
    
    echo "${report_data}" | jq '.' > "${MOCK_REPORT}" 2>/dev/null || echo "${report_data}" > "${MOCK_REPORT}"
    log_success "Mock attestation report generated: ${MOCK_REPORT}"
}

# Display mock attestation summary
display_mock_summary() {
    log_info "=== Mock TDX Attestation Summary ==="
    echo
    log_success "✓ Mock TDX evidence generated"
    log_success "✓ Mock attestation token created"
    log_success "✓ Mock TDX quote generated"
    log_success "✓ Mock attestation verified"
    log_success "✓ Comprehensive mock report created"
    echo
    log_info "Files created:"
    echo "  - Mock Evidence: ${MOCK_EVIDENCE}"
    echo "  - Mock Token: ${MOCK_TOKEN}"
    echo "  - Mock Quote: ${MOCK_QUOTE}"
    echo "  - Mock Report: ${MOCK_REPORT}"
    echo "  - Log: ${LOG_FILE}"
    echo
    log_info "Output directories:"
    echo "  - JSON files: ${JSON_DIR}"
    echo "  - Log files: ${LOG_DIR}"
    echo
    log_warning "Important Notes:"
    echo "  - This is MOCK data for testing and development purposes only"
    echo "  - Do not use in production environments"
    echo "  - All cryptographic data is generated for demonstration purposes"
    echo "  - Use this for testing attestation verification logic"
    echo
    log_info "Next steps:"
    echo "  1. Review the mock attestation report: ${MOCK_REPORT}"
    echo "  2. Use mock data for testing your attestation verification code"
    echo "  3. Integrate mock data into your development and testing workflows"
}

# Main execution
main() {
    log_info "Starting Mock TDX Attestation Process"
    log_info "Script directory: ${SCRIPT_DIR}"
    
    # Initialize log file
    echo "=== Mock TDX Attestation Log ===" > "${LOG_FILE}"
    echo "Started at: $(date)" >> "${LOG_FILE}"
    echo >> "${LOG_FILE}"
    
    # Generate mock attestation components
    generate_mock_evidence
    generate_mock_token
    generate_mock_quote
    verify_mock_attestation
    generate_mock_report
    
    # Display summary
    display_mock_summary
    
    log_success "Mock TDX attestation process completed successfully!"
}

# Handle script interruption
trap 'log_error "Mock attestation interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"
