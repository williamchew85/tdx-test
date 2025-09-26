#!/bin/bash

# Debug script to test analyzer commands

echo "=== Testing TDX Detection Commands ==="

echo "1. CPU TDX count:"
grep -i tdx /proc/cpuinfo | wc -l

echo "2. Module TDX count:"
lsmod | grep -i tdx | wc -l

echo "3. Device check:"
test -e /dev/tdx_guest && echo "true" || echo "false"

echo "4. Memory encryption check:"
dmesg | grep -i "Memory Encryption Features active" | grep -i tdx > /dev/null && echo "true" || echo "false"

echo "5. Raw CPU info TDX lines:"
grep -i tdx /proc/cpuinfo

echo "6. Raw module TDX lines:"
lsmod | grep -i tdx

echo "7. Raw dmesg TDX lines:"
dmesg | grep -i tdx

echo "=== Debug Complete ==="
