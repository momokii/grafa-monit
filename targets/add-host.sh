#!/bin/bash
# Add a remote host to centralized monitoring
# Usage: ./add-host.sh <IP> <VM_NAME> <APP> <ENVIRONMENT>
#
# Creates/appends to prometheus/targets/<app>.json
# Prometheus auto-discovers changes within 30s — no restart needed.

set -euo pipefail

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

# --- Config ---
TARGETS_DIR="prometheus/targets"

# --- Parse arguments ---
if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    cat << 'HELP'
Usage: ./targets/add-host.sh <IP> <VM_NAME> <APP> <ENVIRONMENT> [--job <JOB_NAME>]

Add a remote host to centralized monitoring. One JSON file per app group.
Prometheus auto-discovers new targets every 30s — no restart needed.

Arguments:
  IP           Remote host IP address (e.g., 192.168.1.10)
  VM_NAME      Unique name for this host (e.g., fe-app-a)
  APP          Application group name (e.g., my-app-A)
  ENVIRONMENT  Deployment environment (e.g., production, staging)

Options:
  --job <JOB>  Custom Prometheus job name (default: remote-node-exporters)
               Use this to organize targets into separate job groups for
               filtering in Grafana dashboards and alert rules.

Examples:
  ./targets/add-host.sh 192.168.1.10 fe-app-a  my-app-A production
  ./targets/add-host.sh 192.168.1.11 be-app-a  my-app-A production --job prod-servers
  ./targets/add-host.sh 192.168.1.20 fe-app-b  my-app-B staging
  ./targets/add-host.sh 10.0.0.5    db-main   infra    production --job db-nodes

Target file format (prometheus/targets/<app>.json):
  Each file contains one JSON array with all hosts in that app group.
  Prometheus reads all *.json files every 30s via file_sd_configs.

Validations:
  - IP address format is checked
  - Duplicate IPs and vm_names are rejected within the same app
  - App names are sanitized (lowercased, spaces replaced with hyphens)
HELP
    exit 0
fi

HOST_IP="${1:-}"
VM_NAME="${2:-}"
APP="${3:-}"
ENVIRONMENT="${4:-production}"
CUSTOM_JOB=""

# Parse optional flags
shift 4 2>/dev/null || shift $# 2>/dev/null || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --job)
            CUSTOM_JOB="${2:-}"
            if [ -z "$CUSTOM_JOB" ]; then
                print_error "--job requires a value (e.g., --job prod-servers)"
                exit 1
            fi
            shift 2
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# --- Validate required arguments ---
if [ -z "$HOST_IP" ] || [ -z "$VM_NAME" ] || [ -z "$APP" ]; then
    print_error "Missing required arguments. Use --help for usage."
    exit 1
fi

# --- Validate IP format ---
if ! echo "$HOST_IP" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
    print_error "Invalid IP address: $HOST_IP"
    exit 1
fi

# --- Sanitize app name for filename ---
APP_SAFE=$(echo "$APP" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/^-*//; s/-*$//')
TARGET_FILE="${TARGETS_DIR}/${APP_SAFE}.json"

# --- Create targets directory if needed ---
if [ ! -d "$TARGETS_DIR" ]; then
    mkdir -p "$TARGETS_DIR"
elif [ ! -w "$TARGETS_DIR" ]; then
    # May be owned by root (created by Prometheus container)
    print_info "Fixing targets directory ownership..."
    if sudo chown "$(whoami)" "$TARGETS_DIR" 2>/dev/null; then
        print_success "Fixed ownership"
    else
        print_error "Cannot write to $TARGETS_DIR (owned by root). Run: sudo chown \$(whoami) $TARGETS_DIR"
        exit 1
    fi
fi

# --- Check for duplicates ---
if [ -f "$TARGET_FILE" ]; then
    EXISTING=$(cat "$TARGET_FILE")

    if echo "$EXISTING" | grep -q "\"${HOST_IP}:9100\""; then
        print_error "IP ${HOST_IP}:9100 already exists in ${APP_SAFE}"
        print_info "Use ./targets/remove-host.sh to remove it first"
        exit 1
    fi

    if echo "$EXISTING" | grep -q "\"vm_name\": \"${VM_NAME}\""; then
        print_error "vm_name '${VM_NAME}' already exists in ${APP_SAFE}"
        print_info "Use ./targets/remove-host.sh to remove it first"
        exit 1
    fi
fi

# --- Build new entry ---
if [ -n "$CUSTOM_JOB" ]; then
    NEW_ENTRY=$(cat << ENTRY
  {
    "targets": ["${HOST_IP}:9100"],
    "labels": {
      "vm_name": "${VM_NAME}",
      "app": "${APP}",
      "environment": "${ENVIRONMENT}",
      "custom_job": "${CUSTOM_JOB}"
    }
  }
ENTRY
)
else
    NEW_ENTRY=$(cat << ENTRY
  {
    "targets": ["${HOST_IP}:9100"],
    "labels": {
      "vm_name": "${VM_NAME}",
      "app": "${APP}",
      "environment": "${ENVIRONMENT}"
    }
  }
ENTRY
)
fi

# --- Write file ---
if [ -f "$TARGET_FILE" ] && [ -s "$TARGET_FILE" ]; then
    # Append to existing file: replace closing ] with , new_entry ]
    EXISTING_CONTENT=$(cat "$TARGET_FILE")
    # Remove trailing ] and whitespace, add new entry
    TRIMMED=$(echo "$EXISTING_CONTENT" | sed '$ s/][[:space:]]*$//')
    cat > "$TARGET_FILE" << EOF
${TRIMMED},
${NEW_ENTRY}
]
EOF
    print_info "Added ${VM_NAME} to existing group: ${APP_SAFE}"
else
    # Create new file
    cat > "$TARGET_FILE" << EOF
[
${NEW_ENTRY}
]
EOF
    print_info "Created new group: ${APP_SAFE}"
fi

# --- Summary ---
echo ""
print_success "Host added successfully!"
echo ""
print_info "Details:"
print_info "  VM Name:     ${VM_NAME}"
print_info "  IP:          ${HOST_IP}:9100"
print_info "  App Group:   ${APP} (${APP_SAFE})"
print_info "  Environment: ${ENVIRONMENT}"
if [ -n "$CUSTOM_JOB" ]; then
print_info "  Custom Job:  ${CUSTOM_JOB}"
fi
print_info "  Target File: ${TARGET_FILE}"
echo ""
print_info "Prometheus will auto-discover this host within 30 seconds."
if [ -n "$CUSTOM_JOB" ]; then
print_info "To include this job in alert rules, update alerts/config.yml:"
print_info "  node_exporter_jobs: \"node-exporter|remote-node-exporters|${CUSTOM_JOB}\""
print_info "Then run: ./alerts/setup.sh generate && docker compose restart prometheus"
fi
print_info "Manage targets: ./targets/list-targets.sh"
