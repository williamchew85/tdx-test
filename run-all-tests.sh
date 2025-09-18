#!/bin/bash

# Complete TDX Testing Suite
# This script runs all TDX attestation tests and generates a comprehensive report

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_DIR="${SCRIPT_DIR}/json"
LOG_DIR="${SCRIPT_DIR}/log"

# Create directories if they don't exist
mkdir -p "${JSON_DIR}" "${LOG_DIR}"

TEST_REPORT="${JSON_DIR}/tdx-test-suite-report.json"
LOG_FILE="${LOG_DIR}/tdx-test-suite.log"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

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
    
    local start_time=$(date +%s)
    local test_result="FAILED"
    local test_output=""
    
    if eval "${test_command}" > /tmp/test_output_${test_name}.log 2>&1; then
        test_result="PASSED"
        log_success "Test ${test_name} PASSED"
    else
        log_error "Test ${test_name} FAILED"
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    test_results["${test_name}"]="${test_result}"
    test_durations["${test_name}"]="${duration}"
    
    # Capture test output
    test_output=$(cat /tmp/test_output_${test_name}.log 2>/dev/null || echo "No output captured")
    
    # Clean up temp file
    rm -f /tmp/test_output_${test_name}.log
    
    log_info "Test ${test_name} completed in ${duration} seconds"
    echo
}

# Test 1: Check TDX availability
test_tdx_availability() {
    run_test "tdx_availability" \
        "dmesg | grep -i tdx | head -1" \
        "Verify TDX is available in the system"
}

# Test 2: Check TDX kernel modules
test_tdx_modules() {
    run_test "tdx_modules" \
        "lsmod | grep -i tdx | wc -l" \
        "Check if TDX kernel modules are loaded"
}

# Test 3: Check CPU TDX support
test_cpu_tdx_support() {
    run_test "cpu_tdx_support" \
        "cat /proc/cpuinfo | grep -i tdx | wc -l" \
        "Verify CPU supports TDX"
}

# Test 4: Check Go installation
test_go_installation() {
    run_test "go_installation" \
        "go version | grep -o 'go[0-9.]*'" \
        "Verify Go is installed and get version"
}

# Test 5: Check Intel Trust Authority CLI
test_trustauthority_cli() {
    run_test "trustauthority_cli" \
        "trustauthority-cli version" \
        "Verify Intel Trust Authority CLI is installed"
}

# Test 6: Check configuration file
test_config_file() {
    run_test "config_file" \
        "test -f config.json && jq -e '.trustauthority_api_key' config.json" \
        "Verify configuration file exists and has API key"
}

# Test 7: Generate TDX evidence
test_generate_evidence() {
    run_test "generate_evidence" \
        "sudo trustauthority-cli evidence --tdx -c config.json" \
        "Generate TDX evidence using Intel Trust Authority CLI"
}

# Test 8: Generate attestation token
test_generate_token() {
    run_test "generate_token" \
        "sudo trustauthority-cli token -c config.json" \
        "Generate attestation token"
}

# Test 9: Verify evidence file
test_verify_evidence() {
    run_test "verify_evidence" \
        "test -f tdx-evidence.json && jq -e '.evidence' tdx-evidence.json" \
        "Verify evidence file was created and is valid JSON"
}

# Test 10: Verify token file
test_verify_token() {
    run_test "verify_token" \
        "test -f tdx-token.json && jq -e '.token' tdx-token.json" \
        "Verify token file was created and is valid JSON"
}

# Test 11: System information collection
test_system_info() {
    run_test "system_info" \
        "uname -a && lscpu | head -5" \
        "Collect basic system information"
}

# Test 12: Memory encryption status
test_memory_encryption() {
    run_test "memory_encryption" \
        "dmesg | grep -i 'Memory Encryption Features active'" \
        "Check memory encryption features status"
}

# Generate comprehensive test report
generate_test_report() {
    log_info "Generating comprehensive test report..."
    
    local report_data=$(cat << EOF
{
    "test_suite_info": {
        "timestamp": "${TIMESTAMP}",
        "hostname": "$(hostname)",
        "kernel": "$(uname -r)",
        "architecture": "$(uname -m)",
        "script_version": "1.0.0"
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
            "timestamp": "${TIMESTAMP}"
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
    "system_details": {
        "tdx_status": "$(dmesg | grep -i tdx | head -1 || echo 'Not available')",
        "memory_encryption": "$(dmesg | grep -i 'Memory Encryption Features active' || echo 'Not available')",
        "go_version": "$(go version 2>/dev/null || echo 'Not installed')",
        "trustauthority_cli_version": "$(trustauthority-cli version 2>/dev/null || echo 'Not installed')",
        "cpu_info": "$(lscpu | grep 'Model name' | cut -d':' -f2 | xargs)",
        "memory_info": "$(free -h | grep '^Mem:' | awk '{print $2}')"
    }
}
EOF
)
    
    echo "${report_data}" | jq '.' > "${TEST_REPORT}" 2>/dev/null || echo "${report_data}" > "${TEST_REPORT}"
    log_success "Test report generated: ${TEST_REPORT}"
}

# Display test summary
display_test_summary() {
    log_info "=== Test Suite Summary ==="
    echo
    
    local total_tests=${#test_results[@]}
    local passed_tests=$(printf '%s\n' "${test_results[@]}" | grep -c "PASSED" || echo "0")
    local failed_tests=$(printf '%s\n' "${test_results[@]}" | grep -c "FAILED" || echo "0")
    local total_duration=$(printf '%s\n' "${test_durations[@]}" | awk '{sum+=$1} END {print sum+0}')
    
    log_info "Total Tests: ${total_tests}"
    log_success "Passed: ${passed_tests}"
    if [[ ${failed_tests} -gt 0 ]]; then
        log_error "Failed: ${failed_tests}"
    else
        log_info "Failed: ${failed_tests}"
    fi
    log_info "Total Duration: ${total_duration} seconds"
    
    echo
    log_info "Test Results:"
    for test_name in "${!test_results[@]}"; do
        local status="${test_results[${test_name}]}"
        local duration="${test_durations[${test_name}]}"
        
        if [[ "${status}" == "PASSED" ]]; then
            log_success "  ✓ ${test_name} (${duration}s)"
        else
            log_error "  ✗ ${test_name} (${duration}s)"
        fi
    done
    
    echo
    if [[ ${failed_tests} -eq 0 ]]; then
        log_success "All tests passed! TDX attestation is working correctly."
    else
        log_warning "Some tests failed. Please review the log file for details."
    fi
}

# Main execution
main() {
    log_info "Starting TDX Test Suite"
    
    # Initialize log file
    echo "=== TDX Test Suite Log ===" > "${LOG_FILE}"
    echo "Started at: $(date)" >> "${LOG_FILE}"
    echo >> "${LOG_FILE}"
    
    # Check if running as root for TDX operations
    if [[ $EUID -ne 0 ]]; then
        log_warning "Not running as root. Some tests may fail."
        log_info "For complete testing, run: sudo $0"
    fi
    
    # Run all tests
    test_tdx_availability
    test_tdx_modules
    test_cpu_tdx_support
    test_go_installation
    test_trustauthority_cli
    test_config_file
    test_generate_evidence
    test_generate_token
    test_verify_evidence
    test_verify_token
    test_system_info
    test_memory_encryption
    
    # Generate report and summary
    generate_test_report
    display_test_summary
    
    log_success "TDX test suite completed!"
    log_info "Detailed report: ${TEST_REPORT}"
    log_info "Log file: ${LOG_FILE}"
    echo
    log_info "Output directories:"
    echo "  - JSON files: ${JSON_DIR}"
    echo "  - Log files: ${LOG_DIR}"
}

# Handle script interruption
trap 'log_error "Test suite interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"
