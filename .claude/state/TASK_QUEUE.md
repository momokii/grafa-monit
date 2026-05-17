# Task Queue — vm-monit

Tasks derived from the Phase 1 audit findings, existing TODOs, and identified gaps.

---

## Security Remediation Tasks (High Priority — Complete Before Feature Work)

| Field               | Value                                               |
|---------------------|-----------------------------------------------------|
| Task ID             | SEC-001                                             |
| Name                | Pin cAdvisor Docker image version                   |
| Priority            | High                                                |
| Status              | TODO                                                |
| Complexity          | S                                                   |
| Depends On          | None                                                |
| Scope               | Replace `zcube/cadvisor:latest` with a specific version tag in compose.yaml. Update stop.sh image list accordingly. |
| Acceptance Criteria | cAdvisor image uses a pinned version tag (e.g., v0.47.0 or equivalent). No `:latest` tags remain in compose.yaml. |
| Security Concerns   | Unpinned images risk supply chain attacks and unpredictable updates |
| Source              | compose.yaml line 49; SECURITY_STANDARDS.md finding #5 |

| Field               | Value                                               |
|---------------------|-----------------------------------------------------|
| Task ID             | SEC-002                                             |
| Name                | Configure AlertManager notification receivers       |
| Priority            | High                                                |
| Status              | TODO                                                |
| Complexity          | M                                                   |
| Depends On          | None                                                |
| Scope               | Replace null receiver in alertmanager.yml with actual notification channel(s). Update route configuration. Add required env vars to .example.env. |
| Acceptance Criteria | Alerts are delivered to at least one notification channel (Slack, email, or webhook). AlertManager config validates with `promtool check config`. |
| Security Concerns   | Webhook URLs or API keys for notification channels must come from .env, never hardcoded |
| Source              | alertmanager.yml line 9; SECURITY_STANDARDS.md finding #2 |

| Field               | Value                                               |
|---------------------|-----------------------------------------------------|
| Task ID             | SEC-003                                             |
| Name                | Change default Grafana credentials in production    |
| Priority            | High                                                |
| Status              | TODO                                                |
| Complexity          | S                                                   |
| Depends On          | None                                                |
| Scope               | Document the requirement to set GF_SECURITY_ADMIN_USER and GF_SECURITY_ADMIN_PASSWORD in .env before any production deployment. Add validation to setup.sh. |
| Acceptance Criteria | setup.sh warns if .env has empty Grafana credentials. README.md documents the requirement clearly. |
| Security Concerns   | Default admin/admin credentials allow unauthorized access |
| Source              | compose.yaml lines 138-139; SECURITY_STANDARDS.md finding #1 |

---

## Configuration Consistency Tasks (Medium Priority)

| Field               | Value                                               |
|---------------------|-----------------------------------------------------|
| Task ID             | CFG-001                                             |
| Name                | Fix docker-compose vs docker compose inconsistency  |
| Priority            | Medium                                              |
| Status              | TODO                                                |
| Complexity          | S                                                   |
| Depends On          | None                                                |
| Scope               | Update restore.sh to use `docker compose` (v2 syntax) instead of `docker-compose` (v1 syntax) for consistency with all other scripts. |
| Acceptance Criteria | All scripts in the repo use `docker compose` (v2 syntax) consistently. |
| Security Concerns   | None                                                |
| Source              | restore.sh lines 37, 61, 93, 113, 137               |

| Field               | Value                                               |
|---------------------|-----------------------------------------------------|
| Task ID             | CFG-002                                             |
| Name                | Remove stale promtail/ reference from README.md     |
| Priority            | Medium                                              |
| Status              | TODO                                                |
| Complexity          | S                                                   |
| Depends On          | None                                                |
| Scope               | The promtail/ directory no longer exists (migrated to Alloy). Remove all references to promtail/ directory from README.md project structure section. |
| Acceptance Criteria | README.md no longer references a promtail/ directory that does not exist. |
| Security Concerns   | None                                                |
| Source              | README.md project structure section; promtail/ directory does not exist |

| Field               | Value                                               |
|---------------------|-----------------------------------------------------|
| Task ID             | CFG-003                                             |
| Name                | Add resource limits to all services                 |
| Priority            | Medium                                              |
| Status              | TODO                                                |
| Complexity          | M                                                   |
| Depends On          | None                                                |
| Scope               | Add `deploy.resources.limits` (memory, cpus) to all services in compose.yaml. Start with conservative limits based on README recommendations. |
| Acceptance Criteria | All 8 services have memory and CPU limits defined. Services still start and pass health checks with limits applied. |
| Security Concerns   | Prevents resource exhaustion attacks                |
| Source              | SECURITY_STANDARDS.md finding #10; README.md production guidelines |

---

## Feature Enhancement Tasks (Low Priority)

| Field               | Value                                               |
|---------------------|-----------------------------------------------------|
| Task ID             | FEAT-001                                            |
| Name                | Enable TLS for Grafana                              |
| Priority            | Low                                                 |
| Status              | TODO                                                |
| Complexity          | M                                                   |
| Depends On          | None                                                |
| Scope               | Add TLS configuration to Grafana service in compose.yaml. Support self-signed certs for dev and Let's Encrypt for production. Add env vars for cert paths. |
| Acceptance Criteria | Grafana serves HTTPS. HTTP redirects to HTTPS. Cert paths configurable via .env. |
| Security Concerns   | TLS certificates and keys must come from .env or mounted secrets, never hardcoded |
| Source              | SECURITY_STANDARDS.md finding #3; README.md production recommendations |

| Field               | Value                                               |
|---------------------|-----------------------------------------------------|
| Task ID             | FEAT-002                                            |
| Name                | Add authentication to Prometheus and Loki           |
| Priority            | Low                                                 |
| Status              | TODO                                                |
| Complexity          | L                                                   |
| Depends On          | None                                                |
| Scope               | Implement basic auth or token-based auth for Prometheus and Loki. Update all dependent configs (Grafana datasources, AlertManager alertmanager_url, Alloy loki.write). |
| Acceptance Criteria | Prometheus and Loki require authentication. All dependent services authenticate correctly. Health checks still pass. |
| Security Concerns   | Credentials must come from .env. Never expose auth tokens in logs |
| Source              | SECURITY_STANDARDS.md finding #4, #7                |

| Field               | Value                                               |
|---------------------|-----------------------------------------------------|
| Task ID             | FEAT-003                                            |
| Name                | Implement network isolation                         |
| Priority            | Low                                                 |
| Status              | TODO                                                |
| Complexity          | M                                                   |
| Depends On          | None                                                |
| Scope               | Split Docker networks: internal (prometheus, loki, alertmanager, alloy) and frontend (grafana, node-exporter, cadvisor, blackbox). Configure cross-network access only where needed. |
| Acceptance Criteria | Internal services are not directly accessible from outside the Docker network. Grafana can reach all datasources. Health checks pass. |
| Security Concerns   | Defense in depth — limits blast radius of compromised containers |
| Source              | SECURITY_STANDARDS.md finding #6                    |

---

## Task Summary

| Priority | Count | Task IDs |
|---|---|---|
| High | 3 | SEC-001, SEC-002, SEC-003 |
| Medium | 3 | CFG-001, CFG-002, CFG-003 |
| Low | 3 | FEAT-001, FEAT-002, FEAT-003 |
| **Total** | **9** | |
