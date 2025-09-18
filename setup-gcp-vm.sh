#!/bin/bash

# GCP Confidential VM Setup Script for Intel TDX
# This script helps create and configure a GCP confidential VM with TDX support

set -euo pipefail

# Configuration
PROJECT_ID=""
ZONE="us-central1-a"
MACHINE_TYPE="c3-standard-4"
VM_NAME="tdx-vm"
IMAGE_FAMILY="ubuntu-2204-lts"
IMAGE_PROJECT="ubuntu-os-cloud"
NETWORK="default"
SUBNET=""
SERVICE_ACCOUNT=""
DISK_SIZE="20GB"
DISK_TYPE="pd-ssd"

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

# Display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -p, --project PROJECT_ID    GCP Project ID (required)"
    echo "  -z, --zone ZONE            GCP Zone (default: us-central1-a)"
    echo "  -m, --machine MACHINE_TYPE Machine type (default: c3-standard-4)"
    echo "  -n, --name VM_NAME         VM name (default: tdx-vm)"
    echo "  -s, --subnet SUBNET        Subnet name (optional)"
    echo "  -a, --service-account SA   Service account email (optional)"
    echo "  -d, --disk-size SIZE       Boot disk size (default: 20GB)"
    echo "  -t, --disk-type TYPE       Boot disk type (default: pd-ssd)"
    echo "  -h, --help                 Show this help message"
    echo
    echo "Examples:"
    echo "  $0 --project my-project-id"
    echo "  $0 --project my-project-id --zone us-east1-a --name my-tdx-vm"
}

# Check if gcloud is installed and authenticated
check_gcloud() {
    log_info "Checking gcloud CLI..."
    
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed"
        log_info "Please install gcloud CLI: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "No active gcloud authentication found"
        log_info "Please run: gcloud auth login"
        exit 1
    fi
    
    local active_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    log_success "gcloud CLI is authenticated as: ${active_account}"
}

# Set the project
set_project() {
    if [[ -z "${PROJECT_ID}" ]]; then
        log_error "Project ID is required"
        usage
        exit 1
    fi
    
    log_info "Setting project to: ${PROJECT_ID}"
    
    if gcloud config set project "${PROJECT_ID}" 2>/dev/null; then
        log_success "Project set to: ${PROJECT_ID}"
    else
        log_error "Failed to set project. Please check if the project ID is correct and you have access"
        exit 1
    fi
}

# Enable required APIs
enable_apis() {
    log_info "Enabling required GCP APIs..."
    
    local apis=(
        "compute.googleapis.com"
        "cloudresourcemanager.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        log_info "Enabling ${api}..."
        if gcloud services enable "${api}" 2>/dev/null; then
            log_success "Enabled ${api}"
        else
            log_warning "Failed to enable ${api} (may already be enabled)"
        fi
    done
}

# Check if the machine type supports TDX
check_machine_type() {
    log_info "Checking machine type: ${MACHINE_TYPE}"
    
    if gcloud compute machine-types describe "${MACHINE_TYPE}" --zone="${ZONE}" >/dev/null 2>&1; then
        log_success "Machine type ${MACHINE_TYPE} is available in zone ${ZONE}"
    else
        log_error "Machine type ${MACHINE_TYPE} is not available in zone ${ZONE}"
        log_info "Available TDX-capable machine types in ${ZONE}:"
        gcloud compute machine-types list --zones="${ZONE}" --filter="name~c3" --format="table(name,description)" 2>/dev/null || {
            log_warning "Could not list machine types. Please check manually."
        }
        exit 1
    fi
}

# Create the confidential VM
create_vm() {
    log_info "Creating confidential VM: ${VM_NAME}"
    
    local create_cmd="gcloud compute instances create ${VM_NAME}"
    create_cmd+=" --zone=${ZONE}"
    create_cmd+=" --machine-type=${MACHINE_TYPE}"
    create_cmd+=" --confidential-compute"
    create_cmd+=" --maintenance-policy=TERMINATE"
    create_cmd+=" --image-family=${IMAGE_FAMILY}"
    create_cmd+=" --image-project=${IMAGE_PROJECT}"
    create_cmd+=" --boot-disk-size=${DISK_SIZE}"
    create_cmd+=" --boot-disk-type=${DISK_TYPE}"
    create_cmd+=" --enable-nested-virtualization"
    
    if [[ -n "${SUBNET}" ]]; then
        create_cmd+=" --subnet=${SUBNET}"
    else
        create_cmd+=" --network=${NETWORK}"
    fi
    
    if [[ -n "${SERVICE_ACCOUNT}" ]]; then
        create_cmd+=" --service-account=${SERVICE_ACCOUNT}"
    fi
    
    # Add metadata for TDX
    create_cmd+=" --metadata=enable-oslogin=TRUE"
    
    log_info "Executing: ${create_cmd}"
    
    if eval "${create_cmd}"; then
        log_success "VM created successfully: ${VM_NAME}"
    else
        log_error "Failed to create VM"
        exit 1
    fi
}

# Wait for VM to be ready
wait_for_vm() {
    log_info "Waiting for VM to be ready..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ ${attempt} -le ${max_attempts} ]]; do
        if gcloud compute instances describe "${VM_NAME}" --zone="${ZONE}" --format="value(status)" | grep -q "RUNNING"; then
            log_success "VM is running"
            break
        fi
        
        log_info "Waiting for VM to start... (attempt ${attempt}/${max_attempts})"
        sleep 10
        ((attempt++))
    done
    
    if [[ ${attempt} -gt ${max_attempts} ]]; then
        log_error "VM failed to start within expected time"
        exit 1
    fi
}

# Get VM external IP
get_vm_ip() {
    log_info "Getting VM external IP..."
    
    local external_ip=$(gcloud compute instances describe "${VM_NAME}" --zone="${ZONE}" --format="value(networkInterfaces[0].accessConfigs[0].natIP)" 2>/dev/null)
    
    if [[ -n "${external_ip}" ]]; then
        log_success "VM external IP: ${external_ip}"
        echo "${external_ip}"
    else
        log_warning "Could not get external IP (VM may not have external access)"
        echo ""
    fi
}

# Display connection instructions
display_connection_info() {
    local external_ip=$(get_vm_ip)
    
    log_info "=== VM Setup Complete ==="
    echo
    log_success "VM Name: ${VM_NAME}"
    log_success "Zone: ${ZONE}"
    log_success "Machine Type: ${MACHINE_TYPE}"
    log_success "Project: ${PROJECT_ID}"
    
    if [[ -n "${external_ip}" ]]; then
        log_success "External IP: ${external_ip}"
    fi
    
    echo
    log_info "To connect to your VM:"
    echo "  gcloud compute ssh ${VM_NAME} --zone=${ZONE}"
    
    if [[ -n "${external_ip}" ]]; then
        echo "  ssh -i ~/.ssh/google_compute_engine ubuntu@${external_ip}"
    fi
    
    echo
    log_info "To verify TDX is working:"
    echo "  sudo dmesg | grep -i tdx"
    echo "  cat /proc/cpuinfo | grep -i tdx"
    
    echo
    log_info "Next steps:"
    echo "  1. SSH into the VM"
    echo "  2. Clone this repository"
    echo "  3. Configure your Intel Trust Authority API key"
    echo "  4. Run the TDX attestation scripts"
}

# Cleanup function
cleanup() {
    log_info "Cleaning up..."
    # Add any cleanup logic here if needed
}

# Main execution
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--project)
                PROJECT_ID="$2"
                shift 2
                ;;
            -z|--zone)
                ZONE="$2"
                shift 2
                ;;
            -m|--machine)
                MACHINE_TYPE="$2"
                shift 2
                ;;
            -n|--name)
                VM_NAME="$2"
                shift 2
                ;;
            -s|--subnet)
                SUBNET="$2"
                shift 2
                ;;
            -a|--service-account)
                SERVICE_ACCOUNT="$2"
                shift 2
                ;;
            -d|--disk-size)
                DISK_SIZE="$2"
                shift 2
                ;;
            -t|--disk-type)
                DISK_TYPE="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    log_info "Starting GCP Confidential VM Setup for Intel TDX"
    
    # Execute setup steps
    check_gcloud
    set_project
    enable_apis
    check_machine_type
    create_vm
    wait_for_vm
    display_connection_info
    
    log_success "GCP VM setup completed successfully!"
}

# Handle script interruption
trap 'log_error "Script interrupted by user"; exit 1' INT TERM

# Run main function
main "$@"
