#!/bin/bash
# Setup Node Exporter for remote VM monitoring
# Usage: ./setup.sh <VM_NAME> <ENVIRONMENT>
#
# This script deploys a standalone node-exporter container on a remote VM.
# After running, add the VM's IP to the central Prometheus targets directory.

set -euo pipefail

VM_NAME="${1:-}"
ENVIRONMENT="${2:-production}"

# --- Color output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Parse arguments ---
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Usage: $0 [OPTIONS] <VM_NAME> [ENVIRONMENT]"
            echo ""
            echo "Deploy Node Exporter on a remote VM for centralized monitoring."
            echo "After running this script, the VM's metrics become available"
            echo "to the central Prometheus server."
            echo ""
            echo "This script:"
            echo "  1. Creates a compose.yaml with node-exporter on this VM"
            echo "  2. Starts the node-exporter container"
            echo "  3. Outputs the JSON target to add to the central Prometheus"
            echo ""
            echo "Arguments:"
            echo "  VM_NAME      Unique name for this VM (e.g., web-server-01)"
            echo "  ENVIRONMENT  Deployment environment (default: production)"
            echo ""
            echo "Options:"
            echo "  -h, --help    Show this help message"
            echo ""
            echo "After setup, on the CENTRAL server create a target file:"
            echo "  prometheus/targets/<vm-name>.json"
            echo "  Prometheus auto-discovers new targets every 30s."
            echo ""
            echo "Examples:"
            echo "  $0 web-server-01 production"
            echo "  $0 db-server staging"
            echo ""
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Positional arguments (after flags)
VM_NAME="${1:-}"
ENVIRONMENT="${2:-production}"

if [ -z "$VM_NAME" ]; then
    print_error "VM_NAME is required. Use --help for usage."
    exit 1
fi

print_info "Setting up Node Exporter for: $VM_NAME ($ENVIRONMENT)"

# --- Check prerequisites ---
if ! command -v docker &>/dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi

if ! docker info &>/dev/null; then
    print_error "Docker is not running. Please start Docker."
    exit 1
fi

# --- Detect host IP ---
if command -v hostname &>/dev/null; then
    HOST_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "UNKNOWN")
elif command -v ip &>/dev/null; then
    HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || echo "UNKNOWN")
else
    HOST_IP="UNKNOWN"
fi

# --- Create docker-compose file ---
cat > compose.yaml << EOF
version: "3.7"

services:
  node-exporter:
    image: prom/node-exporter:v1.6.1
    container_name: node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)(\$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    labels:
      - "vm.name=$VM_NAME"
      - "vm.environment=$ENVIRONMENT"
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:9100/metrics"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 5s
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge
EOF

print_info "Created compose.yaml for node-exporter"

# --- Start node-exporter ---
if docker compose -f compose.yaml up -d; then
    print_success "Node Exporter started for $VM_NAME"
else
    print_error "Failed to start Node Exporter"
    exit 1
fi

# --- Verify ---
sleep 3
if curl -sf "http://localhost:9100/metrics" >/dev/null 2>&1; then
    print_success "Node Exporter is healthy at http://localhost:9100/metrics"
else
    print_warning "Node Exporter may still be starting. Check: docker compose logs node-exporter"
fi

# --- Output instructions for central Prometheus ---
echo ""
echo "============================================================"
echo "  NEXT STEP: Register this VM with central Prometheus"
echo "============================================================"
echo ""
print_info "Add the following to your central Prometheus targets directory"
print_info "(prometheus/targets/${VM_NAME}.json):"
echo ""
cat << TARGET_JSON
[
  {
    "targets": ["${HOST_IP}:9100"],
    "labels": {
      "vm_name": "${VM_NAME}",
      "environment": "${ENVIRONMENT}"
    }
  }
]
TARGET_JSON
echo ""
print_info "Prometheus auto-discovers new targets every 30s — no restart needed."
echo ""
print_info "VM Details:"
print_info "  Name:        $VM_NAME"
print_info "  Environment: $ENVIRONMENT"
print_info "  IP Address:  $HOST_IP"
print_info "  Metrics URL: http://${HOST_IP}:9100/metrics"
echo ""
