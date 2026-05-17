# Environment Guide — vm-monit

Populated from the Phase 1 audit with real, verified commands and configuration.

---

## Environment Definitions

| Environment | Purpose | Characteristics |
|---|---|---|
| `development` | Local development and configuration changes | All services running locally, default credentials, debug logging on AlertManager, no TLS |
| `staging` | Pre-production validation (not yet configured) | Would mirror production config with sandboxed services |
| `production` | Live monitoring (not yet configured) | Would require TLS, auth, resource limits, notification receivers, network isolation |

> **Note:** The current codebase has **no environment differentiation**. All configuration is development-oriented. Staging and production would require additional configuration (TLS, auth, resource limits, network isolation) that does not yet exist.

---

## Agent Behavior by Environment

### In `development` (current state):
- All services run locally via Docker Compose
- Default Grafana credentials (admin/admin) are active
- AlertManager debug logging is enabled
- All ports are exposed on localhost
- Seed data and test configurations are safe to modify
- `./setup.sh`, `./stop.sh`, `./update.sh` can be run freely

### In `staging` or `production` (future state):
- **Never run destructive commands** (`./stop.sh --all`, `docker compose down -v`) without explicit written confirmation
- **Never modify** production config files or secrets directly
- **Present a written plan** before executing any change
- **Flag explicitly** when operating in a non-development context

---

## Verified Commands

### Start Development Environment

```bash
# Full setup (recommended first time): creates dirs, sets permissions, pulls images, starts services, waits for health
./setup.sh

# Quick setup (skip image pull and validation):
./setup.sh --quick

# Skip image pull only:
./setup.sh --skip-pull

# Manual start (if dirs and permissions already exist):
docker compose up -d
```

### Stop Services

```bash
# Stop and remove containers (default — preserves data):
./stop.sh

# Stop services only (keep containers):
./stop.sh -s

# Stop, remove containers, and remove volumes (destroys data):
./stop.sh -v

# Complete cleanup (containers, volumes, networks, images, data):
./stop.sh --all

# Show current status:
./stop.sh --status
```

### Update Services

```bash
# Standard update (pull images, restart, verify):
./update.sh

# Rolling update (one service at a time):
./update.sh -r

# Show current status:
./update.sh --status

# Show current versions:
./update.sh -v

# Pull latest images only:
./update.sh -p

# Update with backup and health verification:
./update.sh --backup --verify

# Show recent logs after update:
./update.sh --logs

# Clean up old Docker images after update:
./update.sh --cleanup
```

### Verify Environment Health

```bash
# Full health check (all services):
./update.sh --verify

# Docker Compose status:
docker compose ps

# Individual health endpoints:
curl -f http://localhost:9090/-/healthy    # Prometheus
curl -f http://localhost:3000/api/health   # Grafana
curl -f http://localhost:9093/-/healthy    # AlertManager
curl -f http://localhost:3100/ready        # Loki
curl -f http://localhost:12345/metrics     # Alloy
curl -f http://localhost:9100/metrics      # Node Exporter
curl -f http://localhost:8080/healthz      # cAdvisor
curl -f http://localhost:9115/-/healthy    # Blackbox Exporter
```

### Validate Configuration

```bash
# Validate Docker Compose config:
docker compose config

# Validate Prometheus config (requires promtool):
promtool check config prometheus.yaml

# Validate alert rules (requires promtool):
promtool check rules alerts.yml
```

### Maintenance

```bash
# Combined maintenance (backup + data retention):
./scripts/maintenance.sh

# Backup only:
./scripts/backup.sh

# Data retention (archive old Prometheus data, clean old archives):
./scripts/data-retention.sh

# List available backups:
./scripts/restore.sh list

# Restore Grafana from backup:
./scripts/restore.sh grafana ./backups/grafana_2025-01-15.tar.gz

# Restore Prometheus config from backup:
./scripts/restore.sh prometheus-config ./backups/prometheus_config_2025-01-15.tar.gz

# Restore Prometheus data from backup:
./scripts/restore.sh prometheus-data ./backups/prometheus_recent_2025-01-15.tar.gz
```

---

## Docker Compose Environment Pattern

### Single Unified Configuration

This project uses a **single `compose.yaml`** file for all platforms (Linux, macOS, Windows/WSL). There are no `docker-compose.override.yml` or `docker-compose.prod.yml` files.

### Service Dependencies (implicit, not via `depends_on`)

The startup order in `setup.sh` enforces dependencies:
1. **node-exporter, cadvisor** — no dependencies, start first
2. **prometheus, alertmanager** — depend on exporters being available for scraping
3. **loki, alloy** — Alloy depends on Loki being available for log shipping
4. **blackbox_exporter** — no dependencies
5. **grafana** — depends on Prometheus and Loki datasources being available

### Networks

- **Default network**: All services share the default Docker Compose network
- **monitoring-network**: Created by `setup.sh` for external exporter integration (optional)

### Volumes

All data is stored in **bind mounts** to the host filesystem (not Docker named volumes):
- `./data/prometheus` → `/prometheus` (Prometheus TSDB)
- `./data/grafana` → `/var/lib/grafana` (Grafana database)
- `./data/loki` → `/loki` (Loki chunks)
- `./data/alloy_data` → `/var/lib/alloy/data` (Alloy persistent data)

---

## `.env` File Pattern

```
.example.env        # Committed — all keys with placeholder values + description comments
.env                # Never committed — actual development secrets (gitignored)
```

### `.example.env` Contents

```bash
# GRAFANA base configuration
GRAFANA_ADMIN_USER=
GRAFANA_ADMIN_PASSWORD=

# POSTGRES Configuration if need to monitor a POSTGRES database
POSTGRES_USER=
POSTGRES_PASS=
POSTGRES_DB=
POSTGRES_PORT=
POSTGRES_HOST=
```

### `.gitignore` Status

**`.env` is correctly excluded** from version control. The `.gitignore` contains:

```
# folders
data
logs
archives
backups

# files
.env
```

---

## Known Gotchas

1. **Journal log source in Alloy**: On Windows/WSL, the `loki.source.journal` component will fail because systemd journal is not available. Comment it out in `alloy/alloy-config.alloy` for Windows/WSL setups.

2. **Node Exporter filesystem metrics with Alloy**: When using Alloy instead of traditional node-exporter, the Node Exporter Full dashboard (ID: 1860) may show "N/A" for filesystem metrics due to different mountpoint labeling. Use the Node Exporter Server Metrics dashboard (ID: 11076) instead.

3. **Permission issues on data directories**: The `setup.sh` script uses `sudo chown` to set correct ownership for each service's data directory. If running without sudo, you may need to set permissions manually:
   - Prometheus: `sudo chown -R 65534:65534 data/prometheus`
   - Grafana: `sudo chown -R 472:472 data/grafana`
   - Loki: `sudo chown -R 10001:10001 data/loki`
   - Alloy: `sudo chown -R 0:0 data/alloy_data`

4. **cAdvisor on macOS**: cAdvisor has limited functionality on macOS because it relies on Linux-specific kernel features. Container metrics may be incomplete.

5. **Prometheus `--web.enable-lifecycle`**: This flag allows reloading config via HTTP POST to `/-/reload`. Useful for development but should be disabled or protected in production.

6. **AlertManager null receiver**: Alerts fire but are not delivered anywhere. Configure actual receivers in `alertmanager.yml` before relying on alerts.
