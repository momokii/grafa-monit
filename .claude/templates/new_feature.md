# New Feature Implementation Checklist

## Before Starting
- [ ] Task exists in `.claude/state/TASK_QUEUE.md` with clear acceptance criteria
- [ ] All task dependencies are complete (check TASK_QUEUE.md Depends On field)
- [ ] Relevant config files have been read (compose.yaml, prometheus.yaml, alerts.yml, etc.)
- [ ] Current services are healthy — run `./update.sh --verify` to confirm
- [ ] Active environment identified and confirmed as development (check for `.env` file)

## Design
- [ ] Full scope defined — list every file to be created or modified
- [ ] If adding a new Docker service: image pinned to specific version, healthcheck defined, volume mounts planned
- [ ] If adding a new scrape target: Prometheus job name, scrape interval, and relabel_configs planned
- [ ] If adding a new alert: PromQL expression, threshold, severity, and annotations defined
- [ ] If adding a new dashboard: Grafana datasource dependencies identified
- [ ] Edge cases identified and documented before implementation begins
- [ ] Security implications assessed before implementation begins
- [ ] If new Docker image required: vulnerability check performed and logged in `.claude/state/DECISIONS_LOG.md`, and user confirmation received
- [ ] If schema change required (e.g., new volume mount): proposal submitted to user and confirmed

## Implementation
- [ ] All changes follow `.claude/CODING_STANDARDS.md` exactly
  - File placement matches the structure rules
  - Naming conventions followed (kebab-case for configs, PascalCase for alerts, etc.)
  - Bash scripts use colored output functions and argument parsing pattern
  - Docker images pinned to specific versions
- [ ] If modifying `compose.yaml`: service added to setup.sh startup and stop.sh shutdown sequences
- [ ] If modifying `prometheus.yaml`: config validated with `promtool check config`
- [ ] If modifying `alerts.yml`: config validated with `promtool check rules`
- [ ] If adding new env vars: `.example.env` updated with placeholder and description
- [ ] Error handling covers all failure paths (Docker failures, permission errors, missing files)
- [ ] Logging added at appropriate levels — no sensitive data logged

## Security Review
- [ ] No secrets, tokens, or credentials hardcoded anywhere in new config or scripts
- [ ] All new env vars come from `.env` — never hardcoded
- [ ] New service runs as non-root user where possible (`user:` directive in compose.yaml)
- [ ] New service has resource limits defined (`deploy.resources.limits`)
- [ ] New service has healthcheck defined
- [ ] Any new Docker image checked for known vulnerabilities and logged in DECISIONS_LOG.md
- [ ] `.env.example` updated if new environment variables were introduced
- [ ] Behavior verified correct with `docker compose config`

## Testing / Verification
- [ ] `docker compose config` passes — valid Compose syntax
- [ ] `promtool check config prometheus.yaml` passes (if prometheus.yaml modified)
- [ ] `promtool check rules alerts.yml` passes (if alerts.yml modified)
- [ ] Services start successfully: `docker compose up -d`
- [ ] Health checks pass: `./update.sh --verify`
- [ ] New service metrics/logs are visible in Grafana

## Completion
- [ ] `.claude/state/TASK_QUEUE.md` updated — task marked DONE
- [ ] `.claude/state/CURRENT_STATUS.md` updated with session summary
- [ ] `.claude/state/DECISIONS_LOG.md` updated if any significant decision was made
- [ ] Affected documentation updated (README.md if new service or capability added)
