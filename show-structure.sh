#!/bin/bash

# Show Directory Structure Script
# This script displays the organized directory structure for TDX attestation outputs

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    echo -e "[${level}] ${message}"
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

# Display directory structure
show_structure() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║              TDX Attestation Directory Structure            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo
    
    log_info "Project Structure:"
    echo
    echo "tdx-test/"
    echo "├── 📁 json/                    # All JSON output files"
    echo "│   ├── tdx-attestation-report.json"
    echo "│   ├── tdx-evidence.json"
    echo "│   ├── tdx-token.json"
    echo "│   ├── tdx-local-evidence.json"
    echo "│   ├── tdx-local-quote.bin"
    echo "│   ├── tdx-measurements.json"
    echo "│   ├── tdx-mock-evidence.json"
    echo "│   ├── tdx-mock-token.json"
    echo "│   ├── tdx-mock-quote.bin"
    echo "│   ├── tdx-mock-attestation-report.json"
    echo "│   ├── tdx-quote-info.json"
    echo "│   ├── tdx-quote.bin"
    echo "│   ├── tdx-system-analysis.json"
    echo "│   ├── tdx-verification-report.json"
    echo "│   └── tdx-test-suite-report.json"
    echo "├── 📁 log/                     # All log files"
    echo "│   ├── tdx-attestation.log"
    echo "│   ├── tdx-local-attestation.log"
    echo "│   ├── tdx-mock-attestation.log"
    echo "│   ├── tdx-quote-generator.log"
    echo "│   ├── tdx-system-analyzer.log"
    echo "│   ├── tdx-verifier.log"
    echo "│   └── tdx-test-suite.log"
    echo "├── 📄 config.json              # Configuration file"
    echo "├── 📄 config.json.template     # Configuration template"
    echo "└── 📄 *.sh                     # All TDX scripts"
    echo
}

# Show current directory contents
show_current_contents() {
    log_info "Current Directory Contents:"
    echo
    
    if [[ -d "json" ]]; then
        log_success "✅ json/ directory exists"
        if [[ -n "$(ls -A json 2>/dev/null)" ]]; then
            echo "   Contents:"
            ls -la json/ | while read line; do
                echo "     ${line}"
            done
        else
            log_warning "   (empty)"
        fi
    else
        log_warning "❌ json/ directory not found"
    fi
    
    echo
    
    if [[ -d "log" ]]; then
        log_success "✅ log/ directory exists"
        if [[ -n "$(ls -A log 2>/dev/null)" ]]; then
            echo "   Contents:"
            ls -la log/ | while read line; do
                echo "     ${line}"
            done
        else
            log_warning "   (empty)"
        fi
    else
        log_warning "❌ log/ directory not found"
    fi
    
    echo
}

# Show script information
show_script_info() {
    log_info "Script Output Locations:"
    echo
    echo "📋 Main Attestation Scripts:"
    echo "   tdx-attestation.sh          → json/tdx-evidence.json, json/tdx-token.json"
    echo "   tdx-local-attestation.sh    → json/tdx-local-evidence.json, json/tdx-local-quote.bin"
    echo "   tdx-mock-attestation.sh     → json/tdx-mock-evidence.json, json/tdx-mock-token.json"
    echo
    echo "🔍 Analysis Scripts:"
    echo "   tdx-system-analyzer.sh      → json/tdx-system-analysis.json"
    echo "   tdx-quote-generator.sh      → json/tdx-quote-info.json, json/tdx-quote.bin"
    echo
    echo "✅ Verification Scripts:"
    echo "   tdx-verifier.sh             → json/tdx-verification-report.json"
    echo "   run-all-tests.sh            → json/tdx-test-suite-report.json"
    echo
    echo "📝 All scripts output logs to: log/"
    echo
}

# Show usage examples
show_usage_examples() {
    log_info "Usage Examples:"
    echo
    echo "🔧 Create directories and run scripts:"
    echo "   mkdir -p json log"
    echo "   sudo ./tdx-local-attestation.sh"
    echo "   ./tdx-verifier.sh --all"
    echo
    echo "📊 View organized outputs:"
    echo "   ls -la json/                 # View all JSON outputs"
    echo "   ls -la log/                  # View all log files"
    echo "   cat json/tdx-system-analysis.json | jq ."
    echo
    echo "🧹 Clean up outputs:"
    echo "   rm -rf json/* log/*          # Remove all outputs"
    echo "   rm -rf json log              # Remove directories"
    echo
}

# Main execution
main() {
    show_structure
    show_current_contents
    show_script_info
    show_usage_examples
    
    log_success "Directory structure information displayed!"
    log_info "Run any TDX script to start generating organized outputs."
}

# Run main function
main "$@"
