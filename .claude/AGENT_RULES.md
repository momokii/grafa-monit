# Agent Rules — vm-monit

Non-negotiable behavioral rules for every agent session working on this repository.

---

## Session Start — Mandatory Before Any Action

1. **Read `.claude/HOW_TO_RESUME.md`** completely — understand the resume protocol
2. **Read `.claude/state/CURRENT_STATUS.md`** — know exactly what is done, in progress, and blocked
3. **Read `.claude/state/TASK_QUEUE.md`** — identify the next task and confirm dependencies are met
4. **Read `.claude/CODING_STANDARDS.md`** — internalize conventions before writing any config or script
5. **Read `.claude/SECURITY_STANDARDS.md`** — internalize all security requirements
6. **Identify the active environment** — check if `.env` exists; if not, copy from `.example.env`
7. **Verify the environment is functional** — run `docker compose ps` and confirm services are running
8. **Run health checks** — `./update.sh --verify` or individual curl health endpoints

---

## During Implementation

- **Never modify `compose.yaml`** without understanding the dependency order between services
- **Never change service ports** without updating all references (prometheus.yaml, health checks, documentation)
- **Never delete existing dashboards** from `grafana/provisioning/dashboards/` without user confirmation
- **Never introduce a new Docker image** without pinning to a specific version tag (no `:latest` except where already established)
- **Never modify alert rules in `alerts.yml`** without understanding the PromQL expressions and thresholds
- **Always follow the bash script patterns** — colored output functions, argument parsing, `main "$@"` entry point
- **Always validate YAML configs** before restarting services — use `docker compose config` or `promtool check config`
- **Zero-regression rule**: if a change breaks a running service, revert immediately and flag the issue

---

## Configuration Change Rules

This project is **infrastructure-as-configuration**, not application code. Changes are to YAML configs, Bash scripts, Alloy configs, and JSON dashboards.

### When modifying `compose.yaml`:
- Preserve the existing service startup order (node-exporter → cadvisor → prometheus → alertmanager → loki → alloy → blackbox → grafana)
- Preserve all existing healthchecks
- Preserve all existing volume mounts
- If adding a new service, add it to `setup.sh` startup sequence and `stop.sh` shutdown sequence
- If adding a new service, add it to `update.sh` health verification

### When modifying `prometheus.yaml`:
- Preserve existing scrape jobs unless explicitly replacing them
- Test with `promtool check config prometheus.yaml` before restarting
- If adding scrape targets, add corresponding relabel_configs if needed

### When modifying `alerts.yml`:
- Preserve existing alert names and severity labels
- Test with `promtool check rules alerts.yml` before restarting
- New alerts must have: `expr`, `for`, `labels.severity`, `annotations.summary`, `annotations.description`

### When modifying `alloy-config.alloy`:
- Preserve existing log sources (journal, system files, Docker)
- Test syntax with `docker run --rm grafana/alloy:v1.9.1 fmt /etc/alloy/config.alloy`
- All `forward_to` must point to a valid receiver

### When modifying Bash scripts:
- Preserve the colored output pattern (`print_info`, `print_success`, `print_warning`, `print_error`)
- Preserve the argument parsing pattern (while/case loop)
- Preserve the `main "$@"` entry point with `BASH_SOURCE` check
- Always use `set -e` for safety in new scripts

---

## Security Rules — Non-Negotiable

- **Never hardcode secrets, API keys, tokens, passwords, or webhook URLs** in any config, script, or dashboard
- **All secrets must come from environment variables** loaded from `.env` (never committed)
- **Never log, print, or expose environment variable values** in script output, error messages, or debug statements
- **Never implement auth bypasses** "to be fixed later" — incomplete auth is a blocker
- **Before adding any Docker image**, check for known vulnerabilities and document the check in `DECISIONS_LOG.md`
- **If a security vulnerability is discovered** in existing code, flag it to the user immediately before proceeding

---

## Environment Awareness

- **Development**: This project runs locally via Docker Compose. All services are on the default Docker network.
- **No staging/production distinction** in the current codebase — all config is development-oriented
- **Remote exporters**: The `exporter-centralized/` directory contains scripts for deploying node-exporter and cAdvisor on remote VMs. These are separate from the main stack.
- **`.env` file**: If it exists, it contains actual credentials. Never commit it. Never print its contents.
- **Always verify `.env` is gitignored** before the first commit of any session (it is — confirmed in audit)

---

## Session End — Mandatory Before Closing

1. **Update `state/CURRENT_STATUS.md`** with accurate current state and a session summary
2. **Update `state/TASK_QUEUE.md`** — mark completed tasks, add newly discovered tasks
3. **Log any significant decision** in `state/DECISIONS_LOG.md`
4. **Update `CODING_STANDARDS.md`** if new patterns were established
5. **Update `SECURITY_STANDARDS.md`** if new security findings were identified
6. **Update `ENVIRONMENT_GUIDE.md`** if environment configuration changed
7. **Update `README.md`** if project-level context changed materially

---

## Self-Maintenance Directive

- The `.claude/` files must stay accurate at all times — they are not set-and-forget
- If a convention in `CODING_STANDARDS.md` is found to be wrong, correct it immediately and log the change in `DECISIONS_LOG.md`
- If the project state in `CURRENT_STATUS.md` is stale, update it before proceeding

---

## Escalation Rule

When blocked, uncertain about scope, or facing a decision with significant architectural, security, or operational impact: **document the blocker in `CURRENT_STATUS.md` and ask the user** — do not assume and proceed.
