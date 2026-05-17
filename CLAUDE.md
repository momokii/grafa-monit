# CLAUDE.md — vm-monit Agent Context

> **This file is the entry point for any Claude Code agent starting work on this repository.**
> It references all `.claude/` infrastructure files and provides immediate project context.

---

## Project: Grafana Host Monitoring Stack (vm-monit)

A complete, containerized observability solution for host systems and Docker containers.
Combines metrics (Prometheus + exporters), logs (Loki + Alloy), visualization (Grafana), and alerting (AlertManager).

**Version:** 3.1 — Hybrid Architecture
**Runtime:** Docker Compose v2+
**Services:** 8 (node-exporter, cadvisor, prometheus, grafana, alertmanager, loki, alloy, blackbox_exporter)

---

## Agent Infrastructure — Read These Files in Order

When starting any session, read these files **in this exact order**:

1. **`.claude/README.md`** — Project overview, tech stack, repository structure, service ports
2. **`.claude/state/CURRENT_STATUS.md`** — What is done, in progress, blocked, known issues, security findings
3. **`.claude/state/TASK_QUEUE.md`** — Backlog of 9 tasks (3 high, 3 medium, 3 low priority) with dependencies
4. **`.claude/AGENT_RULES.md`** — Non-negotiable behavioral rules: session start, implementation, security, session end
5. **`.claude/CODING_STANDARDS.md`** — Conventions: file placement, naming (kebab-case/PascalCase/snake_case), bash patterns, YAML patterns, Alloy patterns, image pinning rules
6. **`.claude/SECURITY_STANDARDS.md`** — Security audit findings (12 items: 0 critical, 4 high, 5 medium, 3 low), secrets management, auth status, Docker security posture
7. **`.claude/ENVIRONMENT_GUIDE.md`** — Environment definitions, verified commands (setup, stop, update, health check, validate, maintenance), Docker Compose patterns, .env file pattern, known gotchas
8. **`.claude/HOW_TO_RESUME.md`** — 13-step resume protocol with real commands

---

## State Files (Update Every Session)

- **`.claude/state/CURRENT_STATUS.md`** — Update with session summary after every session
- **`.claude/state/TASK_QUEUE.md`** — Mark tasks DONE, add new tasks, update dependencies
- **`.claude/state/DECISIONS_LOG.md`** — Log significant decisions with context, rationale, alternatives

---

## Templates (Use When Applicable)

- **`.claude/templates/new_feature.md`** — Checklist for adding new services, exporters, alerts, or dashboards
- **`.claude/templates/new_endpoint.md`** — Checklist for new Prometheus scrape targets, Blackbox probes, or Grafana datasources
- **`.claude/templates/new_test.md`** — Checklist for config validation, health checks, functional tests, integration tests
- **`.claude/templates/bug_fix.md`** — Checklist for reproducing, diagnosing, fixing, and verifying bugs

---

## Tool Permissions

See **`.claude/settings.json`** for allowed and denied commands. Key allowances:
- Docker Compose commands (docker compose, docker-compose)
- Git operations
- Bash scripts (setup.sh, stop.sh, update.sh, scripts/*)
- curl, chmod, chown, mkdir, tar, find
- sudo chown, sudo tar, sudo rm, sudo chmod (for permission management)

---

## Quick Reference

### Start / Stop / Update
```bash
./setup.sh              # Full setup (first time)
docker compose up -d    # Start services
./stop.sh               # Stop services
./update.sh --verify    # Update and health check
```

### Validate Config
```bash
docker compose config
promtool check config prometheus.yaml
promtool check rules alerts.yml
```

### Health Checks
```bash
curl -f http://localhost:9090/-/healthy    # Prometheus
curl -f http://localhost:3000/api/health   # Grafana
curl -f http://localhost:9093/-/healthy    # AlertManager
curl -f http://localhost:3100/ready        # Loki
```

### Service Ports
| Service | Port | Auth |
|---|---|---|
| Grafana | 3000 | Basic (admin/admin default) |
| Prometheus | 9090 | None |
| AlertManager | 9093 | None |
| Loki | 3100 | None |
| Alloy | 12345 | None |
| Node Exporter | 9100 | None |
| cAdvisor | 8080 | None |
| Blackbox Exporter | 9115 | None |

---

## Security Posture: YELLOW

- No hardcoded secrets (GREEN)
- .env gitignored (GREEN)
- Default Grafana credentials (YELLOW — change via .env)
- AlertManager null receiver (YELLOW — no notifications)
- No TLS, no auth on most services (YELLOW)
- cAdvisor image unpinned (YELLOW)

See `.claude/SECURITY_STANDARDS.md` for full audit and remediation tasks.
