# Security Standards — vm-monit

Derived from the Phase 1 security audit of the existing codebase.

---

## Audit Findings Summary

### Critical Issues
**None found.** No hardcoded secrets, no exposed credentials, no active vulnerabilities.

### High Priority Issues

| # | Issue | Location | Impact |
|---|---|---|---|
| 1 | **Default Grafana credentials** (admin/admin) | `compose.yaml` line 138-139 | Anyone with network access can log in as admin |
| 2 | **AlertManager null receiver** | `alertmanager.yml` line 9 | Alerts fire but nobody receives them — silent failures |
| 3 | **No TLS on any service** | All services | All traffic (including Grafana admin) is plaintext |
| 4 | **No authentication on Prometheus/Loki/AlertManager** | All services | Anyone can query metrics, logs, or modify alert config |

### Medium Priority Issues

| # | Issue | Location | Impact |
|---|---|---|---|
| 5 | **cAdvisor image unpinned** (`:latest`) | `compose.yaml` line 49 | Unpredictable updates, potential supply chain risk |
| 6 | **Single Docker network** (no isolation) | `compose.yaml` | All services can reach each other — no defense in depth |
| 7 | **Loki `auth_enabled: false`** | `loki/loki-config.yaml` line 1 | Anyone can push logs to Loki without authentication |
| 8 | **Node Exporter `pid: "host"`** | `compose.yaml` line 12 | Sees all host processes — necessary for function but increases attack surface |
| 9 | **cAdvisor `/var/run` mounted rw** | `compose.yaml` line 76-77 | Write access to Docker socket directory — necessary for function |

### Low Priority / Informational

| # | Issue | Location | Impact |
|---|---|---|---|
| 10 | **No resource limits** on any service | `compose.yaml` | A misbehaving service could exhaust host resources |
| 11 | **No CI/CD or vulnerability scanning** | No pipeline | No automated security checks on config changes |
| 12 | **AlertManager debug logging** | `compose.yaml` line 174 | Verbose logs may expose sensitive information |

---

## Secrets & Environment Variable Management

### Current State
- **`.env` file**: Correctly excluded from git via `.gitignore`
- **`.example.env`**: Present at root with placeholder values for:
  - `GRAFANA_ADMIN_USER`, `GRAFANA_ADMIN_PASSWORD`
  - `POSTGRES_USER`, `POSTGRES_PASS`, `POSTGRES_DB`, `POSTGRES_PORT`, `POSTGRES_HOST`
- **No hardcoded secrets** found in any source file, config, or script

### Rules
- **Never hardcode** secrets, API keys, tokens, passwords, or webhook URLs in any file
- **All secrets must come from environment variables** loaded from `.env`
- **Never log, print, or expose** environment variable values in script output or error messages
- **`.env.example` must be updated** whenever a new environment variable is introduced
- **Never commit `.env`**, `.env.*`, or any file containing actual credentials

---

## Environment Configuration

### Current State
- **Single environment**: No distinction between development, staging, and production
- **All config is development-oriented**: Debug logging, default credentials, no TLS
- **No `APP_ENV` or equivalent** variable to control environment-specific behavior

### Rules
- If adding environment-specific behavior, use environment variables — never hardcoded conditionals
- Production deployments must have:
  - TLS enabled on all externally-facing services
  - Non-default credentials for Grafana and all services
  - AlertManager configured with actual notification receivers
  - Resource limits on all containers
  - Network isolation between service tiers

---

## Input Validation & Sanitization

### Current State
- **No application code** in this repository — it is purely infrastructure configuration
- **Boundary layer**: Docker Compose configuration and Bash scripts
- **External input**: Environment variables, command-line arguments to scripts

### Rules
- Bash scripts must validate command-line arguments before use
- Never pass unvalidated user input to shell commands (prevent injection)
- Docker image names in scripts must be validated before `docker pull`

---

## Authentication & Authorization

### Current State

| Service | Auth | Notes |
|---|---|---|
| Grafana | Basic auth (admin/admin default) | Changeable via env vars |
| Prometheus | **None** | Anyone can query all metrics |
| AlertManager | **None** | Anyone can view/modify alert config |
| Loki | **None** (`auth_enabled: false`) | Anyone can push/query logs |
| Alloy | **None** | Internal service, exposes metrics on :12345 |
| Node Exporter | **None** | Exposes all host metrics on :9100 |
| cAdvisor | **None** | Exposes all container metrics on :8080 |
| Blackbox Exporter | **None** | Internal service |

### Rules
- **All protected routes must enforce auth checks** — default deny posture
- **Never implement auth bypasses** "to be fixed later"
- Grafana credentials must be changed from defaults before any production use
- If adding auth to Prometheus/Loki/AlertManager, update all dependent configs (datasources, scrape configs, alertmanager_url)

---

## Dependency Security

### Current State
- **Dependencies are Docker images** — no npm/pip/cargo packages
- **All images pinned** to specific versions except cAdvisor (`:latest`)
- **No vulnerability scanning** in CI/CD (no CI/CD exists)

### Rules
- **Pin all Docker image versions** — never use `:latest` for new services
- **Before adding a new Docker image**, check for known CVEs:
  - Search https://github.com/advisories for the image name
  - Check the image's Docker Hub page for security notes
  - Log the check in `state/DECISIONS_LOG.md`
- **Update images regularly** using `./update.sh` with `--verify` flag

### Current Image Pinning Status

| Service | Pinned? | Version |
|---|---|---|
| Node Exporter | Yes | v1.6.1 |
| cAdvisor | **No** | latest |
| Prometheus | Yes | v2.47.0 |
| Grafana | Yes | 12.1.1 |
| AlertManager | Yes | v0.28.1 |
| Loki | Yes | 3.3.2 |
| Alloy | Yes | v1.9.1 |
| Blackbox Exporter | Yes | v0.27.0 |

---

## Docker & Container Security

### Current State

| Check | Status | Details |
|---|---|---|
| Non-root users | Partial | Prometheus: `nobody:nobody`, AlertManager: `65534:65534`. Others run as default (usually root) |
| Read-only filesystems | Partial | Node Exporter mounts are `read_only: true`. Others are not |
| Unnecessary ports | No | All exposed ports serve a purpose |
| `.env` in images | Yes | `.env` is not mounted into any container — only used for env var substitution in compose |
| Resource limits | No | No `deploy.resources.limits` on any service |
| Health checks | Yes | All 8 services have Docker healthchecks |
| Restart policy | Yes | All services use `restart: unless-stopped` |

### Rules
- **All new services must run as non-root** where possible (use `user:` directive)
- **Mount host filesystems as read-only** where write access is not required
- **Add resource limits** to prevent resource exhaustion
- **Never expose unnecessary ports** — only expose what is needed for the service's function
- **Always include healthchecks** for new services

---

## Stack-Specific Security

### Prometheus
- No auth or TLS — anyone on the network can query all metrics
- `--web.enable-lifecycle` allows config reload via HTTP POST (potential abuse if exposed)
- Rule: Never expose Prometheus port (9090) to untrusted networks in production

### Grafana
- Default admin/admin credentials — must be changed via `.env`
- `GF_USERS_ALLOW_SIGN_UP=false` — good, prevents self-registration
- Rule: Enable HTTPS and OAuth/LDAP in production

### Loki
- `auth_enabled: false` — no authentication
- Rule: Enable auth and TLS before exposing to untrusted networks

### Alloy
- No auth — internal service
- Rule: Do not expose port 12345 to external networks

### AlertManager
- Null receiver — alerts are silently dropped
- Debug logging enabled — may expose sensitive data
- Rule: Configure actual receivers and reduce log level before production use

---

## Security Issue Remediation Priority

1. **Change default Grafana credentials** — add to `.env` before first production use
2. **Configure AlertManager receivers** — alerts are useless without notification
3. **Pin cAdvisor image version** — replace `:latest` with specific tag
4. **Add resource limits** to all services
5. **Enable TLS** for Grafana at minimum
6. **Add authentication** to Prometheus and Loki
7. **Implement network isolation** — separate internal and external networks
