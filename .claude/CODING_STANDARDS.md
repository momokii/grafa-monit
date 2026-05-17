# Coding Standards — vm-monit

Conventions derived from the actual codebase observed during the Phase 1 audit. All new code must follow these patterns.

---

## Project Structure Rules

### Where new files go

| File Type | Location | Example |
|---|---|---|
| Docker Compose service config | Root level | `compose.yaml` |
| Prometheus config | Root level | `prometheus.yaml` |
| Alert rules | Root level | `alerts.yml` |
| AlertManager config | Root level | `alertmanager.yml` |
| Service-specific config | `<service>/` directory | `loki/loki-config.yaml` |
| Grafana provisioning | `grafana/provisioning/<type>/` | `grafana/provisioning/dashboards/my-dashboard.json` |
| Maintenance/utility scripts | `scripts/` | `scripts/backup.sh` |
| Root-level management scripts | Root level | `setup.sh`, `stop.sh`, `update.sh` |
| Environment template | Root level | `.example.env` |
| Alloy log collection config | `alloy/` | `alloy/alloy-config.alloy` |
| Blackbox probe modules | `blackbox_exporter/` | `blackbox_exporter/blackbox_exporter.yaml` |
| Remote exporter deployment | `exporter-centralized/<exporter>/` | `exporter-centralized/node-exporter/setup.sh` |

### Data directories (gitignored, created by setup.sh)

- `data/prometheus/` — Prometheus TSDB data
- `data/grafana/` — Grafana database and plugins
- `data/loki/` — Loki chunks and index
- `data/alloy_data/` — Alloy persistent storage
- `logs/` — Application logs (grafana/, alertmanager/, prometheus/)
- `archives/` — Archived Prometheus data
- `backups/` — Timestamped backups

---

## Naming Conventions

### Files
- **Config files**: `kebab-case.yaml` or `kebab-case.yml` (e.g., `loki-config.yaml`, `blackbox_exporter.yaml`)
- **Alloy configs**: `kebab-case.alloy` (e.g., `alloy-config.alloy`)
- **Shell scripts**: `descriptive-name.sh` (e.g., `data-retention.sh`, `backup.sh`)
- **Grafana dashboards**: `<grafana-dashboard-id>.json` (e.g., `1860.json`, `11076.json`)
- **Environment template**: `.example.env`

### Variables in Bash scripts
- **Constants/parameters**: `UPPER_SNAKE_CASE` (e.g., `BACKUP_DIR`, `DATA_DIR`, `RETENTION_DAYS`)
- **Local variables**: `snake_case` (e.g., `backup_file`, `temp_backup`, `date`)
- **Function names**: `snake_case` (e.g., `print_info`, `check_docker`, `start_services`)

### Docker service names
- **kebab-case** (e.g., `node-exporter`, `blackbox_exporter`, `postgres_exporter`)

### Prometheus job names
- **snake_case** in quotes (e.g., `'node-exporter'`, `'cadvisor'`, `'blackbox'`)

### Alert names
- **PascalCase** (e.g., `InstanceDown`, `HighCPULoad`, `HighMemoryLoad`, `HighDiskUsage`)

### Alloy component names
- **snake_case** in quotes (e.g., `"default"`, `"journal"`, `"system"`, `"dockerlogs"`)

---

## Bash Script Conventions

All bash scripts in this project follow a consistent pattern:

### 1. Colored output functions (always at top)

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
print_step()    { echo -e "${PURPLE}[STEP]${NC} $1"; }
```

### 2. Function-based structure

- All logic organized into named functions
- Each function has a single responsibility
- Functions called from `main()`

### 3. Argument parsing

```bash
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)    show_usage; exit 0 ;;
        --some-flag)  some_flag=true; shift ;;
        *)            print_error "Unknown option: $1"; show_usage; exit 1 ;;
    esac
done
```

### 4. Entry point

```bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
```

### 5. Docker Compose commands

- Use `docker compose` (v2 syntax, space not hyphen) in `compose.yaml` context
- Use `docker-compose` (v1 syntax, hyphen) in `restore.sh` (legacy — consider updating)
- Always specify `-f compose.yaml` when not in the project root directory

---

## YAML Configuration Conventions

### Service definitions in compose.yaml
- Image versions **must be pinned** (e.g., `prom/prometheus:v2.47.0`, not `prom/prometheus:latest`)
- Exception: `cAdvisor` uses `zcube/cadvisor:latest` with a comment noting the alternative
- All services have `container_name`, `restart: unless-stopped`, and `healthcheck`
- Volume mounts use explicit `type: bind` with `read_only: true` where applicable
- Port mappings use quoted strings: `"9090:9090"`

### Prometheus config
- `scrape_interval`, `evaluation_interval`, `scrape_timeout` at global level
- Rule files referenced: `rule_files: ["alerts.yml"]`
- AlertManager target: `alertmanagers: [targets: ['alertmanager:9093']]`

### Alert rules
- Group name: `snake_case` (e.g., `host_alerts`)
- Alert name: `PascalCase` (e.g., `InstanceDown`)
- Required fields: `expr`, `for`, `labels.severity`, `annotations.summary`, `annotations.description`
- Severity values: `critical`, `warning`

---

## Alloy Configuration Conventions

- Comments use `//` for single-line and `/* */` for block comments
- Section separators: `// ! ====================== SECTION NAME`
- Disabled/experimental blocks: commented out with `//` and include explanation comments
- Component naming: descriptive snake_case (e.g., `loki.source.docker "default"`)
- All `forward_to` must reference a valid receiver

---

## Grafana Dashboard Conventions

- Dashboard JSON files named by Grafana dashboard ID (e.g., `1860.json`)
- Custom dashboards use descriptive names (e.g., `alerts.json`, `nginx.json`, `redis.json`)
- All dashboards are auto-provisioned via `grafana/provisioning/dashboards/dashboard.yml`
- Provider config: `disableDeletion: false`, `updateIntervalSeconds: 10`, `allowUiUpdates: true`

---

## Error Handling

### Bash scripts
- Use `exit 1` on fatal errors with a `print_error` message
- Use `print_warning` for non-fatal issues that should be noted
- Use `return 1` from functions to propagate errors to caller
- Docker command failures checked with `if ! docker ...; then print_error "..."; exit 1; fi`

### Prometheus/AlertManager
- Config validation via `promtool check config` and `promtool check rules`
- Invalid configs cause service startup failure (Docker healthcheck catches this)

---

## Logging

- **Grafana**: Configured to log to both console and file (`GF_LOG_MODE=console file`, level `info`)
- **AlertManager**: Debug level logging (`--log.level=debug`)
- **Blackbox Exporter**: Info level logging (`--log.level=info`)
- **Bash scripts**: Colored output via `print_*` functions — no file logging in scripts themselves
- **Never log**: environment variable values, credentials, tokens, or secrets

---

## Testing

This project has **no automated test framework**. It is an infrastructure-as-configuration project.

### Verification approach
- **Config validation**: `promtool check config prometheus.yaml`, `promtool check rules alerts.yml`
- **Compose validation**: `docker compose config`
- **Health checks**: Docker Compose healthchecks on all services
- **Manual verification**: `curl` health endpoints, `docker compose ps`, `docker logs <service>`

### What must be verified before committing changes
1. `docker compose config` — valid Compose syntax
2. `promtool check config prometheus.yaml` — valid Prometheus config (if promtool available)
3. `promtool check rules alerts.yml` — valid alert rules (if promtool available)
4. Services start successfully: `docker compose up -d`
5. Health checks pass: `./update.sh --verify`

---

## Patterns to Follow

### Service startup order (from setup.sh)
1. Metrics exporters (node-exporter, cadvisor)
2. Core monitoring (prometheus, alertmanager)
3. Log aggregation (loki, alloy)
4. Probe monitoring (blackbox_exporter)
5. Visualization (grafana)

### Service shutdown order (from stop.sh) — reverse of startup
alloy → loki → grafana → blackbox_exporter → alertmanager → prometheus → cadvisor → node-exporter

### Adding a new exporter
1. Add service to `compose.yaml` with image, ports, volumes, healthcheck
2. Add scrape job to `prometheus.yaml` (if it exposes metrics)
3. Add datasource to `grafana/provisioning/datasources/datasource.yml` (if Grafana needs it)
4. Add dashboard JSON to `grafana/provisioning/dashboards/` (if visualization needed)
5. Add startup to `setup.sh` and shutdown to `stop.sh`
6. Add health check to `update.sh`
7. Document in README.md

### Adding a new alert
1. Add rule to `alerts.yml` under the appropriate group
2. Ensure AlertManager has a configured receiver (currently null — needs setup)
3. Test with `promtool check rules alerts.yml`

---

## Patterns Explicitly Forbidden

- **Never use `:latest` tag** for Docker images (except cAdvisor which already does — do not add more)
- **Never store secrets in config files** — use environment variables from `.env`
- **Never remove healthchecks** from existing services
- **Never change volume mount paths** without understanding the data migration implications
- **Never modify existing dashboard JSON files** without understanding the Grafana provisioning flow
- **Never introduce `privileged: true`** on new containers without explicit user approval
- **Never expose debug ports or development tooling** in production-facing configuration

---

## Dependencies

This project uses **Docker images as dependencies** — no package manager (npm, pip, cargo, etc.).

### Adding a new Docker image
1. Pin to a specific version tag (e.g., `grafana/grafana:12.1.1`)
2. Check for known CVEs at https://github.com/advisories or the image's security page
3. Document the check in `state/DECISIONS_LOG.md`
4. Add to `stop.sh` image removal list if applicable

### Current image versions (pinned)
| Service | Image | Version |
|---|---|---|
| Node Exporter | prom/node-exporter | v1.6.1 |
| cAdvisor | zcube/cadvisor | latest (⚠️ unpinned) |
| Prometheus | prom/prometheus | v2.47.0 |
| Grafana | grafana/grafana | 12.1.1 |
| AlertManager | prom/alertmanager | v0.28.1 |
| Loki | grafana/loki | 3.3.2 |
| Alloy | grafana/alloy | v1.9.1 |
| Blackbox Exporter | prom/blackbox-exporter | v0.27.0 |
