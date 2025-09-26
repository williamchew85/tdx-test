#!/bin/bash

# Test script to demonstrate the backup functionality
# This creates some sample files and tests the backup archive creation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_DIR="${SCRIPT_DIR}/json"
LOG_DIR="${SCRIPT_DIR}/log"
TEST_DIR="${SCRIPT_DIR}/test"

# Create directories if they don't exist
mkdir -p "${JSON_DIR}" "${LOG_DIR}" "${TEST_DIR}"

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
    echo -e "${timestamp} [${level}] ${message}"
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

# Create sample files for testing
create_sample_files() {
    log_info "Creating sample files for backup testing..."
    
    # Create sample JSON files
    echo '{"test": "sample_json_file", "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' > "${JSON_DIR}/sample_evidence.json"
    echo '{"test": "sample_quote", "data": "binary_data_here"}' > "${JSON_DIR}/sample_quote.bin"
    echo '{"test": "sample_token", "jwt": "mock.jwt.token"}' > "${JSON_DIR}/sample_token.json"
    
    # Create sample log files
    echo "Sample log entry 1" > "${LOG_DIR}/sample_test.log"
    echo "Sample log entry 2" >> "${LOG_DIR}/sample_test.log"
    echo "TDX test completed at $(date)" >> "${LOG_DIR}/sample_test.log"
    
    log_success "Sample files created"
}

# Create backup archives (copied from the main script)
create_backup_archives() {
    log_info "Creating backup archives..."
    
    # Create backup directory at same level as json and log folders
    local backup_dir="${SCRIPT_DIR}/backup"
    mkdir -p "${backup_dir}"
    
    # Create timestamp for unique filenames
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local hostname_short=$(hostname | cut -d'.' -f1)
    
    # Create JSON archive
    if [[ -d "${JSON_DIR}" && $(ls -A "${JSON_DIR}" 2>/dev/null) ]]; then
        log_info "Archiving JSON files..."
        local json_archive="${backup_dir}/tdx_json_${hostname_short}_${timestamp}.zip"
        
        if command -v zip >/dev/null 2>&1; then
            cd "${JSON_DIR}"
            zip -r "${json_archive}" . >/dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                log_success "JSON archive created: ${json_archive}"
            else
                log_error "Failed to create JSON archive"
            fi
            cd "${SCRIPT_DIR}"
        else
            log_warning "zip command not found, creating tar archive instead"
            local json_archive="${backup_dir}/tdx_json_${hostname_short}_${timestamp}.tar.gz"
            tar -czf "${json_archive}" -C "${JSON_DIR}" . 2>/dev/null
            if [[ $? -eq 0 ]]; then
                log_success "JSON archive created: ${json_archive}"
            else
                log_error "Failed to create JSON archive"
            fi
        fi
    else
        log_warning "No JSON files found to archive"
    fi
    
    # Create logs archive
    if [[ -d "${LOG_DIR}" && $(ls -A "${LOG_DIR}" 2>/dev/null) ]]; then
        log_info "Archiving log files..."
        local logs_archive="${backup_dir}/tdx_logs_${hostname_short}_${timestamp}.zip"
        
        if command -v zip >/dev/null 2>&1; then
            cd "${LOG_DIR}"
            zip -r "${logs_archive}" . >/dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                log_success "Logs archive created: ${logs_archive}"
            else
                log_error "Failed to create logs archive"
            fi
            cd "${SCRIPT_DIR}"
        else
            log_warning "zip command not found, creating tar archive instead"
            local logs_archive="${backup_dir}/tdx_logs_${hostname_short}_${timestamp}.tar.gz"
            tar -czf "${logs_archive}" -C "${LOG_DIR}" . 2>/dev/null
            if [[ $? -eq 0 ]]; then
                log_success "Logs archive created: ${logs_archive}"
            else
                log_error "Failed to create logs archive"
            fi
        fi
    else
        log_warning "No log files found to archive"
    fi
    
    # Create comprehensive backup info file
    local backup_info="${backup_dir}/tdx_backup_info_${hostname_short}_${timestamp}.txt"
    cat > "${backup_info}" << EOF
TDX Test Suite Backup Information
================================

Timestamp: $(date)
Hostname: $(hostname)
Kernel: $(uname -r)
Architecture: $(uname -m)
Script Version: 1.0.0

Test Results Summary:
- This is a test backup demonstration
- Sample files were created for testing

Archives Created:
- JSON Archive: $(basename "${json_archive:-N/A}")
- Logs Archive: $(basename "${logs_archive:-N/A}")

TDX Status:
$(dmesg | grep -i tdx | head -3 || echo "No TDX information available")

System Information:
- CPU: $(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)
- Memory: $(free -h | grep '^Mem:' | awk '{print $2}')
- Uptime: $(uptime -p 2>/dev/null || uptime | cut -d',' -f1 | cut -d' ' -f4-)

Files in JSON directory:
$(ls -la "${JSON_DIR}" 2>/dev/null || echo "No JSON directory found")

Files in LOG directory:
$(ls -la "${LOG_DIR}" 2>/dev/null || echo "No LOG directory found")
EOF
    
    log_success "Backup info file created: ${backup_info}"
    
    # Display backup summary
    echo
    log_info "=== Backup Archives Created ==="
    echo "Backup directory: ${backup_dir}"
    echo "JSON archive: $(basename "${json_archive:-N/A}")"
    echo "Logs archive: $(basename "${logs_archive:-N/A}")"
    echo "Backup info: $(basename "${backup_info}")"
    echo
    
    # Show archive sizes
    if [[ -f "${json_archive:-}" ]]; then
        local json_size=$(du -h "${json_archive}" | cut -f1)
        log_info "JSON archive size: ${json_size}"
    fi
    
    if [[ -f "${logs_archive:-}" ]]; then
        local logs_size=$(du -h "${logs_archive}" | cut -f1)
        log_info "Logs archive size: ${logs_size}"
    fi
    
    log_success "Backup archives created successfully!"
    log_info "You can use these archives for future analysis"
}

# Main execution
main() {
    log_info "Testing backup functionality..."
    
    # Create sample files
    create_sample_files
    
    # Test backup creation
    create_backup_archives
    
    log_success "Backup test completed!"
}

# Run main function
main "$@"
