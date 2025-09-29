#!/bin/bash

# Intel Trust Authority API Setup Script
# This script helps configure the Intel Trust Authority API key

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
CONFIG_TEMPLATE="${SCRIPT_DIR}/config.json.template"

# Check if config.json exists
if [[ -f "${CONFIG_FILE}" ]]; then
    log_info "Found existing config.json"
    
    # Check if API key is already configured
    local existing_key=$(jq -r '.trustauthority_api_key // ""' "${CONFIG_FILE}" 2>/dev/null || echo "")
    
    if [[ -n "${existing_key}" && "${existing_key}" != "YOUR_API_KEY_HERE" ]]; then
        log_success "Intel Trust Authority API key is already configured"
        log_info "Current API URL: $(jq -r '.trustauthority_api_url // "https://api.trustauthority.intel.com"' "${CONFIG_FILE}")"
        
        read -p "Do you want to update the API key? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Keeping existing configuration"
            exit 0
        fi
    fi
else
    log_info "No config.json found, creating from template"
    
    if [[ -f "${CONFIG_TEMPLATE}" ]]; then
        cp "${CONFIG_TEMPLATE}" "${CONFIG_FILE}"
        log_success "Created config.json from template"
    else
        log_error "Template file not found: ${CONFIG_TEMPLATE}"
        exit 1
    fi
fi

# Get API key from user
echo
log_info "=== Intel Trust Authority API Configuration ==="
echo
log_info "Please provide your Intel Trust Authority API key:"
log_warning "The API key will be stored in config.json (keep this file secure!)"
echo

read -p "Enter your Intel Trust Authority API key: " -s api_key
echo

if [[ -z "${api_key}" ]]; then
    log_error "No API key provided"
    exit 1
fi

# Get API URL (optional)
echo
log_info "Intel Trust Authority API URL (press Enter for default):"
read -p "API URL [https://api.trustauthority.intel.com]: " api_url
api_url="${api_url:-https://api.trustauthority.intel.com}"

# Update config.json
log_info "Updating config.json with your API key..."

# Create updated config
jq --arg api_key "${api_key}" --arg api_url "${api_url}" \
    '.trustauthority_api_key = $api_key | .trustauthority_api_url = $api_url' \
    "${CONFIG_FILE}" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "${CONFIG_FILE}"

log_success "Configuration updated successfully!"

# Test API connectivity
echo
log_info "Testing API connectivity..."

# Test API call
local response
response=$(curl -s -w "%{http_code}" -o /tmp/api_test.json \
    -H "Authorization: Bearer ${api_key}" \
    -H "Content-Type: application/json" \
    "${api_url}/v1/health" 2>/dev/null || echo "000")

local http_code="${response: -3}"

if [[ "${http_code}" == "200" ]]; then
    log_success "✅ Intel Trust Authority API is accessible!"
    log_info "Your API key is valid and working"
else
    log_warning "⚠️  API test failed (HTTP ${http_code})"
    log_info "This might be normal if the API endpoint is different"
    log_info "The configuration has been saved and will be tested during attestation"
fi

# Clean up
rm -f /tmp/api_test.json

echo
log_success "=== Configuration Complete ==="
log_info "Your Intel Trust Authority API key has been configured"
log_info "You can now run: sudo ./tdx-attestation.sh"
echo
log_info "Configuration details:"
log_info "  - API URL: ${api_url}"
log_info "  - API Key: ${api_key:0:8}...${api_key: -4} (masked)"
log_info "  - Config file: ${CONFIG_FILE}"
echo
log_warning "Security reminder:"
log_warning "  - Keep your config.json file secure"
log_warning "  - Do not commit it to version control"
log_warning "  - Consider using environment variables in production"
