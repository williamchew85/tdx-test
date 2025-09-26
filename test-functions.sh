#!/bin/bash

# Test script to debug the hanging issue

# Source the verifier functions
source ./tdx-verifier-simple.sh

echo "=== Testing check_file function ==="
check_file json/tdx-local-evidence.json
echo "check_file exit code: $?"

echo
echo "=== Testing log_info function ==="
log_info "Test message"
echo "log_info exit code: $?"

echo
echo "=== Testing directory variables ==="
echo "JSON_DIR: $JSON_DIR"
echo "LOG_DIR: $LOG_DIR"

echo
echo "=== Testing file operations ==="
if [[ -f "json/tdx-local-evidence.json" ]]; then
    echo "File exists"
    local file_size=$(stat -c%s "json/tdx-local-evidence.json" 2>/dev/null || echo "0")
    echo "File size: $file_size"
else
    echo "File missing"
fi

echo
echo "=== Test completed ==="
