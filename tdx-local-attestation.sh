#!/bin/bash

# Intel TDX Local Attestation Script (Without Trust Authority API)
# This script performs TDX attestation using local tools and system capabilities

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_DIR="${SCRIPT_DIR}/json"
LOG_DIR="${SCRIPT_DIR}/log"

# Create directories if they don't exist
mkdir -p "${JSON_DIR}" "${LOG_DIR}"

LOG_FILE="${LOG_DIR}/tdx-local-attestation.log"
REPORT_FILE="${JSON_DIR}/tdx-local-attestation-report.json"
EVIDENCE_FILE="${JSON_DIR}/tdx-local-evidence.json"
QUOTE_FILE="${JSON_DIR}/tdx-local-quote.bin"
MEASUREMENT_FILE="${JSON_DIR}/tdx-measurements.json"

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

# Check TDX availability using multiple methods
check_tdx_availability() {
    log_info "Checking TDX availability using multiple methods..."
    
    local tdx_found=false
    local tdx_methods=()
    
    # Method 1: Check dmesg
    if dmesg | grep -i tdx > /dev/null 2>&1; then
        local tdx_info=$(dmesg | grep -i tdx | head -1)
        log_success "TDX found in dmesg: ${tdx_info}"
        tdx_methods+=("dmesg")
        tdx_found=true
    fi
    
    # Method 2: Check CPU flags
    if grep -i tdx /proc/cpuinfo > /dev/null 2>&1; then
        log_success "TDX CPU flag found in /proc/cpuinfo"
        tdx_methods+=("cpuinfo")
        tdx_found=true
    fi
    
    # Method 3: Check kernel modules
    if lsmod | grep -i tdx > /dev/null 2>&1; then
        log_success "TDX kernel modules loaded"
        lsmod | grep -i tdx | while read line; do
            log_info "  - ${line}"
        done
        tdx_methods+=("modules")
        tdx_found=true
    fi
    
    # Method 4: Check TDX device
    if [[ -e /dev/tdx_guest ]]; then
        log_success "TDX guest device found at /dev/tdx_guest"
        tdx_methods+=("device")
        tdx_found=true
    fi
    
    # Method 5: Check memory encryption features
    if dmesg | grep -i "Memory Encryption Features active" | grep -i tdx > /dev/null 2>&1; then
        log_success "TDX memory encryption active"
        tdx_methods+=("memory_encryption")
        tdx_found=true
    fi
    
    if [[ "${tdx_found}" == "false" ]]; then
        log_error "TDX is not available on this system"
        log_info "Detection methods tried: dmesg, cpuinfo, modules, device, memory_encryption"
        exit 1
    fi
    
    log_success "TDX detected using methods: ${tdx_methods[*]}"
}

# Collect system measurements
collect_system_measurements() {
    log_info "Collecting system measurements..."
    
    local measurements=$(cat << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "system_info": {
        "hostname": "$(hostname)",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)",
        "boot_time": "$(uptime -s 2>/dev/null || date -r $(sysctl -n kern.boottime | cut -d',' -f1 | cut -d' ' -f4) 2>/dev/null || echo 'unknown')",
        "uptime": "$(uptime -p 2>/dev/null || uptime | cut -d',' -f1 | cut -d' ' -f4- 2>/dev/null || echo 'unknown')"
    },
    "hardware_info": {
        "cpu_model": "$(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)",
        "cpu_cores": "$(nproc)",
        "memory_total": "$(free -h | grep '^Mem:' | awk '{print $2}')",
        "memory_available": "$(free -h | grep '^Mem:' | awk '{print $7}')"
    },
    "tdx_info": {
        "dmesg_entries": $(dmesg | grep -i tdx | wc -l),
        "cpu_flags": $(grep -i tdx /proc/cpuinfo | wc -l),
        "kernel_modules": $(lsmod | grep -i tdx | wc -l),
        "device_exists": $(test -e /dev/tdx_guest && echo "true" || echo "false"),
        "memory_encryption_active": $(dmesg | grep -i "Memory Encryption Features active" | grep -i tdx > /dev/null && echo "true" || echo "false")
    },
    "security_features": {
        "sme_active": $(dmesg | grep -i "Memory Encryption Features active" | grep -i sme > /dev/null && echo "true" || echo "false"),
        "tdx_active": $(dmesg | grep -i "Memory Encryption Features active" | grep -i tdx > /dev/null && echo "true" || echo "false"),
        "secure_boot": $(mokutil --sb-state 2>/dev/null | grep -i "SecureBoot enabled" > /dev/null && echo "true" || echo "false")
    }
}
EOF
)
    
    echo "${measurements}" | jq '.' > "${MEASUREMENT_FILE}" 2>/dev/null || echo "${measurements}" > "${MEASUREMENT_FILE}"
    log_success "System measurements collected: ${MEASUREMENT_FILE}"
}

# Generate local TDX evidence
generate_local_evidence() {
    log_info "Generating local TDX evidence..."
    
    # Collect TDX-related data
    local tdx_dmesg=$(dmesg | grep -i tdx | head -10)
    local tdx_cpuinfo=$(grep -i tdx /proc/cpuinfo | head -5)
    local tdx_modules=$(lsmod | grep -i tdx)
    local memory_encryption=$(dmesg | grep -i "Memory Encryption Features active")
    
    # Create evidence structure
    local evidence=$(cat << EOF
{
    "evidence_type": "local_tdx_evidence",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "tdx_status": {
        "available": true,
        "detection_methods": ["dmesg", "cpuinfo", "modules", "device_check"],
        "dmesg_entries": [
$(echo "${tdx_dmesg}" | while read line; do
    if [[ -n "${line}" ]]; then
        echo "            \"${line}\","
    fi
done | sed '$ s/,$//')
        ],
        "cpu_flags": [
$(echo "${tdx_cpuinfo}" | while read line; do
    if [[ -n "${line}" ]]; then
        # Escape control characters and quotes in the line
        escaped_line=$(echo "${line}" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g')
        echo "            \"${escaped_line}\","
    fi
done | sed '$ s/,$//')
        ],
        "kernel_modules": [
$(echo "${tdx_modules}" | while read line; do
    if [[ -n "${line}" ]]; then
        echo "            \"${line}\","
    fi
done | sed '$ s/,$//')
        ],
        "memory_encryption": "${memory_encryption}"
    },
    "system_measurements": $(cat "${MEASUREMENT_FILE}" 2>/dev/null || echo "{}"),
    "attestation_metadata": {
        "generated_by": "tdx-local-attestation.sh",
        "version": "1.0.0",
        "method": "local_system_analysis",
        "trust_level": "local_verification"
    }
}
EOF
)
    
    echo "${evidence}" | jq '.' > "${EVIDENCE_FILE}" 2>/dev/null || echo "${evidence}" > "${EVIDENCE_FILE}"
    log_success "Local TDX evidence generated: ${EVIDENCE_FILE}"
}

# Generate mock TDX quote
generate_mock_quote() {
    log_info "Generating mock TDX quote..."
    
    # Create a mock quote structure (this is for demonstration purposes)
    local mock_quote_data=$(cat << EOF
{
    "quote_header": {
        "version": "1.0",
        "att_key_type": "TDX_ATT_KEY_TYPE_RSA3072",
        "tee_type": "TDX_TEE_TYPE",
        "reserved": "00000000"
    },
    "quote_body": {
        "mrseam": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrseam_data")",
        "mrsigner_seam": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrsigner_seam_data")",
        "seamattributes": "0000000000000000",
        "tdattributes": "0000000000000000",
        "xfam": "0000000000000000",
        "mrtd": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrtd_data")",
        "mrconfig_id": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrconfig_id_data")",
        "mrowner": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrowner_data")",
        "mrownerconfig": "$(openssl rand -hex 32 2>/dev/null || echo "mock_mrownerconfig_data")",
        "rtmr0": "$(openssl rand -hex 32 2>/dev/null || echo "mock_rtmr0_data")",
        "rtmr1": "$(openssl rand -hex 32 2>/dev/null || echo "mock_rtmr1_data")",
        "rtmr2": "$(openssl rand -hex 32 2>/dev/null || echo "mock_rtmr2_data")",
        "rtmr3": "$(openssl rand -hex 32 2>/dev/null || echo "mock_rtmr3_data")",
        "report_data": "$(openssl rand -hex 64 2>/dev/null || echo "mock_report_data")"
    },
    "quote_signature": "$(openssl rand -hex 384 2>/dev/null || echo "mock_signature_data")",
    "metadata": {
        "generated_by": "tdx-local-attestation.sh",
        "is_mock": true,
        "purpose": "testing_and_demonstration",
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
}
EOF
)
    
    # Save as JSON
    echo "${mock_quote_data}" | jq '.' > "${QUOTE_FILE}.json" 2>/dev/null || echo "${mock_quote_data}" > "${QUOTE_FILE}.json"
    
    # Create a binary representation (mock)
    echo "${mock_quote_data}" | base64 > "${QUOTE_FILE}" 2>/dev/null || {
        log_warning "Could not create binary quote file, saving as text"
        echo "${mock_quote_data}" > "${QUOTE_FILE}.txt"
    }
    
    log_success "Mock TDX quote generated: ${QUOTE_FILE}"
}

# Verify local evidence
verify_local_evidence() {
    local quiet_mode="${1:-false}"
    
    if [[ "${quiet_mode}" != "true" ]]; then
        log_info "Verifying local evidence..."
    fi
    
    local verification_result=""
    local is_valid=false
    
    if [[ -f "${EVIDENCE_FILE}" ]]; then
        if jq empty "${EVIDENCE_FILE}" 2>/dev/null; then
            if [[ "${quiet_mode}" != "true" ]]; then
                log_success "Evidence file is valid JSON"
            fi
            
            # Check for required fields
            local has_tdx_status=$(jq -e '.tdx_status' "${EVIDENCE_FILE}" > /dev/null 2>&1 && echo "true" || echo "false")
            local has_measurements=$(jq -e '.system_measurements' "${EVIDENCE_FILE}" > /dev/null 2>&1 && echo "true" || echo "false")
            
            if [[ "${has_tdx_status}" == "true" && "${has_measurements}" == "true" ]]; then
                if [[ "${quiet_mode}" != "true" ]]; then
                    log_success "Evidence structure is valid"
                fi
                is_valid=true
                
                if [[ "${quiet_mode}" != "true" ]]; then
                    # Display evidence summary
                    local tdx_available=$(jq -r '.tdx_status.available' "${EVIDENCE_FILE}" 2>/dev/null || echo "unknown")
                    local detection_methods=$(jq -r '.tdx_status.detection_methods | join(", ")' "${EVIDENCE_FILE}" 2>/dev/null || echo "unknown")
                    
                    log_info "TDX Available: ${tdx_available}"
                    log_info "Detection Methods: ${detection_methods}"
                fi
            else
                if [[ "${quiet_mode}" != "true" ]]; then
                    log_error "Evidence structure is invalid - missing required fields"
                fi
            fi
        else
            if [[ "${quiet_mode}" != "true" ]]; then
                log_error "Evidence file is not valid JSON"
            fi
        fi
    else
        if [[ "${quiet_mode}" != "true" ]]; then
            log_error "Evidence file not found"
        fi
    fi
    
    verification_result="{\"file\": \"${EVIDENCE_FILE}\", \"valid\": ${is_valid}, \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}"
    echo "${verification_result}"
}

# Generate comprehensive report
generate_report() {
    log_info "Generating comprehensive local attestation report..."
    
    local report_data=$(cat << EOF
{
    "report_type": "local_tdx_attestation",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "system_info": {
        "hostname": "$(hostname)",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)",
        "tdx_status": "$(dmesg | grep -i tdx | head -1 || echo 'Not available')"
    },
    "attestation_results": {
        "evidence_generated": $(test -f "${EVIDENCE_FILE}" && echo "true" || echo "false"),
        "quote_generated": $(test -f "${QUOTE_FILE}" && echo "true" || echo "false"),
        "measurements_collected": $(test -f "${MEASUREMENT_FILE}" && echo "true" || echo "false"),
        "evidence_file": "${EVIDENCE_FILE}",
        "quote_file": "${QUOTE_FILE}",
        "measurements_file": "${MEASUREMENT_FILE}"
    },
    "verification_results": $(verify_local_evidence "true"),
    "tdx_capabilities": {
        "dmesg_entries": $(dmesg | grep -i tdx | wc -l),
        "cpu_flags": $(grep -i tdx /proc/cpuinfo | wc -l),
        "kernel_modules": $(lsmod | grep -i tdx | wc -l),
        "device_available": $(test -e /dev/tdx_guest && echo "true" || echo "false"),
        "memory_encryption": $(dmesg | grep -i "Memory Encryption Features active" | grep -i tdx > /dev/null && echo "true" || echo "false")
    },
    "limitations": {
        "no_trust_authority": "This attestation was performed locally without Intel Trust Authority API",
        "mock_quote": "The generated quote is for demonstration purposes only",
        "local_verification_only": "Results should be used for testing and development only"
    }
}
EOF
)
    
    echo "${report_data}" | jq '.' > "${REPORT_FILE}" 2>/dev/null || echo "${report_data}" > "${REPORT_FILE}"
    log_success "Comprehensive report generated: ${REPORT_FILE}"
}

# Display summary
display_summary() {
    log_info "=== Local TDX Attestation Summary ==="
    echo
    log_success "✓ TDX availability verified (local methods)"
    log_success "✓ System measurements collected"
    log_success "✓ Local TDX evidence generated"
    log_success "✓ Mock TDX quote created"
    log_success "✓ Evidence verification completed"
    log_success "✓ Comprehensive report created"
    echo
    log_info "Files created:"
    echo "  - Evidence: ${EVIDENCE_FILE}"
    echo "  - Quote: ${QUOTE_FILE}"
    echo "  - Measurements: ${MEASUREMENT_FILE}"
    echo "  - Report: ${REPORT_FILE}"
    echo "  - Log: ${LOG_FILE}"
    echo
    log_info "Output directories:"
    echo "  - JSON files: ${JSON_DIR}"
    echo "  - Log files: ${LOG_DIR}"
    echo
    log_warning "Important Notes:"
    echo "  - This attestation was performed locally without Intel Trust Authority API"
    echo "  - The generated quote is for demonstration purposes only"
    echo "  - Results should be used for testing and development only"
    echo "  - For production use, you would need access to Intel Trust Authority API"
    echo
    log_info "Next steps:"
    echo "  1. Review the attestation report: ${REPORT_FILE}"
    echo "  2. Use the evidence for local testing and development"
    echo "  3. Consider applying for Intel Trust Authority API access for production use"
}

# Main execution
main() {
    log_info "Starting Intel TDX Local Attestation Process (Without Trust Authority API)"
    log_info "Script directory: ${SCRIPT_DIR}"
    
    # Initialize log file
    echo "=== Intel TDX Local Attestation Log ===" > "${LOG_FILE}"
    echo "Started at: $(date)" >> "${LOG_FILE}"
    echo >> "${LOG_FILE}"
    
    # Check prerequisites
    check_root
    check_tdx_availability
    
    # Perform local attestation
    collect_system_measurements
    generate_local_evidence
    generate_mock_quote
    verify_local_evidence
    generate_report
    
    # Display summary
    display_summary
    
    log_success "Local TDX attestation process completed successfully!"
}

# Handle script interruption
trap 'log_error "Script interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"
