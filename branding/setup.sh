#!/bin/bash
# Grafana Branding Setup — custom logo & favicon for Grafana OSS
# Usage: ./branding/setup.sh <command> [options]
#
# This script manages custom branding for the Grafana instance.
# It copies your logo/favicon files into the branding/ directory
# and toggles the volume mounts in compose.yaml.
#
# Grafana OSS supports file-based branding only (no env vars for title/logo).
# The browser tab title remains "Grafana" — changing it requires an NGINX
# reverse proxy (documented in project memory for future implementation).

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
BRANDING_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_FILE="$(dirname "$BRANDING_DIR")/compose.yaml"
BRANDING_MARKER_START="# === BRANDING START ==="
BRANDING_MARKER_END="# === BRANDING END ==="

# --- File mappings: compose mount path <- local branding file name
declare -A BRANDING_FILES=(
    ["grafana_icon.svg"]="/usr/share/grafana/public/img/grafana_icon.svg"
    ["grafana_com_auth_icon.svg"]="/usr/share/grafana/public/img/grafana_com_auth_icon.svg"
    ["fav32.png"]="/usr/share/grafana/public/img/fav32.png"
    ["apple-touch-icon.png"]="/usr/share/grafana/public/img/apple-touch-icon.png"
)

# --- Helpers ---
is_branding_enabled() {
    grep -q "^    - ./branding/" "$COMPOSE_FILE" 2>/dev/null
}

validate_file() {
    local file="$1"
    local expected_ext="$2"

    if [ ! -f "$file" ]; then
        print_error "File not found: $file"
        return 1
    fi

    local ext="${file##*.}"
    if [ "$expected_ext" = "svg" ] && [ "$ext" != "svg" ]; then
        print_warning "Expected SVG file, got .$ext — may not render correctly"
    elif [ "$expected_ext" = "png" ] && [ "$ext" != "png" ]; then
        print_warning "Expected PNG file, got .$ext — may not render correctly"
    fi

    local size
    size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
    if [ "$size" -eq 0 ]; then
        print_error "File is empty: $file"
        return 1
    fi

    return 0
}

copy_if_provided() {
    local src="$1"
    local dest_name="$2"

    if [ -z "$src" ]; then
        return 0
    fi

    local ext="${dest_name##*.}"
    if ! validate_file "$src" "$ext"; then
        return 1
    fi

    cp "$src" "$BRANDING_DIR/$dest_name"
    print_success "Copied $(basename "$src") -> branding/$dest_name"
    return 0
}

# --- Commands ---
cmd_help() {
    cat << 'HELP'
Usage: ./branding/setup.sh <command> [options]

Manage custom branding for Grafana OSS (logo, favicon, login logo).

Commands:
  init [--logo <file>] [--login-logo <file>] [--favicon <file>]
       Copy custom branding files and enable branding in compose.yaml.
       You can provide all files at once or one at a time.

  enable   Enable branding volume mounts in compose.yaml
  disable  Disable branding, revert to Grafana defaults
  status   Show current branding status

Options for init:
  --logo <file>        Main logo — sidebar, header (SVG, ~48x48 or larger)
  --login-logo <file>  Login page logo (SVG, same size as main logo)
  --favicon <file>     Browser tab icon (PNG, 32x32)

File naming convention (in branding/ directory):
  grafana_icon.svg            Main logo (sidebar, top bar)
  grafana_com_auth_icon.svg   Login page logo
  fav32.png                   Browser favicon (32x32)
  apple-touch-icon.png        Apple touch icon (180x180 recommended)

Notes:
  - SVG is recommended for logos (scales without quality loss)
  - Grafana OSS does not support changing the browser tab title via config
  - Changes take effect after restarting Grafana: docker compose restart grafana

Examples:
  ./branding/setup.sh init --logo my-logo.svg --favicon my-favicon.png
  ./branding/setup.sh enable
  ./branding/setup.sh disable
  ./branding/setup.sh status
HELP
}

cmd_status() {
    echo "Grafana Branding Status"
    echo "======================="
    echo ""

    if is_branding_enabled; then
        print_success "Branding is ENABLED in compose.yaml"
    else
        print_info "Branding is DISABLED (using Grafana defaults)"
    fi

    echo ""
    echo "Branding files:"
    for name in "${!BRANDING_FILES[@]}"; do
        if [ -f "$BRANDING_DIR/$name" ]; then
            local size
            size=$(stat -f%z "$BRANDING_DIR/$name" 2>/dev/null || stat -c%s "$BRANDING_DIR/$name" 2>/dev/null || echo "?")
            print_success "  $name ($size bytes)"
        else
            print_warning "  $name (not provided)"
        fi
    done

    echo ""
    echo "To apply changes: docker compose restart grafana"
}

cmd_init() {
    local logo=""
    local login_logo=""
    local favicon=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --logo)
                logo="${2:-}"
                if [ -z "$logo" ]; then
                    print_error "--logo requires a file path"
                    exit 1
                fi
                shift 2
                ;;
            --login-logo)
                login_logo="${2:-}"
                if [ -z "$login_logo" ]; then
                    print_error "--login-logo requires a file path"
                    exit 1
                fi
                shift 2
                ;;
            --favicon)
                favicon="${2:-}"
                if [ -z "$favicon" ]; then
                    print_error "--favicon requires a file path"
                    exit 1
                fi
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Run './branding/setup.sh help' for usage."
                exit 1
                ;;
        esac
    done

    if [ -z "$logo" ] && [ -z "$login_logo" ] && [ -z "$favicon" ]; then
        print_error "Provide at least one file: --logo, --login-logo, or --favicon"
        echo "Run './branding/setup.sh help' for usage."
        exit 1
    fi

    # Copy files
    local copied=0
    if copy_if_provided "$logo" "grafana_icon.svg"; then
        copied=$((copied + 1))
    else
        if [ -n "$logo" ]; then exit 1; fi
    fi

    if copy_if_provided "$login_logo" "grafana_com_auth_icon.svg"; then
        copied=$((copied + 1))
    else
        if [ -n "$login_logo" ]; then exit 1; fi
    fi

    if copy_if_provided "$favicon" "fav32.png"; then
        copied=$((copied + 1))
    else
        if [ -n "$favicon" ]; then exit 1; fi
    fi

    # If logo is provided but login logo is not, use the same logo for login
    if [ -n "$logo" ] && [ -z "$login_logo" ] && [ -f "$BRANDING_DIR/grafana_icon.svg" ]; then
        cp "$BRANDING_DIR/grafana_icon.svg" "$BRANDING_DIR/grafana_com_auth_icon.svg"
        print_info "Using same logo for login page (no --login-logo provided)"
        copied=$((copied + 1))
    fi

    if [ "$copied" -eq 0 ]; then
        print_error "No files were copied"
        exit 1
    fi

    # Enable branding in compose.yaml
    cmd_enable

    echo ""
    print_success "Branding files ready. Restart Grafana to apply:"
    print_info "  docker compose restart grafana"
}

cmd_enable() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "compose.yaml not found at: $COMPOSE_FILE"
        exit 1
    fi

    # Check if branding section already exists
    if grep -q "$BRANDING_MARKER_START" "$COMPOSE_FILE"; then
        # Uncomment the branding volume lines: "    # - ./branding/" -> "    - ./branding/"
        sed -i "/$BRANDING_MARKER_START/,/$BRANDING_MARKER_END/ s/^    # - \.\/branding\//    - .\/branding\//" "$COMPOSE_FILE"
        print_success "Branding enabled in compose.yaml"
    else
        print_error "Branding section not found in compose.yaml"
        print_info "Add the branding volume mounts manually (see compose.yaml comments)"
        exit 1
    fi

    # Verify at least one branding file exists
    local has_files=false
    for name in "${!BRANDING_FILES[@]}"; do
        if [ -f "$BRANDING_DIR/$name" ]; then
            has_files=true
            break
        fi
    done

    if [ "$has_files" = false ]; then
        print_warning "No branding files found in branding/ directory"
        print_info "Run './branding/setup.sh init --logo <file>' to add your logo"
    fi
}

cmd_disable() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "compose.yaml not found at: $COMPOSE_FILE"
        exit 1
    fi

    if ! grep -q "$BRANDING_MARKER_START" "$COMPOSE_FILE"; then
        print_info "Branding section not found in compose.yaml (already disabled)"
        return 0
    fi

    # Comment out the branding volume lines: "    - ./branding/" -> "    # - ./branding/"
    sed -i "/$BRANDING_MARKER_START/,/$BRANDING_MARKER_END/ s/^    - \.\/branding\//    # - .\/branding\//" "$COMPOSE_FILE"
    print_success "Branding disabled in compose.yaml"
    print_info "Restart Grafana to revert to defaults: docker compose restart grafana"
}

# --- Main ---
COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
    help|-h|--help)
        cmd_help
        ;;
    status)
        cmd_status
        ;;
    init)
        cmd_init "$@"
        ;;
    enable)
        cmd_enable
        ;;
    disable)
        cmd_disable
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        echo "Run './branding/setup.sh help' for usage."
        exit 1
        ;;
esac
