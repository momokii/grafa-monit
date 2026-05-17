# How to Resume — vm-monit

Step-by-step protocol for starting any new session. All commands are real and verified from the Phase 1 audit.

---

## Resume Protocol

### Step 1: Read `.claude/README.md`
→ Orient yourself: understand the project, stack, and structure

### Step 2: Read `.claude/state/CURRENT_STATUS.md`
→ Know exactly what is done, in progress, and blocked

### Step 3: Read `.claude/state/TASK_QUEUE.md`
→ Identify the next task and confirm its dependencies are met

### Step 4: Read `.claude/AGENT_RULES.md`
→ Re-internalize all behavioral rules before touching anything

### Step 5: Read `.claude/CODING_STANDARDS.md`
→ Re-internalize all conventions before writing any config or script

### Step 6: Read `.claude/SECURITY_STANDARDS.md`
→ Re-internalize all security requirements before writing any config

### Step 7: Identify the active environment
→ Check if `.env` exists — if not, copy from `.example.env`:
```bash
cp .example.env .env
```
→ Edit `.env` with actual values (never commit this file)

### Step 8: Read task-relevant docs
→ For config changes: read the relevant config file (prometheus.yaml, alerts.yml, compose.yaml, etc.)
→ For script changes: read the existing script to understand the pattern
→ For dashboard changes: read the dashboard JSON and the provisioning config

### Step 9: Verify the environment is functional
```bash
# Check if services are running
docker compose ps

# If not running, start them
./setup.sh

# Or if already configured, just start
docker compose up -d
```

### Step 10: Confirm no regressions
```bash
# Run health checks on all services
./update.sh --verify

# Or check individual services
curl -f http://localhost:9090/-/healthy    # Prometheus
curl -f http://localhost:3000/api/health   # Grafana
curl -f http://localhost:9093/-/healthy    # AlertManager
curl -f http://localhost:3100/ready        # Loki
```

### Step 11: Begin the task
→ Implement changes following CODING_STANDARDS.md
→ Validate configs before restarting:
  ```bash
  docker compose config              # Validate compose
  promtool check config prometheus.yaml   # Validate Prometheus (if promtool available)
  promtool check rules alerts.yml         # Validate alert rules (if promtool available)
  ```
→ Restart affected services:
  ```bash
  docker compose up -d <service-name>
  ```
→ Verify the change works:
  ```bash
  ./update.sh --verify
  ```

### Step 12: Security review
→ No secrets hardcoded in new/modified files
→ No environment variable values logged or printed
→ `.env.example` updated if new env vars introduced
→ `.env` not committed

### Step 13: Update .claude/ state files
→ Update `state/CURRENT_STATUS.md` with session summary
→ Update `state/TASK_QUEUE.md` — mark task DONE, add new tasks
→ Log significant decisions in `state/DECISIONS_LOG.md`
