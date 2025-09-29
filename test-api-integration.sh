#!/bin/bash

# Test Intel Trust Authority API Integration
# This script tests the API integration features

set -euo pipefail

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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.json"

# Test functions
test_config_loading() {
    log_info "Testing configuration loading..."
    
    if [[ -f "${CONFIG_FILE}" ]]; then
        local api_key=$(jq -r '.trustauthority_api_key // ""' "${CONFIG_FILE}" 2>/dev/null || echo "")
        local api_url=$(jq -r '.trustauthority_api_url // ""' "${CONFIG_FILE}" 2>/dev/null || echo "")
        
        if [[ -n "${api_key}" && "${api_key}" != "YOUR_API_KEY_HERE" ]]; then
            log_success "✅ API key found: ${api_key:0:8}...${api_key: -4}"
            log_success "✅ API URL: ${api_url}"
            return 0
        else
            log_warning "⚠️  No valid API key found"
            return 1
        fi
    else
        log_warning "⚠️  No config.json found"
        return 1
    fi
}

test_api_connectivity() {
    log_info "Testing Intel Trust Authority API connectivity..."
    
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log_warning "⚠️  No config.json found - skipping API test"
        return 1
    fi
    
    local api_key=$(jq -r '.trustauthority_api_key // ""' "${CONFIG_FILE}" 2>/dev/null || echo "")
    local api_url=$(jq -r '.trustauthority_api_url // "https://api.trustauthority.intel.com"' "${CONFIG_FILE}" 2>/dev/null || echo "https://api.trustauthority.intel.com")
    
    if [[ -z "${api_key}" || "${api_key}" == "YOUR_API_KEY_HERE" ]]; then
        log_warning "⚠️  No valid API key - skipping API test"
        return 1
    fi
    
    # Test API health endpoint
    local response
    response=$(curl -s -w "%{http_code}" -o /tmp/api_health_test.json \
        -H "Authorization: Bearer ${api_key}" \
        -H "Content-Type: application/json" \
        "${api_url}/v1/health" 2>/dev/null || echo "000")
    
    local http_code="${response: -3}"
    
    if [[ "${http_code}" == "200" ]]; then
        log_success "✅ Intel Trust Authority API is accessible"
        return 0
    else
        log_warning "⚠️  API test failed (HTTP ${http_code})"
        return 1
    fi
}

test_attestation_script() {
    log_info "Testing enhanced attestation script..."
    
    # Check if the script exists and is executable
    if [[ ! -f "${SCRIPT_DIR}/tdx-attestation.sh" ]]; then
        log_error "❌ tdx-attestation.sh not found"
        return 1
    fi
    
    if [[ ! -x "${SCRIPT_DIR}/tdx-attestation.sh" ]]; then
        log_error "❌ tdx-attestation.sh is not executable"
        return 1
    fi
    
    log_success "✅ Enhanced attestation script found and executable"
    
    # Check if the script has the new API functions
    if grep -q "load_config" "${SCRIPT_DIR}/tdx-attestation.sh"; then
        log_success "✅ API integration functions found"
    else
        log_warning "⚠️  API integration functions not found"
        return 1
    fi
    
    return 0
}

test_setup_script() {
    log_info "Testing setup script..."
    
    if [[ ! -f "${SCRIPT_DIR}/setup-trust-authority.sh" ]]; then
        log_error "❌ setup-trust-authority.sh not found"
        return 1
    fi
    
    if [[ ! -x "${SCRIPT_DIR}/setup-trust-authority.sh" ]]; then
        log_error "❌ setup-trust-authority.sh is not executable"
        return 1
    fi
    
    log_success "✅ Setup script found and executable"
    return 0
}

test_verifier_enhancements() {
    log_info "Testing enhanced verifier..."
    
    if [[ ! -f "${SCRIPT_DIR}/tdx-verifier.sh" ]]; then
        log_error "❌ tdx-verifier.sh not found"
        return 1
    fi
    
    # Check if the verifier has the new conclusion functions
    if grep -q "display_conclusions" "${SCRIPT_DIR}/tdx-verifier.sh"; then
        log_success "✅ Enhanced verifier with conclusions found"
    else
        log_warning "⚠️  Enhanced verifier features not found"
        return 1
    fi
    
    return 0
}

# Main test execution
main() {
    log_info "=== Intel Trust Authority API Integration Test ==="
    echo
    
    local tests_passed=0
    local tests_total=0
    
    # Test 1: Configuration loading
    ((tests_total++))
    if test_config_loading; then
        ((tests_passed++))
    fi
    echo
    
    # Test 2: API connectivity
    ((tests_total++))
    if test_api_connectivity; then
        ((tests_passed++))
    fi
    echo
    
    # Test 3: Enhanced attestation script
    ((tests_total++))
    if test_attestation_script; then
        ((tests_passed++))
    fi
    echo
    
    # Test 4: Setup script
    ((tests_total++))
    if test_setup_script; then
        ((tests_passed++))
    fi
    echo
    
    # Test 5: Enhanced verifier
    ((tests_total++))
    if test_verifier_enhancements; then
        ((tests_passed++))
    fi
    echo
    
    # Summary
    log_info "=== Test Results ==="
    log_info "Tests passed: ${tests_passed}/${tests_total}"
    
    if [[ ${tests_passed} -eq ${tests_total} ]]; then
        log_success "🎉 All tests passed! API integration is ready."
        echo
        log_info "Next steps:"
        log_info "1. Run: ./setup-trust-authority.sh (if not done already)"
        log_info "2. Run: sudo ./tdx-attestation.sh"
        log_info "3. Run: ./tdx-verifier.sh --all"
    else
        log_warning "⚠️  Some tests failed. Check the output above."
        echo
        log_info "Troubleshooting:"
        log_info "1. Make sure you have an Intel Trust Authority API key"
        log_info "2. Run: ./setup-trust-authority.sh to configure"
        log_info "3. Check your internet connectivity"
    fi
    
    # Clean up
    rm -f /tmp/api_health_test.json
}

# Run main function
main "$@"
