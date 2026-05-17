# New API Endpoint / Scrape Target Checklist

This project does not have a traditional API. "Endpoints" here means **Prometheus scrape targets**, **Blackbox probe targets**, or **Grafana datasource connections**.

## Before Starting
- [ ] Target defined and behavior is clear (what metrics/logs it provides)
- [ ] HTTP method, route, and full expected behavior are understood
- [ ] Auth requirements are understood (if the target requires authentication)
- [ ] Active environment confirmed as development

## Implementation — Prometheus Scrape Target

- [ ] Service added to `compose.yaml` with:
  - [ ] Pinned Docker image version
  - [ ] Container name
  - [ ] Port mapping
  - [ ] Volume mounts (if needed)
  - [ ] Healthcheck
  - [ ] Restart policy
  - [ ] User directive (non-root where possible)
- [ ] Scrape job added to `prometheus.yaml` under `scrape_configs`:
  - [ ] `job_name` follows snake_case convention
  - [ ] `static_configs` with correct target address (`<service_name>:<port>`)
  - [ ] `scrape_interval` set if different from global (15s)
  - [ ] `relabel_configs` added if label transformation is needed
- [ ] If the target is a Blackbox probe:
  - [ ] `metrics_path: /probe` set
  - [ ] `params.module` configured
  - [ ] Relabel configs copy `__address__` to `__param_target` and set `__address__` to blackbox_exporter
- [ ] Config validated: `promtool check config prometheus.yaml`

## Implementation — Blackbox Probe Module

- [ ] New module added to `blackbox_exporter/blackbox_exporter.yaml`:
  - [ ] Module name follows `snake_case` convention
  - [ ] `prober` type specified (http, tcp, icmp, dns)
  - [ ] `timeout` set
  - [ ] TLS config specified (insecure_skip_verify: false for production)
  - [ ] Valid status codes defined
- [ ] Probe target added to `prometheus.yaml` blackbox job
- [ ] Config validated: `promtool check config prometheus.yaml`

## Implementation — Grafana Datasource

- [ ] Datasource added to `grafana/provisioning/datasources/datasource.yml`:
  - [ ] `name`, `type`, `access`, `url` configured
  - [ ] `isDefault` set appropriately (only one datasource can be default)
  - [ ] `jsonData` configured for datasource-specific settings
  - [ ] `secureJsonData` used for any secrets (passwords, tokens)
- [ ] If datasource requires a plugin: `GF_INSTALL_PLUGINS` env var added to Grafana service in compose.yaml

## Security Review
- [ ] No secrets, tokens, or credentials hardcoded in any config
- [ ] Datasource credentials (if any) use env var substitution from `.env`
- [ ] New service does not expose unnecessary ports
- [ ] New service runs as non-root where possible
- [ ] Any new Docker image checked for known vulnerabilities

## Testing / Verification
- [ ] `docker compose config` passes
- [ ] `promtool check config prometheus.yaml` passes
- [ ] Services start: `docker compose up -d`
- [ ] New target is visible in Prometheus: `curl http://localhost:9090/api/v1/targets`
- [ ] New datasource is visible in Grafana: check Grafana UI at http://localhost:3000/connections/datasources
- [ ] Health checks pass: `./update.sh --verify`

## Completion
- [ ] `.claude/state/TASK_QUEUE.md` updated
- [ ] `.claude/state/CURRENT_STATUS.md` updated
- [ ] README.md updated if new service or capability is user-facing
