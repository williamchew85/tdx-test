#!/bin/bash

# Debug script to check paths
echo "=== Path Debug ==="
echo "Current directory: $(pwd)"
echo "Script directory: $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "JSON_DIR would be: $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/json"
echo "LOG_DIR would be: $(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/log"

echo
echo "=== JSON Directory Contents ==="
ls -la json/ 2>/dev/null || echo "JSON directory not found"

echo
echo "=== Testing File Access ==="
if [[ -f "json/tdx-local-evidence.json" ]]; then
    echo "Found: json/tdx-local-evidence.json"
else
    echo "Missing: json/tdx-local-evidence.json"
fi

if [[ -f "json/test-evidence.json" ]]; then
    echo "Found: json/test-evidence.json"
else
    echo "Missing: json/test-evidence.json"
fi
