#!/bin/bash
# Remove a remote host from centralized monitoring
# Usage: ./remove-host.sh <VM_NAME> [--app <APP>] [--clean]
#
# Removes host from target file and optionally cleans ghost data from Prometheus.

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
PROMETHEUS_URL="http://localhost:9090"

# --- Parse arguments ---
VM_NAME=""
APP_FILTER=""
CLEAN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            cat << 'HELP'
Usage: ./targets/remove-host.sh <VM_NAME> [--app <APP>] [--clean]

Remove a remote host from centralized monitoring. Optionally cleans
ghost data (stale time series) from Prometheus so it doesn't show up
in Grafana dashboards anymore.

Arguments:
  VM_NAME      Name of the host to remove (e.g., fe-app-a)

Options:
  --app <APP>  Only search in specific app group (faster)
  --clean      Delete stale Prometheus series for this host immediately
  -h, --help   Show this help message

How it works:
  1. Finds the vm_name in prometheus/targets/*.json files
  2. Removes the entry from the target file
  3. If the app file becomes empty, deletes the file
  4. With --clean: calls Prometheus admin API to delete matching series

Ghost target cleanup (--clean):
  When you remove a target, Prometheus stops scraping it but old metric
  data lingers until retention expires (15 days). The --clean flag tells
  Prometheus to immediately delete all series for this host, so it
  disappears from Grafana dashboards right away.

Examples:
  ./targets/remove-host.sh fe-app-a
  ./targets/remove-host.sh fe-app-a --app my-app-A
  ./targets/remove-host.sh typo-name --clean
  ./targets/remove-host.sh fe-app-a --app my-app-A --clean
HELP
            exit 0
            ;;
        --app)
            APP_FILTER="${2:-}"
            if [ -z "$APP_FILTER" ]; then
                print_error "--app requires a value"
                exit 1
            fi
            shift 2
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        -*)
            print_error "Unknown option: $1"
            exit 1
            ;;
        *)
            if [ -z "$VM_NAME" ]; then
                VM_NAME="$1"
            else
                print_error "Unexpected argument: $1"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ -z "$VM_NAME" ]; then
    print_error "VM_NAME is required. Use --help for usage."
    exit 1
fi

# --- Find the target ---
FOUND=false
FOUND_FILE=""
FOUND_IP=""

search_files() {
    local pattern="$1"
    if [ -n "$APP_FILTER" ]; then
        local app_safe
        app_safe=$(echo "$APP_FILTER" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/^-*//; s/-*$//')
        local target_file="${TARGETS_DIR}/${app_safe}.json"
        if [ -f "$target_file" ]; then
            echo "$target_file"
        fi
    else
        ls "${TARGETS_DIR}"/*.json 2>/dev/null || true
    fi
}

for target_file in $(search_files "$APP_FILTER"); do
    if grep -q "\"vm_name\": \"${VM_NAME}\"" "$target_file"; then
        FOUND=true
        FOUND_FILE="$target_file"
        FOUND_IP=$(grep -A1 '"vm_name": "'"${VM_NAME}"'"' "$target_file" | grep -oP '"targets": \["\K[^"]+' || echo "unknown")
        break
    fi
done

if [ "$FOUND" = false ]; then
    print_error "vm_name '${VM_NAME}' not found in any target file"
    if [ -n "$APP_FILTER" ]; then
        print_info "Searched in app group: ${APP_FILTER}"
    else
        print_info "Searched all files in ${TARGETS_DIR}/"
    fi
    print_info "Use ./targets/list-targets.sh to see all configured hosts"
    exit 1
fi

print_info "Found '${VM_NAME}' (${FOUND_IP}) in ${FOUND_FILE}"

# --- Remove entry from JSON file ---
# Use python3 to parse and modify JSON properly
if command -v python3 &>/dev/null; then
    python3 -c "
import json, sys

with open('${FOUND_FILE}', 'r') as f:
    data = json.load(f)

original_len = len(data)
data = [entry for entry in data
        if entry.get('labels', {}).get('vm_name') != '${VM_NAME}']

if len(data) == 0:
    print('__EMPTY__')
else:
    with open('${FOUND_FILE}', 'w') as f:
        json.dump(data, f, indent=2)
    print(f'__WRITTEN__:{original_len - len(data)}')
" | {
        read -r result
        if [ "$result" = "__EMPTY__" ]; then
            rm "$FOUND_FILE"
            print_info "Removed empty app file: $(basename "$FOUND_FILE")"
        else
            count=$(echo "$result" | sed 's/__WRITTEN__://')
            print_info "Removed ${count} host(s) from $(basename "$FOUND_FILE")"
        fi
    }
elif command -v jq &>/dev/null; then
    # Fallback: use jq
    UPDATED=$(jq "del(.[] | select(.labels.vm_name == \"${VM_NAME}\"))" "$FOUND_FILE")
    REMAINING=$(echo "$UPDATED" | jq 'length')

    if [ "$REMAINING" -eq 0 ]; then
        rm "$FOUND_FILE"
        print_info "Removed empty app file: $(basename "$FOUND_FILE")"
    else
        echo "$UPDATED" > "$FOUND_FILE"
        print_info "Removed host from $(basename "$FOUND_FILE")"
    fi
else
    print_error "python3 or jq required to modify JSON files"
    exit 1
fi

# --- Clean stale Prometheus data ---
if [ "$CLEAN" = true ]; then
    print_info "Cleaning stale Prometheus series for '${VM_NAME}'..."

    # Delete series by vm_name label
    if curl -sf -X POST "${PROMETHEUS_URL}/api/v1/admin/tsdb/delete_series?match[]={vm_name=\"${VM_NAME}\"}" 2>/dev/null; then
        print_success "Deleted series matching vm_name=\"${VM_NAME}\""
    else
        print_warning "Could not delete series — is Prometheus running?"
    fi

    # Also clean by instance if we have the IP
    if [ "$FOUND_IP" != "unknown" ]; then
        curl -sf -X POST "${PROMETHEUS_URL}/api/v1/admin/tsdb/delete_series?match[]={instance=\"${FOUND_IP}\"}" 2>/dev/null || true
    fi

    # Clean tombstones
    if curl -sf -X POST "${PROMETHEUS_URL}/api/v1/admin/tsdb/clean_tombstones" 2>/dev/null; then
        print_success "Cleaned tombstones"
    fi
fi

echo ""
print_success "Host '${VM_NAME}' removed successfully!"
if [ "$CLEAN" = false ]; then
    print_info "Stale data will expire after retention period (15 days)"
    print_info "Use --clean flag to remove it immediately"
fi
