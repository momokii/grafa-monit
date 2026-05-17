# Bug Fix Checklist

## Reproduce First
- [ ] Bug is reproducible — repro steps documented before touching any config
- [ ] Expected behavior clearly stated
- [ ] Actual broken behavior clearly stated
- [ ] Reproduction performed in development environment only (never production)

## Root Cause Analysis
- [ ] Root cause identified and documented before any fix is applied
- [ ] Checked whether the same bug exists in related config files or scripts
- [ ] Assessed whether the bug has security implications (data exposure, auth bypass, misconfiguration) — if yes, escalate to user immediately before proceeding
- [ ] Checked service logs for error messages:
  ```bash
  docker logs <service-name> --tail 50
  docker compose logs <service-name> --tail 50
  ```

## Common Bug Categories in This Project

### Config Syntax Errors
- [ ] Validate with appropriate tool:
  - `docker compose config` for compose.yaml
  - `promtool check config prometheus.yaml` for Prometheus config
  - `promtool check rules alerts.yml` for alert rules
  - `docker run --rm grafana/alloy:v1.9.1 fmt /etc/alloy/config.alloy` for Alloy config

### Service Startup Failures
- [ ] Check Docker logs: `docker logs <service-name>`
- [ ] Check health status: `docker compose ps`
- [ ] Verify volume mount paths exist and have correct permissions
- [ ] Verify port conflicts: `lsof -i :<port>` or `netstat -tlnp | grep <port>`

### Metrics/Logs Not Appearing
- [ ] Verify exporter is running and responding: `curl http://localhost:<port>/metrics`
- [ ] Verify Prometheus target is UP: `curl -s 'http://localhost:9090/api/v1/targets'`
- [ ] Verify scrape interval is appropriate (not too long)
- [ ] Verify relabel configs are correct (not dropping targets)
- [ ] For logs: verify Alloy is collecting and forwarding to Loki

### Dashboard Shows No Data
- [ ] Verify datasource is configured correctly in Grafana
- [ ] Verify datasource URL is correct (service name, not localhost, within Docker network)
- [ ] Verify PromQL/LogQL query syntax
- [ ] Verify time range is appropriate
- [ ] Check for label mismatches between query and actual data

### Script Failures
- [ ] Run with debug output: `bash -x <script.sh>`
- [ ] Check for missing commands: `command -v <command>`
- [ ] Check for permission issues: `ls -la <path>`
- [ ] Check for Docker availability: `docker info`

## Fix
- [ ] Minimal, targeted fix applied — no opportunistic refactoring alongside the fix
- [ ] Fix resolves only the stated bug — no scope creep
- [ ] Fix does not introduce new behavior beyond resolving the specific bug
- [ ] If modifying compose.yaml: validated with `docker compose config`
- [ ] If modifying prometheus.yaml: validated with `promtool check config`
- [ ] If modifying alerts.yml: validated with `promtool check rules`

## Verification
- [ ] Bug is no longer reproducible with the fix applied
- [ ] All services start successfully: `docker compose up -d`
- [ ] Health checks pass: `./update.sh --verify`
- [ ] Full test suite passes (run all verification commands from new_test.md template)
- [ ] No regressions in other services or features

## Completion
- [ ] `.claude/state/DECISIONS_LOG.md` updated if root cause revealed an important architectural or security insight
- [ ] `.claude/state/CURRENT_STATUS.md` updated with session summary
- [ ] If bug was caused by a pattern issue: consider updating `.claude/CODING_STANDARDS.md` to prevent recurrence
