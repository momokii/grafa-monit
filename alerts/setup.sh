#!/bin/bash
# Alert Configuration Setup — simplified alerting for Grafana monitoring stack
# Usage: ./alerts/setup.sh <command> [options]
#
# Manages Prometheus alert rules and AlertManager notification channels.
# Interactive wizard for first-time setup — no Grafana UI needed.
#
# Generated files:
#   alerts.yml          — Prometheus alert rules (tracked in git, no secrets)
#   alertmanager.yml    — AlertManager config (gitignored, contains credentials)
#   alerts/config.yml   — Your alert configuration (gitignored, contains credentials)

set -euo pipefail

# --- Color output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
print_step()    { echo -e "${PURPLE}[STEP]${NC} $1"; }

# --- Config ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$SCRIPT_DIR/config.yml"
ALERTS_FILE="$PROJECT_DIR/alerts.yml"
ALERTMANAGER_FILE="$PROJECT_DIR/alertmanager.yml"
TEMPLATE_FILE="$SCRIPT_DIR/notify.tmpl"

# --- Config helpers ---

# Read a value from config.yml: get_config "key" [default]
get_config() {
    local key="$1"
    local default="${2:-}"
    local value
    value=$(grep "^${key}:" "$CONFIG_FILE" 2>/dev/null | head -1 | sed "s/^${key}: *//" | sed "s/^# *//" | tr -d '"' | tr -d "'")
    if [ -n "$value" ]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# Read a list value from config.yml: get_list_config "key" [default]
get_list_config() {
    local key="$1"
    local default="${2:-}"
    local value
    value=$(grep "^${key}:" "$CONFIG_FILE" 2>/dev/null | head -1 | sed "s/^${key}: *//" | tr -d '[]' | sed 's/,/ /g')
    if [ -n "$value" ]; then
        echo "$value"
    else
        echo "$default"
    fi
}

# Check if a channel type is enabled in config
channel_enabled() {
    local channel="$1"
    local val
    val=$(get_config "${channel}_enabled" "false")
    echo "$val" | grep -qi "true"
}

# Prompt user with default value
prompt() {
    local question="$1"
    local default="${2:-}"
    if [ -n "$default" ]; then
        printf "%s [%s]: " "$question" "$default" >&2
    else
        printf "%s: " "$question" >&2
    fi
    read -r answer
    if [ -z "$answer" ]; then
        echo "$default"
    else
        echo "$answer"
    fi
}

# Prompt yes/no
prompt_yesno() {
    local question="$1"
    local default="${2:-n}"
    while true; do
        local yn
        yn=$(prompt "$question (y/n)" "$default")
        case "$yn" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) print_warning "Please answer y or n" ;;
        esac
    done
}

# --- Help ---
cmd_help() {
    cat << 'HELP'
Usage: ./alerts/setup.sh <command> [options]

Manage alert rules and notification channels for the monitoring stack.
No Grafana UI needed — everything is configured via this script.

Commands:
  init          Interactive first-time setup wizard
  generate      Regenerate alerts.yml + alertmanager.yml from config.yml
  add-channel   Add or update a notification channel (guided)
  add-rule      Add a custom alert rule (guided)
  status        Show current alert configuration
  test          Send a test notification to configured channels
  help          Show this help

Workflow:
  1. Run  ./alerts/setup.sh init       — answer questions, get working alerts
  2. Restart services:
       docker compose restart prometheus
       docker compose up -d --force-recreate alertmanager
  3. Run  ./alerts/setup.sh test       — verify notifications arrive

Later changes:
  - Edit alerts/config.yml and run ./alerts/setup.sh generate
  - Or use ./alerts/setup.sh add-channel / add-rule
  - Then restart services again

Supported notification channels: Discord, Telegram, Slack, Email

Alert rules included by default:
  HostDown            Critical — host unreachable for 2m
  HighCPUWarning      Warning  — CPU > 80% for 5m
  HighCPUCritical     Critical — CPU > 95% for 5m
  HighMemoryWarning   Warning  — Memory > 80% for 5m
  HighMemoryCritical  Critical — Memory > 95% for 5m
  HighDiskUsageWarning  Warning  — Disk > 85% for 5m
  HighDiskUsageCritical Critical — Disk > 95% for 5m
  HighDiskIO          Warning  — Disk I/O wait > 10% for 5m
  ContainerRestarted  Warning  — Container restarted >5 times in 10m

Examples:
  ./alerts/setup.sh init
  ./alerts/setup.sh init --defaults          # Use all defaults, skip wizard
  ./alerts/setup.sh generate
  ./alerts/setup.sh add-channel
  ./alerts/setup.sh add-rule
  ./alerts/setup.sh status
  ./alerts/setup.sh test
HELP
}

# --- Generate alerts.yml from config ---
generate_alerts() {
    local cpu_warn cpu_crit cpu_dur
    local mem_warn mem_crit mem_dur
    local disk_warn disk_crit disk_dur
    local diskio_warn diskio_dur
    local host_down_dur
    local container_count container_dur

    cpu_warn=$(get_config "cpu_warning" "80")
    cpu_crit=$(get_config "cpu_critical" "95")
    cpu_dur=$(get_config "cpu_duration" "5m")
    mem_warn=$(get_config "memory_warning" "80")
    mem_crit=$(get_config "memory_critical" "95")
    mem_dur=$(get_config "memory_duration" "5m")
    disk_warn=$(get_config "disk_warning" "85")
    disk_crit=$(get_config "disk_critical" "95")
    disk_dur=$(get_config "disk_duration" "5m")
    diskio_warn=$(get_config "disk_io_warning" "10")
    diskio_dur=$(get_config "disk_io_duration" "5m")
    host_down_dur=$(get_config "host_down_duration" "2m")
    container_count=$(get_config "container_restart_count" "5")
    container_dur=$(get_config "container_restart_duration" "10m")

    cat > "$ALERTS_FILE" << EOF
groups:
  # === Host alerts (apply to all node-exporter targets: local + remote VMs) ===
  - name: host_alerts
    rules:
      - alert: HostDown
        expr: up{job=~"node-exporter|remote-node-exporters"} == 0
        for: ${host_down_dur}
        labels:
          severity: critical
        annotations:
          summary: "Host {{ \$labels.instance }} is unreachable"
          value: "{{ \$value }}"

      - alert: HighCPUWarning
        expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > ${cpu_warn}
        for: ${cpu_dur}
        labels:
          severity: warning
        annotations:
          summary: "CPU usage high on {{ \$labels.instance }}"
          value: "{{ \$value | printf \\"%.1f\\" }}%"

      - alert: HighCPUCritical
        expr: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > ${cpu_crit}
        for: ${cpu_dur}
        labels:
          severity: critical
        annotations:
          summary: "CPU usage critical on {{ \$labels.instance }}"
          value: "{{ \$value | printf \\"%.1f\\" }}%"

      - alert: HighMemoryWarning
        expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > ${mem_warn}
        for: ${mem_dur}
        labels:
          severity: warning
        annotations:
          summary: "Memory usage high on {{ \$labels.instance }}"
          value: "{{ \$value | printf \\"%.1f\\" }}%"

      - alert: HighMemoryCritical
        expr: (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100 > ${mem_crit}
        for: ${mem_dur}
        labels:
          severity: critical
        annotations:
          summary: "Memory usage critical on {{ \$labels.instance }}"
          value: "{{ \$value | printf \\"%.1f\\" }}%"

      - alert: HighDiskUsageWarning
        expr: (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|nsfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|nsfs|overlay"}) * 100 > ${disk_warn}
        for: ${disk_dur}
        labels:
          severity: warning
        annotations:
          summary: "Disk usage high on {{ \$labels.instance }} ({{ \$labels.mountpoint }})"
          value: "{{ \$value | printf \\"%.1f\\" }}%"

      - alert: HighDiskUsageCritical
        expr: (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|nsfs|overlay"} / node_filesystem_size_bytes{fstype!~"tmpfs|nsfs|overlay"}) * 100 > ${disk_crit}
        for: ${disk_dur}
        labels:
          severity: critical
        annotations:
          summary: "Disk usage critical on {{ \$labels.instance }} ({{ \$labels.mountpoint }})"
          value: "{{ \$value | printf \\"%.1f\\" }}%"

      - alert: HighDiskIO
        expr: avg by (instance) (irate(node_disk_io_time_seconds_total[5m])) * 100 > ${diskio_warn}
        for: ${diskio_dur}
        labels:
          severity: warning
        annotations:
          summary: "Disk I/O wait high on {{ \$labels.instance }}"
          value: "{{ \$value | printf \\"%.1f\\" }}%"

  # === Container alerts (local cAdvisor only) ===
  - name: container_alerts
    rules:
      - alert: ContainerRestarted
        expr: increase(container_restart_count{container_label_com_docker_compose_service!=""}[${container_dur}]) > ${container_count}
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ \$labels.container_label_com_docker_compose_service }} restarting repeatedly"
          value: "{{ \$value }} restarts in ${container_dur}"
EOF

    print_success "Generated $ALERTS_FILE"
}

# --- Generate alertmanager.yml from config ---
generate_alertmanager() {
    local default_channels critical_channels
    local group_wait group_interval repeat_interval

    default_channels=$(get_list_config "default_channels" "")
    critical_channels=$(get_list_config "critical_channels" "")
    group_wait=$(get_config "group_wait" "30s")
    group_interval=$(get_config "group_interval" "5m")
    repeat_interval=$(get_config "repeat_interval" "4h")

    if [ -z "$default_channels" ] && [ -z "$critical_channels" ]; then
        print_warning "No notification channels configured — generating null receiver"
        cat > "$ALERTMANAGER_FILE" << EOF
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'app', 'environment']
  group_wait: ${group_wait}
  group_interval: ${group_interval}
  repeat_interval: ${repeat_interval}
  receiver: 'null'

receivers:
  - name: 'null'
EOF
        print_success "Generated $ALERTMANAGER_FILE (null receiver)"
        return
    fi

    # Build receiver configs for default and critical
    local all_default_receivers=""
    local all_critical_receivers=""

    for ch in $default_channels; do
        all_default_receivers+="$(build_channel_config "$ch")
"
    done

    for ch in $critical_channels; do
        all_critical_receivers+="$(build_channel_config "$ch")
"
    done

    # Per-app routes and their receiver definitions
    local app_routes=""
    local app_receivers=""
    app_routes=$(build_app_routes)
    app_receivers=$(build_app_receivers)

    cat > "$ALERTMANAGER_FILE" << EOF
global:
  resolve_timeout: 5m

templates:
  - '/etc/alertmanager/templates/*.tmpl'

route:
  receiver: 'default'
  group_by: ['alertname', 'app', 'environment']
  group_wait: ${group_wait}
  group_interval: ${group_interval}
  repeat_interval: ${repeat_interval}
  routes:
    - match:
        severity: critical
      receiver: 'critical'
      group_wait: 10s
      repeat_interval: 1h
${app_routes}
receivers:
  - name: 'default'
${all_default_receivers}
  - name: 'critical'
${all_critical_receivers}
${app_receivers}
EOF

    print_success "Generated $ALERTMANAGER_FILE"
}

# Build a channel config block for a receiver
build_channel_config() {
    local channel="$1"
    local url token chat_id to from smarthost auth_user auth_pass

    case "$channel" in
        discord)
            url=$(get_config "discord_webhook_url" "")
            if [ -n "$url" ]; then
                # Discord supports Slack-compatible webhooks — append /slack
                if echo "$url" | grep -qv "/slack$"; then
                    url="${url}/slack"
                fi
                echo "    slack_configs:"
                echo "      - api_url: '${url}'"
                echo "        title: '{{ template \"slack.default.title\" . }}'"
                echo "        text: '{{ template \"slack.default.text\" . }}'"
                echo "        color: '{{ if eq .Status \"firing\" }}{{ if eq .CommonLabels.severity \"critical\" }}danger{{ else }}warning{{ end }}{{ else }}good{{ end }}'"
            fi
            ;;
        telegram)
            token=$(get_config "telegram_bot_token" "")
            chat_id=$(get_config "telegram_chat_id" "")
            if [ -n "$token" ] && [ -n "$chat_id" ]; then
                echo "    telegram_configs:"
                echo "      - bot_token: '${token}'"
                echo "        chat_id: ${chat_id}"
                echo "        parse_mode: 'Markdown'"
                echo "        message: '{{ template \"telegram.default.message\" . }}'"
            fi
            ;;
        slack)
            url=$(get_config "slack_webhook_url" "")
            if [ -n "$url" ]; then
                echo "    slack_configs:"
                echo "      - api_url: '${url}'"
                echo "        title: '{{ template \"slack.default.title\" . }}'"
                echo "        text: '{{ template \"slack.default.text\" . }}'"
                echo "        color: '{{ if eq .Status \"firing\" }}{{ if eq .CommonLabels.severity \"critical\" }}danger{{ else }}warning{{ end }}{{ else }}good{{ end }}'"
            fi
            ;;
        email)
            to=$(get_config "email_to" "")
            from=$(get_config "email_from" "")
            smarthost=$(get_config "email_smarthost" "")
            auth_user=$(get_config "email_auth_username" "")
            auth_pass=$(get_config "email_auth_password" "")
            if [ -n "$to" ] && [ -n "$from" ] && [ -n "$smarthost" ]; then
                echo "    email_configs:"
                echo "      - to: '${to}'"
                echo "        from: '${from}'"
                echo "        smarthost: '${smarthost}'"
                if [ -n "$auth_user" ]; then
                    echo "        auth_username: '${auth_user}'"
                fi
                if [ -n "$auth_pass" ]; then
                    echo "        auth_password: '${auth_pass}'"
                fi
                echo "        headers:"
                echo "          Subject: '{{ template \"email.default.subject\" . }}'"
                echo "        html: '{{ template \"email.default.html\" . }}'"
            fi
            ;;
        *)
            print_warning "Unknown channel type: $channel — skipping"
            ;;
    esac
}

# Build per-app routing entries from config
build_app_routes() {
    local config_content
    config_content=$(cat "$CONFIG_FILE" 2>/dev/null || echo "")

    # Look for lines like: "  my-app-name:" under a comment about per-app
    # Parse app sections from config
    local in_routing=false in_apps=false
    while IFS= read -r line; do
        if echo "$line" | grep -q "^routing:"; then
            in_routing=true
            continue
        fi
        if [ "$in_routing" = true ] && echo "$line" | grep -q "^  [a-z_]*:$"; then
            # Check if it's an app definition (not a known routing key)
            local key
            key=$(echo "$line" | sed 's/^  //; s/:$//')
            case "$key" in
                default_channels|critical_channels) continue ;;
            esac
            # This is an app route
            local app_channels
            app_channels=$(echo "$config_content" | grep -A5 "^  ${key}:" | grep "channels:" | head -1 | sed 's/.*channels: *//' | tr -d '[]' | sed 's/,/ /g')
            if [ -n "$app_channels" ]; then
                local receiver_name="app-${key}"
                echo "    - match:"
                echo "        app: '${key}'"
                echo "      receiver: '${receiver_name}'"
            fi
        fi
    done <<< "$config_content"
}

# Build per-app receiver blocks (companion to build_app_routes)
build_app_receivers() {
    local config_content
    config_content=$(cat "$CONFIG_FILE" 2>/dev/null || echo "")

    local in_routing=false
    while IFS= read -r line; do
        if echo "$line" | grep -q "^routing:"; then
            in_routing=true
            continue
        fi
        if [ "$in_routing" = true ] && echo "$line" | grep -q "^  [a-z_]*:$"; then
            local key
            key=$(echo "$line" | sed 's/^  //; s/:$//')
            case "$key" in
                default_channels|critical_channels) continue ;;
            esac
            local app_channels
            app_channels=$(echo "$config_content" | grep -A5 "^  ${key}:" | grep "channels:" | head -1 | sed 's/.*channels: *//' | tr -d '[]' | sed 's/,/ /g')
            if [ -n "$app_channels" ]; then
                local receiver_name="app-${key}"
                echo "  - name: '${receiver_name}'"
                for ch in $app_channels; do
                    echo "$(build_channel_config "$ch")"
                done
            fi
        fi
    done <<< "$config_content"
}

# --- Write config.yml ---
write_config() {
    cat > "$CONFIG_FILE" << EOF
# Alert Configuration — generated by ./alerts/setup.sh init
# Edit values below and run ./alerts/setup.sh generate to apply changes.
# This file contains credentials — it is gitignored.

# === Notification Channels ===
discord_enabled: ${DISCORD_ENABLED:-false}
discord_webhook_url: "${DISCORD_WEBHOOK_URL:-}"

telegram_enabled: ${TELEGRAM_ENABLED:-false}
telegram_bot_token: "${TELEGRAM_BOT_TOKEN:-}"
telegram_chat_id: "${TELEGRAM_CHAT_ID:-}"

slack_enabled: ${SLACK_ENABLED:-false}
slack_webhook_url: "${SLACK_WEBHOOK_URL:-}"

email_enabled: ${EMAIL_ENABLED:-false}
email_to: "${EMAIL_TO:-}"
email_from: "${EMAIL_FROM:-}"
email_smarthost: "${EMAIL_SMARTHOST:-}"
email_auth_username: "${EMAIL_AUTH_USER:-}"
email_auth_password: "${EMAIL_AUTH_PASS:-}"

# === Alert Thresholds ===
cpu_warning: ${CPU_WARNING:-80}
cpu_critical: ${CPU_CRITICAL:-95}
cpu_duration: ${CPU_DURATION:-5m}

memory_warning: ${MEMORY_WARNING:-80}
memory_critical: ${MEMORY_CRITICAL:-95}
memory_duration: ${MEMORY_DURATION:-5m}

disk_warning: ${DISK_WARNING:-85}
disk_critical: ${DISK_CRITICAL:-95}
disk_duration: ${DISK_DURATION:-5m}

disk_io_warning: ${DISK_IO_WARNING:-10}
disk_io_duration: ${DISK_IO_DURATION:-5m}

host_down_duration: ${HOST_DOWN_DURATION:-2m}

container_restart_count: ${CONTAINER_RESTART_COUNT:-5}
container_restart_duration: ${CONTAINER_RESTART_DURATION:-10m}

# === Routing ===
default_channels: [${DEFAULT_CHANNELS:-}]
critical_channels: [${CRITICAL_CHANNELS:-}]

# Per-app routing overrides (add your apps below):
#   app-name:
#     channels: [discord, telegram]
#
# my-app-A:
#   channels: [discord]

# === Timing ===
group_wait: ${GROUP_WAIT:-30s}
group_interval: ${GROUP_INTERVAL:-5m}
repeat_interval: ${REPEAT_INTERVAL:-4h}
EOF
    print_success "Generated $CONFIG_FILE"
}

# --- Init wizard ---
cmd_init() {
    local use_defaults=false
    if [[ "${1:-}" == "--defaults" ]]; then
        use_defaults=true
    fi

    echo ""
    echo "============================================"
    echo "  Alert Configuration — Setup Wizard"
    echo "============================================"
    echo ""
    print_info "This wizard will configure:"
    print_info "  1. Notification channels (where alerts are sent)"
    print_info "  2. Alert thresholds (when alerts trigger)"
    print_info "  3. Routing rules (which alerts go where)"
    echo ""

    # --- Step 1: Notification Channels ---
    print_step "Step 1: Notification Channels"
    echo ""

    DISCORD_ENABLED=false
    TELEGRAM_ENABLED=false
    SLACK_ENABLED=false
    EMAIL_ENABLED=false

    if prompt_yesno "Enable Discord notifications?" "n"; then
        DISCORD_ENABLED=true
        DISCORD_WEBHOOK_URL=$(prompt "  Discord webhook URL" "")
        if [ -z "$DISCORD_WEBHOOK_URL" ]; then
            print_warning "No URL provided — Discord will be disabled"
            DISCORD_ENABLED=false
        fi
        echo ""
    fi

    if prompt_yesno "Enable Telegram notifications?" "n"; then
        TELEGRAM_ENABLED=true
        TELEGRAM_BOT_TOKEN=$(prompt "  Telegram bot token (from @BotFather)" "")
        TELEGRAM_CHAT_ID=$(prompt "  Telegram chat ID" "")
        if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
            print_warning "Missing token or chat ID — Telegram will be disabled"
            TELEGRAM_ENABLED=false
        fi
        echo ""
    fi

    if prompt_yesno "Enable Slack notifications?" "n"; then
        SLACK_ENABLED=true
        SLACK_WEBHOOK_URL=$(prompt "  Slack webhook URL" "")
        if [ -z "$SLACK_WEBHOOK_URL" ]; then
            print_warning "No URL provided — Slack will be disabled"
            SLACK_ENABLED=false
        fi
        echo ""
    fi

    if prompt_yesno "Enable Email notifications?" "n"; then
        EMAIL_ENABLED=true
        EMAIL_TO=$(prompt "  Recipient email (to)" "")
        EMAIL_FROM=$(prompt "  Sender email (from)" "alertmanager@localhost")
        EMAIL_SMARTHOST=$(prompt "  SMTP server (host:port)" "smtp.gmail.com:587")
        EMAIL_AUTH_USER=$(prompt "  SMTP username" "")
        EMAIL_AUTH_PASS=$(prompt "  SMTP password" "")
        if [ -z "$EMAIL_TO" ]; then
            print_warning "No recipient — Email will be disabled"
            EMAIL_ENABLED=false
        fi
        echo ""
    fi

    # Verify at least one channel is enabled
    local any_enabled=false
    $DISCORD_ENABLED && any_enabled=true
    $TELEGRAM_ENABLED && any_enabled=true
    $SLACK_ENABLED && any_enabled=true
    $EMAIL_ENABLED && any_enabled=true

    if ! $any_enabled; then
        print_error "No notification channels enabled. At least one is required."
        print_info "Run './alerts/setup.sh init' again to retry."
        exit 1
    fi

    # --- Step 2: Thresholds ---
    print_step "Step 2: Alert Thresholds"
    echo ""
    print_info "Default thresholds (press Enter to accept):"

    CPU_WARNING=$(prompt "  CPU warning %" "80")
    CPU_CRITICAL=$(prompt "  CPU critical %" "95")
    CPU_DURATION=$(prompt "  CPU duration" "5m")
    echo ""

    MEMORY_WARNING=$(prompt "  Memory warning %" "80")
    MEMORY_CRITICAL=$(prompt "  Memory critical %" "95")
    MEMORY_DURATION=$(prompt "  Memory duration" "5m")
    echo ""

    DISK_WARNING=$(prompt "  Disk usage warning %" "85")
    DISK_CRITICAL=$(prompt "  Disk usage critical %" "95")
    DISK_DURATION=$(prompt "  Disk duration" "5m")
    echo ""

    DISK_IO_WARNING=$(prompt "  Disk I/O wait warning %" "10")
    DISK_IO_DURATION=$(prompt "  Disk I/O duration" "5m")
    echo ""

    HOST_DOWN_DURATION=$(prompt "  Host down alert after" "2m")
    echo ""

    CONTAINER_RESTART_COUNT=$(prompt "  Container restart threshold (count)" "5")
    CONTAINER_RESTART_DURATION=$(prompt "  Container restart window" "10m")
    echo ""

    # --- Step 3: Routing ---
    print_step "Step 3: Alert Routing"
    echo ""
    print_info "Which channels should receive alerts?"
    echo ""

    local available=""
    $DISCORD_ENABLED && available+="discord "
    $TELEGRAM_ENABLED && available+="telegram "
    $SLACK_ENABLED && available+="slack "
    $EMAIL_ENABLED && available+="email "

    DEFAULT_CHANNELS=$(prompt "  Default channels for all alerts" "$(echo $available | awk '{print $1}')")
    CRITICAL_CHANNELS=$(prompt "  Extra channels for CRITICAL alerts" "$(echo $available | tr '\n' ' ' | sed 's/ $//')")
    echo ""

    # --- Step 4: Timing ---
    print_step "Step 4: Notification Timing"
    echo ""

    GROUP_WAIT=$(prompt "  Group wait (delay before first notification)" "30s")
    GROUP_INTERVAL=$(prompt "  Group interval (between updates)" "5m")
    REPEAT_INTERVAL=$(prompt "  Repeat interval (reminder frequency)" "4h")
    echo ""

    # --- Generate ---
    print_step "Generating configuration files..."
    echo ""

    write_config
    generate_alerts
    generate_alertmanager

    echo ""
    print_success "Alert configuration complete!"
    echo ""
    print_info "Next steps:"
    print_info "  1. Restart AlertManager (picks up new channels):"
    print_info "     docker compose up -d --force-recreate alertmanager"
    print_info ""
    print_info "  2. Restart Prometheus (picks up new rules):"
    print_info "     docker compose restart prometheus"
    echo ""
    print_info "  3. Test notifications:"
    print_info "     ./alerts/setup.sh test"
    echo ""
    print_info "  4. View alerts in Prometheus:"
    print_info "     http://localhost:9090/alerts"
    echo ""
    print_info "Later changes: edit alerts/config.yml then run ./alerts/setup.sh generate"
}

# --- Generate command ---
cmd_generate() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "No config found. Run './alerts/setup.sh init' first."
        exit 1
    fi

    print_info "Regenerating from $CONFIG_FILE..."
    generate_alerts
    generate_alertmanager
    echo ""
    print_success "Done. Restart services to apply:"
    print_info "  docker compose up -d --force-recreate alertmanager"
    print_info "  docker compose restart prometheus"
}

# --- Add channel ---
cmd_add_channel() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "No config found. Run './alerts/setup.sh init' first."
        exit 1
    fi

    echo ""
    echo "Available channels: discord, telegram, slack, email"
    echo ""
    local channel
    channel=$(prompt "Channel type to add/update" "")
    echo ""

    case "$channel" in
        discord)
            local url
            url=$(prompt "Discord webhook URL" "$(get_config 'discord_webhook_url')")
            sed -i "s/^discord_enabled:.*/discord_enabled: true/" "$CONFIG_FILE"
            sed -i "s|^discord_webhook_url:.*|discord_webhook_url: \"${url}\"|" "$CONFIG_FILE"
            print_success "Discord channel configured"
            ;;
        telegram)
            local token chat_id
            token=$(prompt "Telegram bot token" "$(get_config 'telegram_bot_token')")
            chat_id=$(prompt "Telegram chat ID" "$(get_config 'telegram_chat_id')")
            sed -i "s/^telegram_enabled:.*/telegram_enabled: true/" "$CONFIG_FILE"
            sed -i "s|^telegram_bot_token:.*|telegram_bot_token: \"${token}\"|" "$CONFIG_FILE"
            sed -i "s|^telegram_chat_id:.*|telegram_chat_id: \"${chat_id}\"|" "$CONFIG_FILE"
            print_success "Telegram channel configured"
            ;;
        slack)
            local url
            url=$(prompt "Slack webhook URL" "$(get_config 'slack_webhook_url')")
            sed -i "s/^slack_enabled:.*/slack_enabled: true/" "$CONFIG_FILE"
            sed -i "s|^slack_webhook_url:.*|slack_webhook_url: \"${url}\"|" "$CONFIG_FILE"
            print_success "Slack channel configured"
            ;;
        email)
            local to from smarthost user pass
            to=$(prompt "Recipient email" "$(get_config 'email_to')")
            from=$(prompt "Sender email" "$(get_config 'email_from')")
            smarthost=$(prompt "SMTP server (host:port)" "$(get_config 'email_smarthost')")
            user=$(prompt "SMTP username" "$(get_config 'email_auth_username')")
            pass=$(prompt "SMTP password" "$(get_config 'email_auth_password')")
            sed -i "s/^email_enabled:.*/email_enabled: true/" "$CONFIG_FILE"
            sed -i "s|^email_to:.*|email_to: \"${to}\"|" "$CONFIG_FILE"
            sed -i "s|^email_from:.*|email_from: \"${from}\"|" "$CONFIG_FILE"
            sed -i "s|^email_smarthost:.*|email_smarthost: \"${smarthost}\"|" "$CONFIG_FILE"
            sed -i "s|^email_auth_username:.*|email_auth_username: \"${user}\"|" "$CONFIG_FILE"
            sed -i "s|^email_auth_password:.*|email_auth_password: \"${pass}\"|" "$CONFIG_FILE"
            print_success "Email channel configured"
            ;;
        *)
            print_error "Unknown channel: $channel"
            print_info "Available: discord, telegram, slack, email"
            exit 1
            ;;
    esac

    echo ""
    print_info "Regenerating alert configs..."
    generate_alertmanager
    echo ""
    print_success "Done. Restart AlertManager to apply:"
    print_info "  docker compose up -d --force-recreate alertmanager"
}

# --- Add custom rule ---
cmd_add_rule() {
    if [ ! -f "$ALERTS_FILE" ]; then
        print_error "No alerts.yml found. Run './alerts/setup.sh init' first."
        exit 1
    fi

    echo ""
    print_info "Add a custom Prometheus alert rule."
    print_info "You need a PromQL expression (the 'expr' field)."
    print_info "See: https://prometheus.io/docs/prometheus/latest/querying/basics/"
    echo ""

    local name expr severity duration summary
    name=$(prompt "Alert name (PascalCase, e.g. HighSwapUsage)" "")
    if [ -z "$name" ]; then
        print_error "Alert name is required"
        exit 1
    fi

    expr=$(prompt "PromQL expression" "")
    if [ -z "$expr" ]; then
        print_error "PromQL expression is required"
        exit 1
    fi

    severity=$(prompt "Severity (warning/critical)" "warning")
    duration=$(prompt "Duration (e.g. 5m)" "5m")
    summary=$(prompt "Summary (describe the alert)" "$name on {{ \$labels.instance }}")

    echo ""
    echo "--- Preview ---"
    echo "  - alert: $name"
    echo "    expr: $expr"
    echo "    for: $duration"
    echo "    severity: $severity"
    echo "    summary: \"$summary\""
    echo ""

    if ! prompt_yesno "Add this rule?" "y"; then
        print_info "Cancelled"
        return
    fi

    # Append to the first alert group (host_alerts)
    local rule_block
    rule_block=$(cat << RULE

      - alert: ${name}
        expr: ${expr}
        for: ${duration}
        labels:
          severity: ${severity}
        annotations:
          summary: "${summary}"
          value: "{{ \$value }}"
RULE
)

    # Insert before the container_alerts group (or at end)
    if grep -q "container_alerts" "$ALERTS_FILE"; then
        local tmp_file
        tmp_file=$(mktemp)
        awk -v rule="$rule_block" '/^  # === Container alerts/{print rule} {print}' "$ALERTS_FILE" > "$tmp_file" && mv "$tmp_file" "$ALERTS_FILE"
    else
        echo "$rule_block" >> "$ALERTS_FILE"
    fi

    print_success "Added rule: $name"
    echo ""
    print_info "Restart Prometheus to apply:"
    print_info "  docker compose restart prometheus"
}

# --- Status ---
cmd_status() {
    echo ""
    echo "Alert Configuration Status"
    echo "==========================="
    echo ""

    if [ -f "$CONFIG_FILE" ]; then
        print_success "Config file: $CONFIG_FILE"
        echo ""
        echo "Channels:"
        for ch in discord telegram slack email; do
            local enabled
            enabled=$(get_config "${ch}_enabled" "false")
            if [ "$enabled" = "true" ]; then
                print_success "  $ch — enabled"
            else
                print_info "  $ch — disabled"
            fi
        done

        echo ""
        echo "Thresholds:"
        echo "  CPU:      warning $(get_config cpu_warning "?")% / critical $(get_config cpu_critical "?")% / duration $(get_config cpu_duration "?")"
        echo "  Memory:   warning $(get_config memory_warning "?")% / critical $(get_config memory_critical "?")% / duration $(get_config memory_duration "?")"
        echo "  Disk:     warning $(get_config disk_warning "?")% / critical $(get_config disk_critical "?")% / duration $(get_config disk_duration "?")"
        echo "  Disk IO:  warning $(get_config disk_io_warning "?")% / duration $(get_config disk_io_duration "?")"
        echo "  Host down after: $(get_config host_down_duration "?")"
        echo "  Container restarts: $(get_config container_restart_count "?") in $(get_config container_restart_duration "?")"

        echo ""
        echo "Routing:"
        local def_ch crit_ch
        def_ch=$(get_list_config default_channels)
        crit_ch=$(get_list_config critical_channels)
        echo "  Default channels: ${def_ch:-none}"
        echo "  Critical channels: ${crit_ch:-none}"

        echo ""
        echo "Timing:"
        echo "  Group wait: $(get_config group_wait '?') / interval: $(get_config group_interval '?') / repeat: $(get_config repeat_interval '?')"
    else
        print_warning "No config file found — run './alerts/setup.sh init' first"
    fi

    echo ""
    if [ -f "$ALERTS_FILE" ]; then
        local rule_count
        rule_count=$(grep -c "^      - alert:" "$ALERTS_FILE" 2>/dev/null || echo "0")
        print_success "Alert rules: $rule_count rules in $ALERTS_FILE"
    else
        print_warning "No alerts.yml found"
    fi

    if [ -f "$ALERTMANAGER_FILE" ]; then
        local has_null
        has_null=$(grep -c "name: 'null'" "$ALERTMANAGER_FILE" 2>/dev/null || echo "0")
        if [ "$has_null" -gt 0 ]; then
            print_warning "AlertManager: null receiver (no notifications configured)"
        else
            print_success "AlertManager: notification channels configured"
        fi
    else
        print_warning "No alertmanager.yml found"
    fi

    echo ""

    # Check if services are running
    if command -v docker &>/dev/null; then
        local am_status pStatus
        am_status=$(docker ps --filter "name=alertmanager" --format "{{.Status}}" 2>/dev/null | head -1 || echo "")
        pStatus=$(docker ps --filter "name=prometheus" --format "{{.Status}}" 2>/dev/null | head -1 || echo "")
        echo "Services:"
        if [ -n "$pStatus" ]; then
            print_success "  Prometheus: $pStatus"
        else
            print_warning "  Prometheus: not running"
        fi
        if [ -n "$am_status" ]; then
            print_success "  AlertManager: $am_status"
        else
            print_warning "  AlertManager: not running"
        fi
    fi
}

# --- Test ---
cmd_test() {
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "No config found. Run './alerts/setup.sh init' first."
        exit 1
    fi

    local has_channels
    has_channels=$(get_list_config "default_channels" "")
    if [ -z "$has_channels" ]; then
        print_error "No channels configured. Run './alerts/setup.sh add-channel' first."
        exit 1
    fi

    print_info "Checking if AlertManager is running..."
    local am_running=false
    if curl -sf "http://localhost:9093/-/healthy" >/dev/null 2>&1; then
        am_running=true
        print_success "AlertManager is running"
    else
        print_error "AlertManager is not reachable at http://localhost:9093"
        print_info "Start it with: docker compose up -d alertmanager"
        exit 1
    fi

    print_info "Sending test alert..."
    echo ""

    # Send a test alert via AlertManager API
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

    local test_payload
    test_payload=$(cat << EOF
[{
  "labels": {
    "alertname": "TestAlert",
    "severity": "warning",
    "instance": "test-host",
    "test": "true"
  },
  "annotations": {
    "summary": "This is a test alert from ./alerts/setup.sh test",
    "value": "test"
  },
  "startsAt": "${timestamp}",
  "endsAt": "$(date -u -d '+5 minutes' +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -v+5M +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || echo "${timestamp}")"
}]
EOF
)

    local response
    response=$(curl -s -w "\n%{http_code}" -X POST "http://localhost:9093/api/v2/alerts" \
        -H "Content-Type: application/json" \
        -d "$test_payload" 2>&1) || true

    local http_code
    http_code=$(echo "$response" | tail -1)

    if [ "$http_code" = "200" ]; then
        print_success "Test alert sent to AlertManager"
        echo ""
        print_info "Check your configured channels for the test notification:"
        local channels
        channels=$(get_list_config "default_channels" "")
        for ch in $channels; do
            print_info "  - $ch"
        done
        echo ""
        print_info "The test alert auto-resolves in 5 minutes."
        print_info "View at: http://localhost:9093/#/alerts"
    else
        print_error "Failed to send test alert (HTTP $http_code)"
        print_info "Response: $(echo "$response" | head -1)"
        exit 1
    fi
}

# --- Main ---
COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
    help|-h|--help)
        cmd_help
        ;;
    init)
        cmd_init "$@"
        ;;
    generate)
        cmd_generate
        ;;
    add-channel)
        cmd_add_channel
        ;;
    add-rule)
        cmd_add_rule
        ;;
    status)
        cmd_status
        ;;
    test)
        cmd_test
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        echo "Run './alerts/setup.sh help' for usage."
        exit 1
        ;;
esac
