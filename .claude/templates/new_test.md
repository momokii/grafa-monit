# New Test Scenario Checklist

This project has **no automated test framework**. Testing is done through configuration validation, health checks, and manual verification.

## Before Starting
- [ ] Test objective clearly defined — what specific behavior is being verified
- [ ] Test type identified:
  - **Config validation**: `promtool check config`, `promtool check rules`, `docker compose config`
  - **Health check**: curl health endpoints, `docker compose ps`
  - **Functional verification**: Query Prometheus metrics, query Loki logs, check Grafana dashboards
  - **Integration test**: Verify end-to-end flow (exporter → Prometheus → Grafana)
- [ ] Test environment is functional — all services running
- [ ] Active environment confirmed — never run destructive tests against production

## Implementation — Config Validation Test

- [ ] Run `docker compose config` — verify no YAML errors in compose.yaml
- [ ] Run `promtool check config prometheus.yaml` — verify Prometheus config (if promtool available)
- [ ] Run `promtool check rules alerts.yml` — verify alert rules (if promtool available)
- [ ] If testing Alloy config: `docker run --rm grafana/alloy:v1.9.1 fmt /etc/alloy/config.alloy`

## Implementation — Health Check Test

- [ ] Run `./update.sh --verify` — all services pass health checks
- [ ] Verify individual endpoints:
  ```bash
  curl -f http://localhost:9090/-/healthy    # Prometheus
  curl -f http://localhost:3000/api/health   # Grafana
  curl -f http://localhost:9093/-/healthy    # AlertManager
  curl -f http://localhost:3100/ready        # Loki
  curl -f http://localhost:12345/metrics     # Alloy
  curl -f http://localhost:9100/metrics      # Node Exporter
  curl -f http://localhost:8080/healthz      # cAdvisor
  curl -f http://localhost:9115/-/healthy    # Blackbox Exporter
  ```

## Implementation — Functional Test

- [ ] **Prometheus metrics**: Query a known metric and verify data is returned
  ```bash
  curl -s 'http://localhost:9090/api/v1/query?query=up' | python3 -m json.tool
  ```
- [ ] **Loki logs**: Query logs and verify data is returned
  ```bash
  curl -s 'http://localhost:3100/loki/api/v1/query?query={job=~".+"}&limit=5' | python3 -m json.tool
  ```
- [ ] **Grafana dashboards**: Verify dashboards are provisioned and show data
  - Open http://localhost:3000/dashboards
  - Check that expected dashboards are listed
  - Open a dashboard and verify panels show data (not "No data")
- [ ] **AlertManager**: Verify alerts are being received
  ```bash
  curl -s http://localhost:9093/api/v2/alerts | python3 -m json.tool
  ```

## Implementation — Integration Test

- [ ] **End-to-end metrics flow**: Node Exporter → Prometheus → Grafana
  1. Verify Node Exporter is scraping: `curl http://localhost:9100/metrics | head -5`
  2. Verify Prometheus is receiving: `curl -s 'http://localhost:9090/api/v1/query?query=node_cpu_seconds_total' | python3 -m json.tool`
  3. Verify Grafana dashboard shows data: check Node Exporter dashboard
- [ ] **End-to-end logs flow**: Docker containers → Alloy → Loki → Grafana
  1. Verify Alloy is collecting: `curl http://localhost:12345/metrics | grep alloy`
  2. Verify Loki is receiving: `curl -s 'http://localhost:3100/loki/api/v1/query?query={job=~".+"}' | python3 -m json.tool`
  3. Verify Grafana Explore shows logs: query `{job=~".+"}` in Grafana Explore

## Completion
- [ ] All tests pass reliably — run health checks at least 3 times to confirm no flakiness
- [ ] Test results documented in session notes
- [ ] `.claude/state/CURRENT_STATUS.md` updated
