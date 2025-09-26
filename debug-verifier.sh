#!/bin/bash
echo "Starting debug verifier..."
echo "Testing jq on evidence file..."
if jq empty /home/william_chew/tdx-test/json/tdx-local-evidence.json 2>/dev/null; then
    echo "JSON is valid"
else
    echo "JSON is invalid"
fi
echo "Debug verifier completed"
