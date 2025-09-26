#!/bin/bash

# TDX System Analyzer Script
# This script performs deep analysis of TDX capabilities without requiring Trust Authority API

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_DIR="${SCRIPT_DIR}/json"
LOG_DIR="${SCRIPT_DIR}/log"

# Create directories if they don't exist
mkdir -p "${JSON_DIR}" "${LOG_DIR}"

ANALYSIS_REPORT="${JSON_DIR}/tdx-system-analysis.json"
LOG_FILE="${LOG_DIR}/tdx-system-analyzer.log"

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

# Analyze CPU capabilities
analyze_cpu_capabilities() {
    log_info "Analyzing CPU capabilities..."
    
    local cpu_info=$(cat << EOF
{
    "cpu_model": "$(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)",
    "cpu_cores": $(nproc),
    "cpu_flags": {
        "tdx": $(grep -i tdx /proc/cpuinfo | wc -l),
        "sme": $(grep -i sme /proc/cpuinfo | wc -l),
        "sev": $(grep -i sev /proc/cpuinfo | wc -l),
        "sse": $(grep -i sse /proc/cpuinfo | wc -l),
        "avx": $(grep -i avx /proc/cpuinfo | wc -l)
    },
    "tdx_flags_detail": [
$(grep -i tdx /proc/cpuinfo | while read line; do
    if [[ -n "${line}" ]]; then
        echo "        \"${line}\","
    fi
done | sed '$ s/,$//')
    ]
}
EOF
)
    
    echo "${cpu_info}"
}

# Analyze kernel modules
analyze_kernel_modules() {
    log_info "Analyzing kernel modules..."
    
    local modules_info=$(cat << EOF
{
    "tdx_modules": [
$(lsmod | grep -i tdx | while read line; do
    if [[ -n "${line}" ]]; then
        echo "        \"${line}\","
    fi
done | sed '$ s/,$//')
    ],
    "security_modules": [
$(lsmod | grep -E -i "(tdx|sme|sev|tpm)" | while read line; do
    if [[ -n "${line}" ]]; then
        echo "        \"${line}\","
    fi
done | sed '$ s/,$//')
    ],
    "module_count": {
        "tdx": $(lsmod | grep -i tdx | wc -l),
        "security": $(lsmod | grep -E -i "(tdx|sme|sev|tpm)" | wc -l)
    }
}
EOF
)
    
    echo "${modules_info}"
}

# Analyze memory encryption
analyze_memory_encryption() {
    log_info "Analyzing memory encryption features..."
    
    local memory_info=$(cat << EOF
{
    "memory_encryption_status": "$(dmesg | grep -i 'Memory Encryption Features active' || echo 'Not found')",
    "tdx_memory_encryption": $(dmesg | grep -i "Memory Encryption Features active" | grep -i tdx > /dev/null && echo "true" || echo "false"),
    "sme_memory_encryption": $(dmesg | grep -i "Memory Encryption Features active" | grep -i sme > /dev/null && echo "true" || echo "false"),
    "memory_info": {
        "total": "$(free -h | grep '^Mem:' | awk '{print $2}')",
        "available": "$(free -h | grep '^Mem:' | awk '{print $7}')",
        "used": "$(free -h | grep '^Mem:' | awk '{print $3}')"
    },
    "dmesg_memory_entries": [
$(dmesg | grep -i -E "(memory|encryption|tdx|sme)" | head -10 | while read line; do
    if [[ -n "${line}" ]]; then
        echo "        \"${line}\","
    fi
done | sed '$ s/,$//')
    ]
}
EOF
)
    
    echo "${memory_info}"
}

# Analyze TDX-specific information
analyze_tdx_specific() {
    log_info "Analyzing TDX-specific information..."
    
    local tdx_info=$(cat << EOF
{
    "tdx_dmesg_entries": [
$(dmesg | grep -i tdx | while read line; do
    if [[ -n "${line}" ]]; then
        echo "        \"${line}\","
    fi
done | sed '$ s/,$//')
    ],
    "tdx_device": {
        "exists": $(test -e /dev/tdx_guest && echo "true" || echo "false"),
        "permissions": "$(ls -la /dev/tdx_guest 2>/dev/null || echo 'Device not found')"
    },
    "tdx_sysfs": {
        "available": $(test -d /sys/firmware/tdx_seam && echo "true" || echo "false"),
        "entries": [
$(find /sys -name "*tdx*" 2>/dev/null | head -10 | while read line; do
    if [[ -n "${line}" ]]; then
        echo "            \"${line}\","
    fi
done | sed '$ s/,$//')
        ]
    },
    "tdx_procfs": {
        "cpuinfo_entries": $(grep -i tdx /proc/cpuinfo | wc -l),
        "meminfo_entries": $(grep -i tdx /proc/meminfo | wc -l)
    }
}
EOF
)
    
    echo "${tdx_info}"
}

# Analyze security features
analyze_security_features() {
    log_info "Analyzing security features..."
    
    local security_info=$(cat << EOF
{
    "secure_boot": {
        "status": "$(mokutil --sb-state 2>/dev/null | grep -i "SecureBoot" || echo 'Unknown')",
        "enabled": $(mokutil --sb-state 2>/dev/null | grep -i "SecureBoot enabled" > /dev/null && echo "true" || echo "false")
    },
    "tpm": {
        "available": $(test -c /dev/tpm0 && echo "true" || echo "false"),
        "version": "$(cat /sys/class/tpm/tpm0/device/description 2>/dev/null || echo 'Not available')"
    },
    "ima": {
        "enabled": $(test -f /sys/kernel/security/ima/policy && echo "true" || echo "false"),
        "measurements": $(test -f /sys/kernel/security/ima/ascii_runtime_measurements && echo "true" || echo "false")
    },
    "apparmor": {
        "enabled": $(test -d /sys/kernel/security/apparmor && echo "true" || echo "false")
    },
    "selinux": {
        "enabled": $(test -f /sys/fs/selinux/enforce && echo "true" || echo "false")
    }
}
EOF
)
    
    echo "${security_info}"
}

# Analyze virtualization capabilities
analyze_virtualization() {
    log_info "Analyzing virtualization capabilities..."
    
    local virt_info=$(cat << EOF
{
    "virtualization_type": "$(systemd-detect-virt 2>/dev/null || echo 'bare_metal')",
    "hypervisor": "$(cat /sys/hypervisor/type 2>/dev/null || echo 'unknown')",
    "vmx_svm": {
        "vmx": $(grep -i vmx /proc/cpuinfo | wc -l),
        "svm": $(grep -i svm /proc/cpuinfo | wc -l)
    },
    "nested_virtualization": {
        "enabled": $(test -f /sys/module/kvm_intel/parameters/nested && echo "true" || echo "false"),
        "value": "$(cat /sys/module/kvm_intel/parameters/nested 2>/dev/null || echo 'Not available')"
    },
    "kvm": {
        "available": $(test -c /dev/kvm && echo "true" || echo "false"),
        "permissions": "$(ls -la /dev/kvm 2>/dev/null || echo 'Device not found')"
    }
}
EOF
)
    
    echo "${virt_info}"
}

# Generate comprehensive analysis report
generate_analysis_report() {
    log_info "Generating comprehensive system analysis report..."
    
    local analysis_data=$(cat << EOF
{
    "analysis_metadata": {
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
        "hostname": "$(hostname)",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)",
        "analyzer_version": "1.0.0"
    },
    "system_overview": {
        "os": "$(lsb_release -d 2>/dev/null | cut -d':' -f2 | xargs || echo 'Unknown')",
        "uptime": "$(uptime -p 2>/dev/null || uptime | cut -d',' -f1 | cut -d' ' -f4- 2>/dev/null || echo 'unknown')",
        "boot_time": "$(uptime -s 2>/dev/null || date -r $(sysctl -n kern.boottime | cut -d',' -f1 | cut -d' ' -f4) 2>/dev/null || echo 'unknown')"
    },
    "cpu_analysis": $(analyze_cpu_capabilities),
    "kernel_modules": $(analyze_kernel_modules),
    "memory_encryption": $(analyze_memory_encryption),
    "tdx_analysis": $(analyze_tdx_specific),
    "security_features": $(analyze_security_features),
    "virtualization": $(analyze_virtualization),
    "tdx_readiness_assessment": {
        "cpu_support": $(grep -i tdx /proc/cpuinfo | wc -l),
        "kernel_support": $(lsmod | grep -i tdx | wc -l),
        "memory_encryption": $(dmesg | grep -i "Memory Encryption Features active" | grep -i tdx > /dev/null && echo "true" || echo "false"),
        "device_available": $(test -e /dev/tdx_guest && echo "true" || echo "false"),
        "overall_readiness": "$(if [[ $(grep -i tdx /proc/cpuinfo | wc -l) -gt 0 && $(lsmod | grep -i tdx | wc -l) -gt 0 ]]; then echo 'READY'; else echo 'NOT_READY'; fi)"
    },
    "recommendations": [
        $(if [[ $(grep -i tdx /proc/cpuinfo | wc -l) -eq 0 ]]; then echo '"CPU does not support TDX - consider using TDX-capable hardware"'; fi),
        $(if [[ $(lsmod | grep -i tdx | wc -l) -eq 0 ]]; then echo '"TDX kernel modules not loaded - check kernel configuration"'; fi),
        $(if [[ ! -e /dev/tdx_guest ]]; then echo '"TDX guest device not available - check TDX initialization"'; fi),
        $(if ! dmesg | grep -i "Memory Encryption Features active" | grep -i tdx > /dev/null; then echo '"TDX memory encryption not active - check BIOS/UEFI settings"'; fi),
        "Consider applying for Intel Trust Authority API access for production attestation",
        "Use local attestation methods for testing and development purposes"
    ]
}
EOF
)
    
    echo "${analysis_data}" | jq '.' > "${ANALYSIS_REPORT}" 2>/dev/null || echo "${analysis_data}" > "${ANALYSIS_REPORT}"
    log_success "System analysis report generated: ${ANALYSIS_REPORT}"
}

# Display analysis summary
display_analysis_summary() {
    log_info "=== TDX System Analysis Summary ==="
    echo
    
    if [[ -f "${ANALYSIS_REPORT}" ]]; then
        # Get values directly from system instead of JSON parsing
        local cpu_support=$(grep -i tdx /proc/cpuinfo | wc -l)
        local kernel_support=$(lsmod | grep -i tdx | wc -l)
        local memory_encryption=$(dmesg | grep -i "Memory Encryption Features active" | grep -i tdx > /dev/null && echo "true" || echo "false")
        local device_available=$(test -e /dev/tdx_guest && echo "true" || echo "false")
        
        # Determine readiness based on actual values
        local readiness="UNKNOWN"
        if [[ ${cpu_support} -gt 0 && ${kernel_support} -gt 0 && "${device_available}" == "true" ]]; then
            readiness="READY"
        elif [[ ${cpu_support} -gt 0 || ${kernel_support} -gt 0 ]]; then
            readiness="PARTIAL"
        else
            readiness="NOT_READY"
        fi
        
        log_info "TDX Readiness Assessment: ${readiness}"
        echo
        log_info "CPU Support: ${cpu_support} cores with TDX flags"
        log_info "Kernel Support: ${kernel_support} TDX modules loaded"
        log_info "Memory Encryption: ${memory_encryption}"
        log_info "TDX Device: ${device_available}"
        
        echo
        log_info "Recommendations:"
        jq -r '.recommendations[]' "${ANALYSIS_REPORT}" 2>/dev/null | while read recommendation; do
            if [[ -n "${recommendation}" ]]; then
                log_warning "  - ${recommendation}"
            fi
        done
    else
        log_error "Analysis report not found"
    fi
}

# Main execution
main() {
    log_info "Starting TDX System Analysis"
    
    # Initialize log file
    echo "=== TDX System Analyzer Log ===" > "${LOG_FILE}"
    echo "Started at: $(date)" >> "${LOG_FILE}"
    echo >> "${LOG_FILE}"
    
    # Perform analysis
    generate_analysis_report
    display_analysis_summary
    
    log_success "TDX system analysis completed!"
    log_info "Detailed report: ${ANALYSIS_REPORT}"
    log_info "Log file: ${LOG_FILE}"
    echo
    log_info "Output directories:"
    echo "  - JSON files: ${JSON_DIR}"
    echo "  - Log files: ${LOG_DIR}"
}

# Handle script interruption
trap 'log_error "Analysis interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"
