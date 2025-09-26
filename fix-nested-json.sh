#!/bin/bash

# Fix the nested json directory issue
echo "Fixing nested json directory issue..."

# Remove the nested json directory
rm -rf json/json/

# Clean up any other nested directories
find json/ -type d -name "json" -exec rm -rf {} + 2>/dev/null || true

echo "Fixed! Nested json directory removed."
echo "Current json directory structure:"
ls -la json/
