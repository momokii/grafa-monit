# vm-monit — Claude Code Agent Infrastructure

## What This Project Is

**Grafana Host Monitoring Stack** — a complete, containerized observability solution for host systems and Docker containers. It combines metrics collection (Prometheus + exporters), log aggregation (Loki + Alloy), visualization (Grafana), and alerting (AlertManager) into a single unified stack managed by Docker Compose.

**Version:** 3.1 — Hybrid Architecture (Docker-based metrics exporters + Grafana Alloy for log collection)

## Tech Stack at a Glance

| Layer | Technology | Version |
|---|---|---|
| Orchestration | Docker Compose | v2+ |
| Metrics DB | Prometheus | v2.47.0 |
| Visualization | Grafana | v12.1.1 |
| Alert Routing | AlertManager | v0.28.1 |
| Log Aggregation | Loki | v3.3.2 |
| Log Collection | Grafana Alloy | v1.9.1 |
| Host Metrics | Node Exporter | v1.6.1 |
| Container Metrics | cAdvisor | zcube/latest |
| Probe Monitoring | Blackbox Exporter | v0.27.0 |
| Scripting | Bash | — |
| Config Format | YAML, JSON, Alloy | — |

## Repository Structure

```
vm-monit/
├── compose.yaml                  # Unified Docker Compose (all services, all platforms)
├── prometheus.yaml               # Prometheus scrape configs & alerting rules reference
├── alerts.yml                    # Prometheus alert rules (InstanceDown, HighCPU/Memory/Disk)
├── alertmanager.yml              # AlertManager routing (currently null receiver)
├── .example.env                  # Environment variable template (Grafana admin, PostgreSQL)
├── .gitignore                    # Excludes: data/, logs/, archives/, backups/, .env
├── setup.sh                      # Full setup: dirs, permissions, networks, pull, start, health-check
├── stop.sh                       # Graceful shutdown with cleanup options
├── update.sh                     # Image pull, rolling/batch update, health verification
├── promtail-to-alloy-config.sh   # Migration: Promtail YAML → Alloy format via Docker
│
├── loki/                         # Loki configuration
│   └── loki-config.yaml          # Single-node Loki, filesystem storage, TSDB schema v13
├── alloy/                        # Grafana Alloy configuration (primary log collector)
│   └── alloy-config.alloy        # Journal + file + Docker log collection → Loki
├── blackbox_exporter/            # Blackbox Exporter configuration
│   └── blackbox_exporter.yaml    # HTTP website + API probe modules
├── grafana/                      # Grafana auto-provisioning
│   └── provisioning/
│       ├── dashboards/           # 10 pre-provisioned dashboards (Node, cAdvisor, PG, Nginx, Redis, Alerts)
│       │   ├── dashboard.yml     # Dashboard provider config
│       │   ├── 1860.json         # Node Exporter Full
│       │   ├── 11076.json        # Node Exporter Server Metrics
│       │   ├── 19908.json        # cAdvisor Docker Insights
│       │   ├── 9628.json         # PostgreSQL Database
│       │   ├── nginx.json        # Nginx Exporter
│       │   ├── redis.json        # Redis Monitoring
│       │   ├── redis-streaming.json  # Redis Streaming
│       │   ├── alerts.json       # Alert History
│       │   ├── 13659_rev1.json   # (additional dashboard)
│       │   └── 19792_rev6.json   # (additional dashboard)
│       └── datasources/
│           └── datasource.yml    # Prometheus (default), Loki, Redis (commented) datasources
│
├── scripts/                      # Maintenance & utility scripts
│   ├── backup.sh                 # Timestamped backups: Grafana data, Prometheus config, recent metrics
│   ├── restore.sh                # Restore Grafana, Prometheus config, or Prometheus data from backups
│   ├── data-retention.sh         # Archive old Prometheus data (16d), clean old archives (90d)
│   └── maintenance.sh            # Combined: backup → data-retention
│
├── exporter-centralized/         # Remote VM exporter deployment scripts
│   ├── cadvisor/setup.sh         # Deploy cAdvisor on a remote host
│   └── node-exporter/setup.sh    # Deploy Node Exporter on a remote VM
│
├── data/                         # Runtime data (gitignored): prometheus/, grafana/, loki/, alloy_data/
├── logs/                         # Runtime logs (gitignored): grafana/, alertmanager/, prometheus/
├── archives/                     # Archived Prometheus data (gitignored)
└── backups/                      # Timestamped backups (gitignored)
```

## Orientation Sequence (Read in Order Before Any Work)

1. **`.claude/README.md`** (this file) → Project overview, stack, structure
2. **`.claude/state/CURRENT_STATUS.md`** → What is done, in progress, blocked, known issues
3. **`.claude/state/TASK_QUEUE.md`** → Backlog of tasks with priorities and dependencies
4. **`.claude/AGENT_RULES.md`** → Non-negotiable behavioral rules for every session
5. **`.claude/CODING_STANDARDS.md`** → Conventions: naming, file placement, patterns to follow
6. **`.claude/SECURITY_STANDARDS.md`** → Security requirements and audit findings
7. **`.claude/ENVIRONMENT_GUIDE.md`** → Environment definitions, verified commands, gotchas
8. **`.claude/HOW_TO_RESUME.md`** → Step-by-step resume protocol with real commands

## Environment Bootstrap

```bash
# Start the full monitoring stack (first time or after changes)
./setup.sh

# Or manually with Docker Compose
docker compose up -d

# Verify all services are healthy
./update.sh --status   # or: ./update.sh --verify

# Stop services
./stop.sh
```

**Service Ports:**
- Grafana: `:3000` (default: admin/admin)
- Prometheus: `:9090`
- AlertManager: `:9093`
- Loki: `:3100`
- Alloy: `:12345`
- Node Exporter: `:9100`
- cAdvisor: `:8080`
- Blackbox Exporter: `:9115`

## Security Note

See **`.claude/SECURITY_STANDARDS.md`** for the full security audit. Key findings:

- **YELLOW**: Default Grafana credentials (admin/admin) — changeable via `.env`
- **YELLOW**: AlertManager has null receiver (no alert notifications active)
- **YELLOW**: No TLS, no auth on Prometheus/Loki/AlertManager endpoints
- **YELLOW**: cAdvisor image uses `:latest` tag (unpinned)
- **GREEN**: No hardcoded secrets found in any source file
- **GREEN**: `.env` correctly excluded from git
- **GREEN**: Prometheus and AlertManager run as unprivileged users

## Where to Find Current State

- **Current status**: `.claude/state/CURRENT_STATUS.md`
- **Task backlog**: `.claude/state/TASK_QUEUE.md`
- **Decision history**: `.claude/state/DECISIONS_LOG.md`

## Key Configuration Files

| File | Purpose |
|---|---|
| `compose.yaml` | All service definitions, volumes, networks, healthchecks |
| `prometheus.yaml` | Scrape configs: node-exporter, cadvisor, prometheus, blackbox |
| `alerts.yml` | 4 alert rules: InstanceDown, HighCPULoad, HighMemoryLoad, HighDiskUsage |
| `alertmanager.yml` | Routing config (null receiver — needs notification setup) |
| `loki/loki-config.yaml` | Loki single-node config, filesystem storage |
| `alloy/alloy-config.alloy` | Alloy log collection: journal, system files, Docker containers |
| `blackbox_exporter/blackbox_exporter.yaml` | HTTP probe modules (website + API) |
| `grafana/provisioning/datasources/datasource.yml` | Auto-provisioned datasources |
| `.example.env` | Required env vars: Grafana admin user/pass, PostgreSQL connection |
