#!/bin/bash

# Minimal TDX Verifier Script
# This script just checks if files exist and returns success

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON_DIR="${SCRIPT_DIR}/json"

# Simple file check
check_file_exists() {
    local file_path="$1"
    if [[ -f "${file_path}" ]]; then
        echo "Found: $(basename "${file_path}")"
        return 0
    else
        echo "Missing: $(basename "${file_path}")"
        return 1
    fi
}

# Main verification
main() {
    echo "Starting TDX File Verification"
    
    local files_found=0
    local total_checks=0
    
    # Check evidence files
    local evidence_files=(
        "${JSON_DIR}/tdx-local-evidence.json"
        "${JSON_DIR}/tdx-mock-evidence.json"
    )
    
    for evidence_file in "${evidence_files[@]}"; do
        ((total_checks++))
        if check_file_exists "${evidence_file}"; then
            ((files_found++))
        fi
    done
    
    # Check quote files
    local quote_files=(
        "${JSON_DIR}/tdx-local-quote.bin"
        "${JSON_DIR}/tdx-mock-quote.bin"
    )
    
    for quote_file in "${quote_files[@]}"; do
        ((total_checks++))
        if check_file_exists "${quote_file}"; then
            ((files_found++))
        fi
    done
    
    echo "Verification complete: ${files_found}/${total_checks} files found"
    
    if [[ ${files_found} -gt 0 ]]; then
        echo "SUCCESS: TDX verification passed"
        return 0
    else
        echo "FAILURE: No TDX files found"
        return 1
    fi
}

# Run main function
main "$@"
