# Current Status — vm-monit

## Project Phase
**Active Maintenance — v3.1 Hybrid Architecture** (Docker-based metrics exporters + Grafana Alloy for log collection)

## Completed

- **Core monitoring stack** — All 8 services configured and operational:
  - Node Exporter (v1.6.1) — host system metrics (CPU, memory, disk, network)
  - cAdvisor (zcube/latest) — Docker container metrics
  - Prometheus (v2.47.0) — metrics storage, querying, alert rule evaluation
  - Grafana (v12.1.1) — visualization with 10 pre-provisioned dashboards
  - AlertManager (v0.28.1) — alert routing (null receiver — no notifications active)
  - Loki (v3.3.2) — log aggregation with filesystem storage
  - Grafana Alloy (v1.9.1) — log collection from journal, system files, Docker containers
  - Blackbox Exporter (v0.27.0) — HTTP/HTTPS probe monitoring (website + API modules)

- **Data retention strategy** — Multi-tier: hot (15d Prometheus), warm (16-90d archives), cold (backups)
- **Backup/restore system** — Timestamped backups for Grafana data, Prometheus config, recent metrics
- **Management scripts** — setup.sh, stop.sh, update.sh with full argument parsing and colored output
- **Grafana provisioning** — Auto-provisioned datasources (Prometheus, Loki) and 10 dashboards
- **Cross-platform support** — Single compose.yaml works on Linux, macOS, Windows/WSL
- **Promtail→Alloy migration** — Migration script completed, Promtail removed
- **Health checks** — All 8 services have Docker Compose healthchecks
- **Security basics** — Prometheus runs as nobody, AlertManager as 65534, .env gitignored, no hardcoded secrets

## In Progress

- None — all configured features are operational

## Blocked

- **Alert notifications** — AlertManager has null receiver; needs actual notification channel (Slack, email, webhook) configured before alerts are useful
- **Production readiness** — No TLS, no auth on most services, no resource limits, no network isolation

## Known Issues

1. **cAdvisor image unpinned** — Uses `:latest` tag instead of specific version
2. **AlertManager null receiver** — Alerts fire but are silently dropped
3. **No authentication** on Prometheus, Loki, AlertManager, Node Exporter, cAdvisor
4. **No TLS** on any service
5. **No resource limits** on any container
6. **promtail/ directory** referenced in README but does not exist (migrated to Alloy — README should be updated)
7. **restore.sh uses `docker-compose`** (v1 syntax) while other scripts use `docker compose` (v2 syntax) — inconsistency

## Security Findings

**Overall: YELLOW** — No critical vulnerabilities, but several medium-priority issues need attention before production use.

- **GREEN**: No hardcoded secrets in any file
- **GREEN**: `.env` correctly excluded from git
- **GREEN**: Prometheus and AlertManager run as unprivileged users
- **YELLOW**: Default Grafana credentials (admin/admin)
- **YELLOW**: AlertManager null receiver (silent alert failures)
- **YELLOW**: No TLS on any service
- **YELLOW**: No auth on Prometheus/Loki/AlertManager
- **YELLOW**: cAdvisor image unpinned (`:latest`)
- See `.claude/SECURITY_STANDARDS.md` for full audit

## Open Questions

1. Should AlertManager be configured with actual notification receivers? If so, which channels (Slack, email, PagerDuty, webhook)?
2. Should TLS be enabled for Grafana at minimum?
3. Should resource limits be added to all services?
4. Should the `promtail/` directory reference be removed from README.md?
5. Should `restore.sh` be updated to use `docker compose` (v2) instead of `docker-compose` (v1)?

## Last Updated
2026-05-17 — Initial population from takeover audit
