# Decisions Log — vm-monit

Key decisions already made and visible in the codebase, extracted from the Phase 1 audit.

---

---
**Decision:** Migrate from Promtail to Grafana Alloy for log collection
**Date:** Pre-takeover (commit fc8bdcb, 1cbb7c0)
**Context:** Promtail was being deprecated by Grafana Labs. Alloy provides unified observability data collection (logs, metrics, traces) in a single agent.
**Rationale:** Alloy is the future-proof replacement for Promtail with active development and long-term support from Grafana Labs. It uses the same underlying technology but with a more flexible configuration format (River/Alloy language).
**Alternatives Rejected:** Continuing with Promtail (deprecated, no long-term support)
**Security Implications:** None — Alloy runs with same permissions model as Promtail
**Impact:** Required config migration script (promtail-to-alloy-config.sh), updated compose.yaml, updated Alloy config with journal + file + Docker log sources
---

---
**Decision:** Use Docker-based metrics exporters (Node Exporter, cAdvisor) instead of Alloy built-in exporters
**Date:** Pre-takeover (commit 76609b4)
**Context:** Alloy has built-in `prometheus.exporter.unix` and `prometheus.exporter.cadvisor` components that could replace separate containers.
**Rationale:** Dedicated exporters ensure reliable metrics collection with industry-standard configurations. Alloy's built-in exporters were commented out in favor of separate containers. This provides better isolation and independent lifecycle management.
**Alternatives Rejected:** Using Alloy built-in exporters (would couple metrics and logs collection in a single process)
**Security Implications:** Separate containers follow principle of least privilege — each runs with only the permissions it needs
**Impact:** compose.yaml includes separate node-exporter and cadvisor services. Alloy config has unix/cadvisor exporters commented out.
---

---
**Decision:** Single unified compose.yaml for all platforms
**Date:** Pre-takeover (commit 9aba9d2)
**Context:** Previous versions had platform-specific compose files (compose-linux/, compose-windows/).
**Rationale:** Simplified architecture with a single compose.yaml that works across Linux, macOS, and Windows/WSL. Reduces maintenance burden and configuration drift between platforms.
**Alternatives Rejected:** Maintaining separate compose files per platform
**Security Implications:** None
**Impact:** All platform-specific differences resolved. Journal log source in Alloy must be commented out for Windows/WSL (noted in config comments).
---

---
**Decision:** Hybrid architecture — dedicated exporters for metrics, Alloy for logs
**Date:** Pre-takeover (v3.1)
**Context:** v3.0 used Alloy for everything (metrics + logs). v3.1 reverted to dedicated exporters for metrics while keeping Alloy for logs.
**Rationale:** Specialized exporters provide more reliable metrics collection with extensive community support. Alloy excels at log collection and processing. Combining both gives the best of each approach.
**Alternatives Rejected:** All-in-Alloy (metrics reliability concerns), All-in-exporters (no unified log collection)
**Security Implications:** More containers = larger attack surface, but each container is more isolated
**Impact:** 8 services running instead of fewer. More resource usage but better reliability.
---

---
**Decision:** Bind mounts instead of Docker named volumes for data persistence
**Date:** Pre-takeover (initial commit 68cca32)
**Context:** Data directories (data/, logs/) are bind-mounted to the host filesystem rather than using Docker named volumes.
**Rationale:** Direct host filesystem access makes backup, restore, and data retention scripts simpler. Files are accessible for manual inspection and management.
**Alternatives Rejected:** Docker named volumes (would require docker exec or volume inspection for backup/restore)
**Security Implications:** Host filesystem access means container data is readable by host users with appropriate permissions. Permission management via setup.sh chown commands.
**Impact:** setup.sh creates directories and sets ownership. backup.sh/restore.sh work directly with host paths.
---

---
**Decision:** AlertManager configured with null receiver (no notifications)
**Date:** Pre-takeover (initial commit 68cca32)
**Context:** AlertManager is configured but has no actual notification channels.
**Rationale:** Default setup — alerts are defined and evaluated but not delivered. Allows the stack to be deployed without requiring external notification service configuration.
**Alternatives Rejected:** Defaulting to email or Slack (would require credentials that may not be available)
**Security Implications:** Alerts fire but are silently dropped — operators may miss critical issues
**Impact:** Alert rules are evaluated by Prometheus and sent to AlertManager, but no notifications are delivered. This is a known gap that needs addressing before production use.
---

---
**Decision:** Prometheus runs as `nobody:nobody`, AlertManager as `65534:65534`
**Date:** Pre-takeover (initial commit 68cca32)
**Context:** Both Prometheus and AlertManager run as unprivileged users instead of root.
**Rationale:** Following the principle of least privilege. Reduces attack surface if the container is compromised. `65534:65534` is the numeric UID/GID for `nobody` — used for AlertManager to ensure cross-distro compatibility.
**Alternatives Rejected:** Running as root (default for many Docker images)
**Security Implications:** Positive — limits damage from container escape or compromise
**Impact:** setup.sh must set correct ownership on data directories before starting services.
---

---
**Decision:** Multi-tier data retention strategy (hot/warm/cold)
**Date:** Pre-takeover (initial commit 68cca32)
**Context:** Prometheus data retention, archive scripts, and backup system work together for tiered storage.
**Rationale:** Hot storage (15d Prometheus native) for active querying. Warm storage (16-90d archives) for historical analysis. Cold storage (backups) for disaster recovery. The 1-day buffer between Prometheus retention and archiving ensures data is safely archived before deletion.
**Alternatives Rejected:** Single-tier retention (either too expensive for long retention or too risky for data loss)
**Security Implications:** Archived data contains all metrics — may include sensitive information. Archives should be protected.
**Impact:** data-retention.sh runs on schedule. backup.sh creates timestamped archives. restore.sh can recover from any backup.
---
