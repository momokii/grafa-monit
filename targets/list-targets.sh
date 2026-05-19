#!/bin/bash
# List all remote hosts in centralized monitoring
# Usage: ./targets/list-targets.sh [--app <APP>]

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
APP_FILTER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            cat << 'HELP'
Usage: ./targets/list-targets.sh [--app <APP>]

List all configured remote hosts, grouped by application.

Options:
  --app <APP>  Show only hosts in a specific app group
  -h, --help   Show this help message

Output shows:
  - App group name and environment
  - Each host with vm_name, IP:port
  - Total host count

Examples:
  ./targets/list-targets.sh
  ./targets/list-targets.sh --app my-app-A
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
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# --- Find target files ---
TARGET_FILES=()

if [ -n "$APP_FILTER" ]; then
    app_safe=$(echo "$APP_FILTER" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g; s/^-*//; s/-*$//')
    target_file="${TARGETS_DIR}/${app_safe}.json"
    if [ -f "$target_file" ]; then
        TARGET_FILES+=("$target_file")
    else
        print_error "App group '${APP_FILTER}' not found (no file: ${target_file})"
        exit 1
    fi
else
    while IFS= read -r f; do
        TARGET_FILES+=("$f")
    done < <(ls "${TARGETS_DIR}"/*.json 2>/dev/null || true)
fi

if [ ${#TARGET_FILES[@]} -eq 0 ]; then
    print_info "No target files found in ${TARGETS_DIR}/"
    print_info "Add hosts with: ./targets/add-host.sh <IP> <VM_NAME> <APP> <ENV>"
    exit 0
fi

# --- Display targets ---
TOTAL_HOSTS=0

for target_file in "${TARGET_FILES[@]}"; do
    APP_NAME=$(basename "$target_file" .json)

    # Parse JSON with python3 or jq
    if command -v python3 &>/dev/null; then
        ENTRIES=$(python3 -c "
import json
with open('${target_file}', 'r') as f:
    data = json.load(f)
for entry in data:
    labels = entry.get('labels', {})
    targets = entry.get('targets', ['?'])
    print(f\"{labels.get('vm_name', '?')}|{targets[0] if targets else '?'}|{labels.get('app', '?')}|{labels.get('environment', '?')}\")
" 2>/dev/null)
    elif command -v jq &>/dev/null; then
        ENTRIES=$(jq -r '.[] | "\(.labels.vm_name // "?")|\(.targets[0] // "?")|\(.labels.app // "?")|\(.labels.environment // "?")"' "$target_file" 2>/dev/null)
    else
        print_error "python3 or jq required to parse JSON"
        exit 1
    fi

    if [ -z "$ENTRIES" ]; then
        continue
    fi

    # Get environment from first entry
    FIRST_ENV=$(echo "$ENTRIES" | head -1 | cut -d'|' -f4)
    HOST_COUNT=$(echo "$ENTRIES" | wc -l)
    TOTAL_HOSTS=$((TOTAL_HOSTS + HOST_COUNT))

    echo ""
    print_info "${APP_NAME} (${FIRST_ENV}) — ${HOST_COUNT} host(s)"
    echo "  File: ${target_file}"
    echo ""

    while IFS='|' read -r vm_name target app env; do
        printf "    %-20s %-25s %s\n" "$vm_name" "$target" ""
    done <<< "$ENTRIES"
done

echo ""
print_success "Total: ${TOTAL_HOSTS} host(s) in ${#TARGET_FILES[@]} app group(s)"
echo ""
print_info "Manage targets:"
print_info "  Add:    ./targets/add-host.sh <IP> <VM_NAME> <APP> <ENV>"
print_info "  Remove: ./targets/remove-host.sh <VM_NAME> [--clean]"
