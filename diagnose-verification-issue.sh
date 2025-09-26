#!/bin/bash

# Diagnostic script to identify verification issues
# This script tests each verification component individually

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_DIR="${SCRIPT_DIR}/json"

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

# Test individual verification components
test_evidence_verification() {
    log_info "Testing evidence verification..."
    
    if [[ -f "${JSON_DIR}/tdx-local-evidence.json" ]]; then
        log_info "Evidence file exists: ${JSON_DIR}/tdx-local-evidence.json"
        
        # Test JSON validity
        if jq empty "${JSON_DIR}/tdx-local-evidence.json" 2>/dev/null; then
            log_success "Evidence file is valid JSON"
        else
            log_error "Evidence file is not valid JSON"
            return 1
        fi
        
        # Test structure
        local has_tdx_status=$(jq -e '.tdx_status' "${JSON_DIR}/tdx-local-evidence.json" > /dev/null 2>&1 && echo "true" || echo "false")
        if [[ "${has_tdx_status}" == "true" ]]; then
            log_success "Evidence has tdx_status field"
        else
            log_error "Evidence missing tdx_status field"
            return 1
        fi
        
        # Test TDX availability
        local tdx_available=$(jq -r '.tdx_status.available' "${JSON_DIR}/tdx-local-evidence.json" 2>/dev/null || echo "unknown")
        log_info "TDX Available: ${tdx_available}"
        
        return 0
    else
        log_error "Evidence file not found: ${JSON_DIR}/tdx-local-evidence.json"
        return 1
    fi
}

test_quote_verification() {
    log_info "Testing quote verification..."
    
    if [[ -f "${JSON_DIR}/tdx-local-quote.bin" ]]; then
        log_info "Quote file exists: ${JSON_DIR}/tdx-local-quote.bin"
        
        local file_size=$(stat -c%s "${JSON_DIR}/tdx-local-quote.bin" 2>/dev/null || echo "0")
        log_info "Quote file size: ${file_size} bytes"
        
        if [[ ${file_size} -gt 0 ]]; then
            log_success "Quote file is not empty"
            return 0
        else
            log_error "Quote file is empty"
            return 1
        fi
    else
        log_error "Quote file not found: ${JSON_DIR}/tdx-local-quote.bin"
        return 1
    fi
}

test_mock_verification() {
    log_info "Testing mock verification..."
    
    local mock_files=(
        "${JSON_DIR}/tdx-mock-evidence.json"
        "${JSON_DIR}/tdx-mock-token.json"
        "${JSON_DIR}/tdx-mock-quote.bin"
    )
    
    local mock_count=0
    for mock_file in "${mock_files[@]}"; do
        if [[ -f "${mock_file}" ]]; then
            log_success "Mock file exists: $(basename "${mock_file}")"
            ((mock_count++))
        else
            log_warning "Mock file not found: $(basename "${mock_file}")"
        fi
    done
    
    log_info "Found ${mock_count}/${#mock_files[@]} mock files"
    return 0
}

test_verifier_components() {
    log_info "Testing verifier components..."
    
    # Test evidence verification
    if test_evidence_verification; then
        log_success "Evidence verification passed"
    else
        log_error "Evidence verification failed"
        return 1
    fi
    
    # Test quote verification
    if test_quote_verification; then
        log_success "Quote verification passed"
    else
        log_error "Quote verification failed"
        return 1
    fi
    
    # Test mock verification
    if test_mock_verification; then
        log_success "Mock verification passed"
    else
        log_error "Mock verification failed"
        return 1
    fi
    
    return 0
}

test_verifier_hanging() {
    log_info "Testing verifier hanging issue..."
    
    # Test individual verifier calls
    log_info "Testing evidence verification with timeout..."
    if timeout 10 ./tdx-verifier-improved.sh --evidence json/tdx-local-evidence.json > /tmp/evidence_test.log 2>&1; then
        log_success "Evidence verification completed successfully"
    else
        log_error "Evidence verification failed or timed out"
        log_info "Evidence verification output:"
        cat /tmp/evidence_test.log
        return 1
    fi
    
    # Test quote verification
    log_info "Testing quote verification with timeout..."
    if timeout 10 ./tdx-verifier-improved.sh --quote json/tdx-local-quote.bin > /tmp/quote_test.log 2>&1; then
        log_success "Quote verification completed successfully"
    else
        log_error "Quote verification failed or timed out"
        log_info "Quote verification output:"
        cat /tmp/quote_test.log
        return 1
    fi
    
    # Test comprehensive verification with timeout
    log_info "Testing comprehensive verification with timeout..."
    if timeout 15 ./tdx-verifier-improved.sh --all > /tmp/comprehensive_test.log 2>&1; then
        log_success "Comprehensive verification completed successfully"
    else
        log_error "Comprehensive verification failed or timed out"
        log_info "Comprehensive verification output:"
        cat /tmp/comprehensive_test.log
        return 1
    fi
    
    return 0
}

# Main execution
main() {
    log_info "Starting TDX Verification Diagnostic"
    echo
    
    # Test individual components
    log_info "=== Testing Individual Components ==="
    test_verifier_components
    echo
    
    # Test verifier hanging issue
    log_info "=== Testing Verifier Hanging Issue ==="
    if test_verifier_hanging; then
        log_success "All verifier tests passed!"
    else
        log_error "Some verifier tests failed!"
    fi
    
    echo
    log_info "=== Diagnostic Summary ==="
    log_info "Check the test logs in /tmp/ for detailed output"
    log_info "Files tested:"
    echo "  - Evidence: ${JSON_DIR}/tdx-local-evidence.json"
    echo "  - Quote: ${JSON_DIR}/tdx-local-quote.bin"
    echo "  - Mock files: ${JSON_DIR}/tdx-mock-*"
}

# Run main function
main "$@"
