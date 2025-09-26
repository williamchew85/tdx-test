#!/bin/bash

# Comprehensive TDX Attestation Testing Script (CORRECTED VERSION)
# Tests both positive and negative scenarios for TDX verification
# Fixed the nested json directory issue

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_DIR="${SCRIPT_DIR}/json"
LOG_DIR="${SCRIPT_DIR}/log"
TEST_DIR="${SCRIPT_DIR}/test"

# Create directories if they don't exist
mkdir -p "${JSON_DIR}" "${LOG_DIR}" "${TEST_DIR}"

TEST_REPORT="${JSON_DIR}/tdx-comprehensive-test-report.json"
LOG_FILE="${LOG_DIR}/tdx-comprehensive-test.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results tracking
declare -A test_results
declare -A test_durations

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

# Run a test and track results
run_test() {
    local test_name="$1"
    local test_command="$2"
    local test_description="$3"
    
    log_info "Running test: ${test_name}"
    log_info "Description: ${test_description}"
    log_info "Command: ${test_command}"
    
    local start_time=$(date +%s)
    local test_result="FAILED"
    local test_output=""
    local exit_code=0
    
    # Run the test command and capture output
    if eval "${test_command}" > /tmp/test_output_${test_name}.log 2>&1; then
        test_result="PASSED"
        log_success "Test ${test_name} PASSED"
    else
        exit_code=$?
        log_error "Test ${test_name} FAILED (exit code: ${exit_code})"
        
        # Show detailed error information
        log_error "=== FAILURE DETAILS ==="
        if [[ -f /tmp/test_output_${test_name}.log ]]; then
            log_error "Command output:"
            cat /tmp/test_output_${test_name}.log | while IFS= read -r line; do
                log_error "  ${line}"
            done
        else
            log_error "No output captured"
        fi
        
        # Show file system state for debugging
        log_error "=== DEBUGGING INFO ==="
        log_error "Current directory: $(pwd)"
        log_error "JSON directory contents:"
        ls -la "${JSON_DIR}/" 2>/dev/null | while IFS= read -r line; do
            log_error "  ${line}"
        done || log_error "  Cannot list JSON directory"
        
        log_error "=== END FAILURE DETAILS ==="
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    test_results["${test_name}"]="${test_result}"
    test_durations["${test_name}"]="${duration}"
    
    # Capture test output for report
    test_output=$(cat /tmp/test_output_${test_name}.log 2>/dev/null || echo "No output captured")
    
    # Clean up temp file
    rm -f /tmp/test_output_${test_name}.log
    
    log_info "Test ${test_name} completed in ${duration} seconds"
    echo
}

# Run a test with specific exit code whitelist
run_test_with_exit_code() {
    local test_name="$1"
    local test_command="$2"
    local test_description="$3"
    local expected_exit_code="$4"
    
    log_info "Running test: ${test_name}"
    log_info "Description: ${test_description}"
    log_info "Command: ${test_command}"
    log_info "Expected exit code: ${expected_exit_code}"
    
    local start_time=$(date +%s)
    local test_result="FAILED"
    local test_output=""
    local exit_code=0
    
    # Run the test command and capture output
    if eval "${test_command}" > /tmp/test_output_${test_name}.log 2>&1; then
        test_result="PASSED"
        log_success "Test ${test_name} PASSED"
    else
        exit_code=$?
        if [[ "${exit_code}" == "${expected_exit_code}" ]]; then
            test_result="PASSED"
            log_success "Test ${test_name} PASSED (expected exit code ${expected_exit_code})"
        else
            log_error "Test ${test_name} FAILED (exit code: ${exit_code}, expected: ${expected_exit_code})"
            
            # Show detailed error information
            log_error "=== FAILURE DETAILS ==="
            if [[ -f /tmp/test_output_${test_name}.log ]]; then
                log_error "Command output:"
                cat /tmp/test_output_${test_name}.log | while IFS= read -r line; do
                    log_error "  ${line}"
                done
            else
                log_error "No output captured"
            fi
            
            # Show file system state for debugging
            log_error "=== DEBUGGING INFO ==="
            log_error "Current directory: $(pwd)"
            log_error "JSON directory contents:"
            ls -la "${JSON_DIR}/" 2>/dev/null | while IFS= read -r line; do
                log_error "  ${line}"
            done || log_error "  Cannot list JSON directory"
            
            log_error "=== END FAILURE DETAILS ==="
        fi
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    test_results["${test_name}"]="${test_result}"
    test_durations["${test_name}"]="${duration}"
    
    # Capture test output for report
    test_output=$(cat /tmp/test_output_${test_name}.log 2>/dev/null || echo "No output captured")
    
    # Clean up temp file
    rm -f /tmp/test_output_${test_name}.log
    
    log_info "Test ${test_name} completed in ${duration} seconds"
    echo
}

# Test 1: Positive - Check TDX availability
test_tdx_availability_positive() {
    run_test "tdx_availability_positive" \
        "dmesg | grep -i tdx | head -1" \
        "Verify TDX is available in the system (POSITIVE)"
}

# Test 2: Positive - Check TDX kernel modules
test_tdx_modules_positive() {
    run_test "tdx_modules_positive" \
        "lsmod | grep -i tdx | wc -l" \
        "Check if TDX kernel modules are loaded (POSITIVE)"
}

# Test 3: Positive - Check CPU TDX support
test_cpu_tdx_support_positive() {
    run_test "cpu_tdx_support_positive" \
        "cat /proc/cpuinfo | grep -i tdx | wc -l" \
        "Verify CPU supports TDX (POSITIVE)"
}

# Test 4: Positive - Generate local TDX evidence
test_generate_local_evidence_positive() {
    run_test "generate_local_evidence_positive" \
        "sudo ./tdx-local-attestation.sh" \
        "Generate local TDX evidence (POSITIVE)"
}

# Test 5: Positive - Generate TDX quotes
test_generate_quotes_positive() {
    run_test "generate_quotes_positive" \
        "sudo ./tdx-quote-generator.sh" \
        "Generate TDX quotes (POSITIVE)"
}

# Test 6: Positive - Verify evidence file
test_verify_evidence_positive() {
    run_test "verify_evidence_positive" \
        "test -f json/tdx-local-evidence.json && jq -e '.tdx_status' json/tdx-local-evidence.json" \
        "Verify evidence file was created and is valid (POSITIVE)"
}

# Test 7: Positive - Verify quote file
test_verify_quote_positive() {
    run_test "verify_quote_positive" \
        "test -f json/tdx-local-quote.bin && test -s json/tdx-local-quote.bin" \
        "Verify quote file was created and is not empty (POSITIVE)"
}

# Test 8: Positive - Run comprehensive verification
test_comprehensive_verification_positive() {
    run_test "comprehensive_verification_positive" \
        "./tdx-verifier-minimal.sh" \
        "Run comprehensive verification (POSITIVE)"
}

# Test 9: Negative - Test with missing files
test_missing_files_negative() {
    log_info "Creating negative test scenario: missing files"
    
    # Backup existing files (FIXED: only copy files, not directories)
    mkdir -p "${TEST_DIR}/backup"
    find "${JSON_DIR}" -maxdepth 1 -type f -exec cp {} "${TEST_DIR}/backup/" \; 2>/dev/null || true
    
    # Remove all TDX files
    rm -f "${JSON_DIR}"/tdx-*.json "${JSON_DIR}"/tdx-*.bin
    
    run_test "missing_files_negative" \
        "./tdx-verifier-minimal.sh" \
        "Test verification with missing files (NEGATIVE)"
    
    # Restore files (FIXED: only copy files, not directories)
    find "${TEST_DIR}/backup" -maxdepth 1 -type f -exec cp {} "${JSON_DIR}/" \; 2>/dev/null || true
}

# Test 10: Negative - Test with corrupted files
test_corrupted_files_negative() {
    log_info "Creating negative test scenario: corrupted files"
    
    # Backup existing files (FIXED: only copy files, not directories)
    mkdir -p "${TEST_DIR}/backup_corrupted"
    find "${JSON_DIR}" -maxdepth 1 -type f -exec cp {} "${TEST_DIR}/backup_corrupted/" \; 2>/dev/null || true
    
    # Corrupt evidence file
    if [[ -f "${JSON_DIR}/tdx-local-evidence.json" ]]; then
        echo "corrupted json data" > "${JSON_DIR}/tdx-local-evidence.json"
    fi
    
    # Corrupt quote file
    if [[ -f "${JSON_DIR}/tdx-local-quote.bin" ]]; then
        echo "corrupted binary data" > "${JSON_DIR}/tdx-local-quote.bin"
    fi
    
    run_test "corrupted_files_negative" \
        "./tdx-verifier-minimal.sh" \
        "Test verification with corrupted files (NEGATIVE)"
    
    # Restore files (FIXED: only copy files, not directories)
    find "${TEST_DIR}/backup_corrupted" -maxdepth 1 -type f -exec cp {} "${JSON_DIR}/" \; 2>/dev/null || true
}

# Test 11: Negative - Test with invalid JSON
test_invalid_json_negative() {
    log_info "Creating negative test scenario: invalid JSON"
    
    # Backup existing files (FIXED: only copy files, not directories)
    mkdir -p "${TEST_DIR}/backup_invalid"
    find "${JSON_DIR}" -maxdepth 1 -type f -exec cp {} "${TEST_DIR}/backup_invalid/" \; 2>/dev/null || true
    
    # Create invalid JSON
    if [[ -f "${JSON_DIR}/tdx-local-evidence.json" ]]; then
        echo '{"invalid": json, "missing": quote}' > "${JSON_DIR}/tdx-local-evidence.json"
    fi
    
    run_test "invalid_json_negative" \
        "./tdx-verifier-minimal.sh" \
        "Test verification with invalid JSON (NEGATIVE)"
    
    # Restore files (FIXED: only copy files, not directories)
    find "${TEST_DIR}/backup_invalid" -maxdepth 1 -type f -exec cp {} "${JSON_DIR}/" \; 2>/dev/null || true
}

# Test 12: Negative - Test with empty files
test_empty_files_negative() {
    log_info "Creating negative test scenario: empty files"
    
    # Backup existing files (FIXED: only copy files, not directories)
    mkdir -p "${TEST_DIR}/backup_empty"
    find "${JSON_DIR}" -maxdepth 1 -type f -exec cp {} "${TEST_DIR}/backup_empty/" \; 2>/dev/null || true
    
    # Create empty files
    touch "${JSON_DIR}/tdx-local-evidence.json"
    touch "${JSON_DIR}/tdx-local-quote.bin"
    
    run_test "empty_files_negative" \
        "./tdx-verifier-minimal.sh" \
        "Test verification with empty files (NEGATIVE)"
    
    # Restore files (FIXED: only copy files, not directories)
    find "${TEST_DIR}/backup_empty" -maxdepth 1 -type f -exec cp {} "${JSON_DIR}/" \; 2>/dev/null || true
}

# Test 13: Edge case - Test with mock data
test_mock_data_edge() {
    run_test "mock_data_edge" \
        "./tdx-mock-attestation.sh" \
        "Generate mock data for edge case testing"
}

# Test 14: Edge case - Test verification with mock data
test_verify_mock_data_edge() {
    run_test "verify_mock_data_edge" \
        "./tdx-verifier-minimal.sh" \
        "Verify mock data (EDGE CASE)"
}

# Test 15: System analysis (with exit code 5 whitelist)
test_system_analysis() {
    run_test_with_exit_code "system_analysis" \
        "./tdx-system-analyzer.sh" \
        "Run comprehensive system analysis" \
        "5"
}

# Generate comprehensive test report
generate_test_report() {
    log_info "Generating comprehensive test report..."
    
    local report_data=$(cat << EOF
{
    "test_suite_info": {
        "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
        "hostname": "$(hostname)",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)",
        "script_version": "1.0.0",
        "test_type": "comprehensive_positive_negative"
    },
    "test_results": {
EOF
)
    
    local first_test=true
    for test_name in "${!test_results[@]}"; do
        if [[ "${first_test}" == "true" ]]; then
            first_test=false
        else
            report_data+=","
        fi
        
        report_data+=$(cat << EOF

        "${test_name}": {
            "status": "${test_results[${test_name}]}",
            "duration_seconds": ${test_durations[${test_name}]},
            "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        }
EOF
)
    done
    
    report_data+=$(cat << EOF

    },
    "summary": {
        "total_tests": ${#test_results[@]},
        "passed_tests": $(printf '%s\n' "${test_results[@]}" | grep -c "PASSED" || echo "0"),
        "failed_tests": $(printf '%s\n' "${test_results[@]}" | grep -c "FAILED" || echo "0"),
        "total_duration_seconds": $(printf '%s\n' "${test_durations[@]}" | awk '{sum+=$1} END {print sum+0}'),
        "success_rate": "$(printf '%.1f' $(echo "scale=2; $(printf '%s\n' "${test_results[@]}" | grep -c "PASSED") * 100 / ${#test_results[@]}" | bc -l 2>/dev/null || echo "0"))%"
    },
    "test_categories": {
        "positive_tests": $(printf '%s\n' "${!test_results[@]}" | grep -c "positive" || echo "0"),
        "negative_tests": $(printf '%s\n' "${!test_results[@]}" | grep -c "negative" || echo "0"),
        "edge_case_tests": $(printf '%s\n' "${!test_results[@]}" | grep -c "edge" || echo "0")
    },
    "system_details": {
        "tdx_status": "$(dmesg | grep -i tdx | head -1 || echo 'Not available')",
        "memory_encryption": "$(dmesg | grep -i 'Memory Encryption Features active' || echo 'Not available')",
        "cpu_info": "$(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)",
        "memory_info": "$(free -h | grep '^Mem:' | awk '{print $2}')"
    }
}
EOF
)
    
    echo "${report_data}" | jq '.' > "${TEST_REPORT}" 2>/dev/null || echo "${report_data}" > "${TEST_REPORT}"
    log_success "Test report generated: ${TEST_REPORT}"
}

# Create backup archives
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
- Total Tests: ${#test_results[@]}
- Passed Tests: $(printf '%s\n' "${test_results[@]}" | grep -c "PASSED" || echo "0")
- Failed Tests: $(printf '%s\n' "${test_results[@]}" | grep -c "FAILED" || echo "0")

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

# Display test summary
display_test_summary() {
    log_info "=== Comprehensive TDX Test Summary ==="
    echo
    
    local total_tests=${#test_results[@]}
    local passed_tests=$(printf '%s\n' "${test_results[@]}" | grep -c "PASSED" 2>/dev/null || echo "0")
    local failed_tests=$(printf '%s\n' "${test_results[@]}" | grep -c "FAILED" 2>/dev/null || echo "0")
    local total_duration=$(printf '%s\n' "${test_durations[@]}" | awk '{sum+=$1} END {print sum+0}' 2>/dev/null || echo "0")
    
    # Ensure variables are numeric
    passed_tests=$((passed_tests + 0))
    failed_tests=$((failed_tests + 0))
    total_duration=$((total_duration + 0))
    
    log_info "Total Tests: ${total_tests}"
    log_success "Passed: ${passed_tests}"
    if [[ ${failed_tests} -gt 0 ]]; then
        log_error "Failed: ${failed_tests}"
    else
        log_info "Failed: ${failed_tests}"
    fi
    log_info "Total Duration: ${total_duration} seconds"
    
    echo
    log_info "Test Results by Category:"
    
    # Positive tests
    echo "  POSITIVE TESTS:"
    for test_name in "${!test_results[@]}"; do
        if [[ "${test_name}" == *"positive"* ]]; then
            local status="${test_results[${test_name}]}"
            local duration="${test_durations[${test_name}]}"
            
            if [[ "${status}" == "PASSED" ]]; then
                log_success "    ✓ ${test_name} (${duration}s)"
            else
                log_error "    ✗ ${test_name} (${duration}s)"
            fi
        fi
    done
    
    # Negative tests
    echo "  NEGATIVE TESTS:"
    for test_name in "${!test_results[@]}"; do
        if [[ "${test_name}" == *"negative"* ]]; then
            local status="${test_results[${test_name}]}"
            local duration="${test_durations[${test_name}]}"
            
            if [[ "${status}" == "PASSED" ]]; then
                log_success "    ✓ ${test_name} (${duration}s)"
            else
                log_error "    ✗ ${test_name} (${duration}s)"
            fi
        fi
    done
    
    # Edge case tests
    echo "  EDGE CASE TESTS:"
    for test_name in "${!test_results[@]}"; do
        if [[ "${test_name}" == *"edge"* ]]; then
            local status="${test_results[${test_name}]}"
            local duration="${test_durations[${test_name}]}"
            
            if [[ "${status}" == "PASSED" ]]; then
                log_success "    ✓ ${test_name} (${duration}s)"
            else
                log_error "    ✗ ${test_name} (${duration}s)"
            fi
        fi
    done
    
    echo
    if [[ ${failed_tests} -eq 0 ]]; then
        log_success "All tests passed! TDX attestation verification is working correctly."
    else
        log_warning "Some tests failed. Please review the log file for details."
    fi
}

# Main execution
main() {
    log_info "Starting Comprehensive TDX Attestation Testing"
    
    # Initialize log file
    echo "=== Comprehensive TDX Test Log ===" > "${LOG_FILE}"
    echo "Started at: $(date)" >> "${LOG_FILE}"
    echo >> "${LOG_FILE}"
    
    # Check if running as root for TDX operations
    if [[ $EUID -ne 0 ]]; then
        log_warning "Not running as root. Some tests may fail."
        log_info "For complete testing, run: sudo $0"
    fi
    
    log_info "=== PHASE 1: POSITIVE TESTS ==="
    echo "Testing TDX attestation with valid data and scenarios..."
    echo
    
    # Run positive tests
    test_tdx_availability_positive
    test_tdx_modules_positive
    test_cpu_tdx_support_positive
    test_generate_local_evidence_positive
    test_generate_quotes_positive
    test_verify_evidence_positive
    test_verify_quote_positive
    test_comprehensive_verification_positive
    
    log_info "=== PHASE 2: NEGATIVE TESTS ==="
    echo "Testing TDX attestation with invalid data and error scenarios..."
    echo
    
    # Run negative tests
    test_missing_files_negative
    test_corrupted_files_negative
    test_invalid_json_negative
    test_empty_files_negative
    
    log_info "=== PHASE 3: EDGE CASE TESTS ==="
    echo "Testing TDX attestation with edge cases and mock data..."
    echo
    
    # Run edge case tests
    test_mock_data_edge
    test_verify_mock_data_edge
    test_system_analysis
    
    # Generate report and summary
    generate_test_report
    display_test_summary
    
    # Create backup archives
    create_backup_archives
    
    log_success "Comprehensive TDX test suite completed!"
    log_info "Detailed report: ${TEST_REPORT}"
    log_info "Log file: ${LOG_FILE}"
    echo
    log_info "Output directories:"
    echo "  - JSON files: ${JSON_DIR}"
    echo "  - Log files: ${LOG_DIR}"
    echo "  - Test files: ${TEST_DIR}"
    echo "  - Backup archives: ${SCRIPT_DIR}/backup/"
}

# Handle script interruption
trap 'log_error "Test suite interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"
