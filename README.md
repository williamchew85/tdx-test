# Intel TDX Attestation on GCP Confidential VMs

This repository contains bash scripts for performing Intel Trust Domain Extensions (TDX) attestation and reporting on Google Cloud Platform (GCP) Confidential Virtual Machines.

## Overview

Intel TDX provides hardware-based memory encryption and isolation for virtual machines. This toolkit helps you:

- Verify TDX availability on your GCP confidential VM
- Generate TDX attestation evidence and tokens
- Verify attestation results
- Create comprehensive attestation reports

## Prerequisites

### GCP Setup

1. **Create a Confidential VM with TDX support:**
   ```bash
   gcloud compute instances create tdx-vm \
     --zone=us-central1-a \
     --machine-type=c3-standard-4 \
     --confidential-compute \
     --maintenance-policy=TERMINATE \
     --image-family=ubuntu-2204-lts \
     --image-project=ubuntu-os-cloud \
     --enable-nested-virtualization
   ```

2. **SSH into your VM:**
   ```bash
   gcloud compute ssh tdx-vm --zone=us-central1-a
   ```

### Intel Trust Authority API Key (Optional)

**Note**: If you don't have access to Intel Trust Authority API, you can use the alternative scripts provided in this toolkit.

1. Visit [Intel Trust Authority](https://trustauthority.intel.com)
2. Sign up for an account (if available)
3. Generate an API key for attestation services

**Alternative**: Use the local attestation scripts that don't require Trust Authority API access.

## Scripts Overview

### 1. Main Attestation Script (`tdx-attestation.sh`)

The primary script that performs complete TDX attestation (requires Trust Authority API):

```bash
sudo ./tdx-attestation.sh
```

**Features:**
- Checks TDX availability
- Installs required dependencies (Go, Intel Trust Authority CLI)
- Generates TDX evidence
- Creates attestation tokens
- Produces comprehensive reports

### 2. Local Attestation Script (`tdx-local-attestation.sh`)

**Alternative script that works WITHOUT Trust Authority API:**

```bash
sudo ./tdx-local-attestation.sh
```

**Features:**
- Works without Intel Trust Authority API access
- Uses local system analysis for TDX verification
- Generates local evidence and mock quotes
- Perfect for testing and development
- No external API dependencies

### 3. System Analyzer (`tdx-system-analyzer.sh`)

Deep analysis of TDX capabilities:

```bash
./tdx-system-analyzer.sh
```

**Features:**
- Comprehensive TDX system analysis
- CPU, memory, and kernel module analysis
- Security feature assessment
- TDX readiness evaluation
- Detailed recommendations

### 4. Mock Attestation (`tdx-mock-attestation.sh`)

Creates complete mock attestation environment:

```bash
./tdx-mock-attestation.sh
```

**Features:**
- Generates realistic mock TDX evidence
- Creates mock attestation tokens
- Produces mock TDX quotes
- Perfect for testing attestation verification logic
- No real cryptographic operations

### 5. Quote Generator (`tdx-quote-generator.sh`)

Generates TDX quotes for local verification:

```bash
sudo ./tdx-quote-generator.sh
```

**Features:**
- Generates TDX quote information
- Extracts system TDX capabilities
- Creates quote binary files
- Provides detailed system information

### 6. Quote Verifier (`tdx-verifier.sh`)

Verifies TDX quotes and attestation tokens:

```bash
# Verify all files
./tdx-verifier.sh --all

# Verify specific files
./tdx-verifier.sh --evidence tdx-evidence.json
./tdx-verifier.sh --token tdx-token.json
./tdx-verifier.sh --quote tdx-quote.bin
```

**Features:**
- Validates evidence file structure
- Verifies token format and content
- Checks quote file integrity
- Generates verification reports

## Quick Start

### Option 1: With Trust Authority API (Production)

1. **Clone and setup:**
   ```bash
   git clone <repository-url>
   cd tdx-test
   ```

2. **Configure API key (Interactive):**
   ```bash
   ./setup-trust-authority.sh
   ```
   
   Or manually configure:
   ```bash
   cp config.json.template config.json
   # Edit config.json and add your Intel Trust Authority API key
   ```

3. **Run attestation:**
   ```bash
   sudo ./tdx-attestation.sh
   ```

4. **Verify results:**
   ```bash
   ./tdx-verifier.sh --all
   ```

### Option 2: Without Trust Authority API (Testing/Development)

1. **Clone and setup:**
   ```bash
   git clone <repository-url>
   cd tdx-test
   ```

2. **Run local attestation (no API key needed):**
   ```bash
   sudo ./tdx-local-attestation.sh
   ```

3. **Analyze system capabilities:**
   ```bash
   ./tdx-system-analyzer.sh
   ```

4. **Generate mock data for testing:**
   ```bash
   ./tdx-mock-attestation.sh
   ```

5. **Verify results:**
   ```bash
   ./tdx-verifier.sh --all
   ```

## Configuration

### config.json

```json
{
    "trustauthority_api_url": "https://api.trustauthority.intel.com",
    "trustauthority_api_key": "your_api_key_here",
    "attestation_policy": {
        "enforce_tdx": true,
        "require_secure_boot": true,
        "require_measured_boot": true
    }
}
```

## Output Files

After running the scripts, you'll find these files organized in directories:

### JSON Files (`json/` directory)
- `tdx-evidence.json` - Raw TDX evidence data
- `tdx-token.json` - Attestation token from Intel Trust Authority
- `tdx-quote.bin` - Binary TDX quote (if generated)
- `tdx-attestation-report.json` - Comprehensive attestation report
- `tdx-verification-report.json` - Verification results
- `tdx-local-evidence.json` - Local TDX evidence (without API)
- `tdx-mock-evidence.json` - Mock TDX evidence for testing

### Log Files (`log/` directory)
- `tdx-attestation.log` - Detailed execution log
- `tdx-local-attestation.log` - Local attestation log
- `tdx-mock-attestation.log` - Mock attestation log
- `tdx-system-analyzer.log` - System analysis log
- `tdx-verifier.log` - Verification log

**Note**: The `json/` and `log/` directories are excluded from version control via `.gitignore` since they contain generated output files.

## Troubleshooting

### Common Issues

1. **"TDX is not available"**
   - Ensure you're using a TDX-capable machine type (c3-standard-4 or similar)
   - Check that confidential compute is enabled
   - Verify the VM is running in a supported region

2. **"Intel Trust Authority CLI not found"**
   - The main script will automatically install it
   - Ensure you have internet connectivity
   - Check that Go is properly installed

3. **"Invalid API key" or "Trust Authority API not available"**
   - **Solution**: Use the alternative scripts that don't require Trust Authority API
   - Run `sudo ./tdx-local-attestation.sh` instead
   - Use `./tdx-mock-attestation.sh` for testing purposes
   - Use `./tdx-system-analyzer.sh` for system analysis

4. **"No Trust Authority API access"**
   - This is common as Trust Authority API may not be publicly available
   - Use the local attestation scripts provided in this toolkit
   - All functionality is available without external API dependencies

### Verification Commands

Check TDX status:
```bash
sudo dmesg | grep -i tdx
```

Check system capabilities:
```bash
cat /proc/cpuinfo | grep -i tdx
```

Verify Go installation:
```bash
go version
```

## Security Considerations

- **API Keys**: Store your Intel Trust Authority API key securely
- **Root Access**: Scripts require root access for TDX operations
- **Network**: Ensure secure network connectivity for API calls
- **Logs**: Review log files for sensitive information before sharing

## Alternative Approaches

### Without Trust Authority API Access

If you don't have access to Intel Trust Authority API (which is common), this toolkit provides several alternative approaches:

1. **Local Attestation** (`tdx-local-attestation.sh`)
   - Works entirely with local system analysis
   - No external API dependencies
   - Generates local evidence and mock quotes
   - Perfect for testing and development

2. **System Analysis** (`tdx-system-analyzer.sh`)
   - Deep analysis of TDX capabilities
   - Comprehensive system assessment
   - TDX readiness evaluation
   - Detailed recommendations

3. **Mock Attestation** (`tdx-mock-attestation.sh`)
   - Generates realistic mock data
   - Perfect for testing attestation verification logic
   - No real cryptographic operations
   - Ideal for development and testing

4. **Local Quote Generation** (`tdx-quote-generator.sh`)
   - Extracts TDX system information
   - Generates local quote data
   - Works without external dependencies

### Use Cases

- **Testing and Development**: Use mock and local attestation scripts
- **System Analysis**: Use system analyzer to understand TDX capabilities
- **Integration Testing**: Use mock data to test your attestation verification logic
- **Research and Education**: All scripts provide educational value about TDX

## Intel Trust Authority API Integration

### New Features

The enhanced `tdx-attestation.sh` script now supports real attestation via Intel Trust Authority API:

- **Real Attestation**: Uses Intel's cloud service for production-grade attestation
- **Automatic Fallback**: Falls back to local attestation if API is unavailable
- **Interactive Setup**: Use `./setup-trust-authority.sh` for easy configuration
- **Secure Configuration**: API keys stored in `config.json` (keep secure!)

### API Integration Flow

1. **Configuration**: Script loads API key from `config.json`
2. **Connectivity Check**: Tests API accessibility
3. **Quote Generation**: Requests TDX quote from Intel Trust Authority
4. **Quote Verification**: Verifies quote with Intel's service
5. **Evidence Generation**: Creates attestation evidence
6. **Token Creation**: Generates attestation token

### Benefits of API Integration

- **Production Ready**: Real attestation suitable for production use
- **Intel Verified**: Attestation verified by Intel's infrastructure
- **Comprehensive**: Full attestation evidence and tokens
- **Reliable**: Automatic fallback ensures system always works

## Support

For issues related to:
- **Intel TDX**: Check [Intel TDX documentation](https://www.intel.com/content/www/us/en/developer/tools/trust-domain-extensions/overview.html)
- **Intel Trust Authority**: Visit [Intel Trust Authority docs](https://docs.trustauthority.intel.com)
- **GCP Confidential VMs**: See [GCP confidential computing documentation](https://cloud.google.com/compute/confidential-vm/docs)

## License

This project is provided as-is for educational and testing purposes. Please review Intel's and Google's terms of service for production use.
