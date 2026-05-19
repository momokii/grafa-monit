# Grafana Host Monitoring Stack

A centralized monitoring and observability solution for host systems and containerized applications, featuring metrics collection, visualization, alerting, and optional log aggregation.

## Overview

This project provides a containerized monitoring stack designed for **centralized monitoring** — deploy this stack once as your central server, then add remote machines by running node-exporter on them. Log aggregation (Loki + Alloy) is optional and enabled via Docker Compose profiles. It includes data retention strategies, automated backup procedures, and cross-platform compatibility.

## Architecture

The monitoring stack is split into core services (always running) and optional log aggregation:

### Core Services (always running)
- **Prometheus**: Time-series database for metrics storage, querying, and alerting
- **Grafana**: Unified visualization platform for metrics (and logs when enabled)
- **AlertManager**: Alert handling, routing, and notifications
- **Node Exporter**: Host system metrics collection (CPU, memory, disk, network)
- **cAdvisor**: Docker container metrics collection (resource usage, performance)
- **Blackbox Exporter**: HTTP/HTTPS, TCP, ICMP, and DNS probe monitoring

### Optional Log Aggregation (enabled with `--with-logs` or `--profile logs`)
- **Grafana Alloy**: Log collection and processing agent
- **Loki**: Log aggregation system with efficient storage and querying

> **Architecture Note**: Core services provide centralized metrics monitoring. Remote VMs only need node-exporter to be monitored by this central server. Log aggregation is optional.

### Optional Exporters (Configurable)
- **PostgreSQL Exporter**: Database performance monitoring
- **Nginx Exporter**: Web server metrics and performance monitoring
- **Redis Monitoring**: Redis datasource integration for real-time Redis metrics

## Project Structure

```
grafana-host-monitoring/
├── compose.yaml                 # Unified Docker Compose configuration
├── prometheus.yaml              # Prometheus configuration
├── alerts.yml                   # Prometheus alert rules
├── alertmanager.yml             # AlertManager configuration
├── .example.env                 # Environment variables template
├── .gitignore                   # Git ignore rules
├── setup.sh                     # Setup script (core or --with-logs)
├── stop.sh                      # Service management script
├── update.sh                    # Update and restart script
├── data/                        # Data storage (gitignored)
│   ├── prometheus/              # Prometheus TSDB data
│   ├── grafana/                 # Grafana database and plugins
│   ├── loki/                    # Loki chunks and index data (optional)
│   └── alloy_data/              # Alloy persistent storage (optional)
├── logs/                        # Application logs (gitignored)
│   ├── grafana/                 # Grafana application logs
│   └── alertmanager/            # AlertManager logs
├── archives/                    # Long-term data archive (gitignored)
├── backups/                     # Configuration and data backups (gitignored)
├── prometheus/targets/          # Remote VM target JSON files (auto-discovered)
├── loki/                        # Loki configuration
│   └── loki-config.yaml
├── alloy/                       # Grafana Alloy configuration (optional log collector)
│   └── alloy-config.alloy
├── blackbox_exporter/           # Blackbox Exporter configuration
│   └── blackbox_exporter.yaml
├── exporter-centralized/        # Remote VM setup scripts
│   └── node-exporter/setup.sh   # Deploy node-exporter on remote VMs
├── grafana/                     # Grafana provisioning
│   ├── provisioning/
│   │   ├── dashboards/          # Auto-provisioned dashboards (5 active)
│   │   │   ├── dashboard.yml    # Dashboard provider config
│   │   │   ├── node-exporter-full.json          # Detailed host metrics
│   │   │   ├── node-exporter-server-metrics.json # Quick health overview
│   │   │   ├── cadvisor-docker-insights.json    # Container monitoring
│   │   │   ├── blackbox-prober.json             # Endpoint probing
│   │   │   └── alert-history.json               # Alert status and trends
│   │   └── datasources/         # Auto-provisioned data sources
│   │       ├── datasource.yml   # Prometheus datasource
│   │       └── datasource-loki.yml.disabled  # Loki (enabled by --with-logs)
│   └── dashboards-optional/     # Dashboards for disabled exporters
│       ├── cadvisor-full.json          # cAdvisor deep analysis
│       ├── postgresql-database.json    # PostgreSQL (requires postgres_exporter)
│       ├── nginx.json                  # NGINX (requires nginx_exporter)
│       ├── redis.json                  # Redis (requires Redis datasource)
│       └── redis-streaming.json        # Redis streaming
└── scripts/                     # Maintenance and utility scripts
    ├── backup.sh                # Backup script for data and configs
    ├── restore.sh               # Restore script for disaster recovery
    ├── data-retention.sh        # Data archiving and cleanup
    └── maintenance.sh           # Combined maintenance operations
```

## Setup and Configuration

### Prerequisites
- Docker Engine 20.10+ and Docker Compose 2.0+
- Bash shell (Git Bash on Windows, native on Linux/macOS)
- 2GB+ RAM for core services (4GB+ recommended with log aggregation)
- 10GB+ disk space (depends on retention policies)
- Network ports available: 3000, 9090, 9093, 9100, 8080, 9115 (core) + 3100, 12345 (optional logging)

### Cross-Platform Support

This monitoring stack uses a **unified Docker Compose configuration** that works across different platforms:

- **Simplified Architecture**: Single `compose.yaml` file with optional profiles
- **Centralized Monitoring**: Monitor remote VMs by deploying only node-exporter on them
- **Consistent Performance**: Same functionality across Linux, Windows, and macOS environments

### Setup Modes

The monitoring stack has two setup modes. Choose the one that fits your needs:

#### Default Mode (Core — Metrics Only)

**Recommended for most users.** Starts 6 core services for centralized metrics monitoring:

| Service | Purpose | Port |
|---|---|---|
| **node-exporter** | Host system metrics (CPU, memory, disk, network) | 9100 |
| **cadvisor** | Docker container metrics (resource usage, performance) | 8080 |
| **prometheus** | Metrics storage, querying, and alerting engine | 9090 |
| **grafana** | Visualization dashboards | 3000 |
| **alertmanager** | Alert routing and notification management | 9093 |
| **blackbox_exporter** | HTTP/HTTPS endpoint probing and availability checks | 9115 |

Use this when you need centralized monitoring of multiple VMs, host and container metrics, and endpoint probing — without log aggregation.

#### Full Mode (`--with-logs`) — Metrics + Log Aggregation

Starts all 6 core services **plus** 2 log aggregation services:

| Service | Purpose | Port |
|---|---|---|
| **loki** | Log storage and querying | 3100 |
| **alloy** | Log collection (system logs, container logs, file-based logs) | 12345 |

Use this when you also need centralized log management — collecting, storing, and searching logs from your host and containers.

> **Why is logging optional?** Many setups only need metrics. Loki and Alloy consume additional memory (~1-2GB combined) and disk space for log storage. If you don't need log querying in Grafana, the core mode is lighter and simpler.

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/grafana-host-monit.git
   cd grafana-host-monit
   ```

2. **Choose your setup mode and run:**
   ```bash
   chmod +x setup.sh

   # Core setup — metrics only (recommended for most users)
   ./setup.sh

   # OR: Full setup with log aggregation (Loki + Alloy)
   ./setup.sh --with-logs

   # OR: Start manually with Docker Compose
   docker compose up -d                    # Core services only
   docker compose --profile logs up -d     # All services including logs
   ```

3. **Access the interfaces:**

   **Core services (always available):**
   - **Grafana**: http://localhost:3000 (admin/admin)
   - **Prometheus**: http://localhost:9090
   - **AlertManager**: http://localhost:9093
   - **Node Exporter**: http://localhost:9100/metrics
   - **cAdvisor**: http://localhost:8080/metrics
   - **Blackbox Exporter**: http://localhost:9115

   **Log services (only with `--with-logs`):**
   - **Loki**: http://localhost:3100
   - **Alloy**: http://localhost:12345/metrics

> **Note**: Grafana credentials can be customized by setting `GF_SECURITY_ADMIN_USER` and `GF_SECURITY_ADMIN_PASSWORD` environment variables in your `.env` file before starting the services.

### Adding Remote Machines (Centralized Monitoring)

To monitor additional VMs from this central server:

1. **On the remote VM**, run the node-exporter setup:
   ```bash
   cd exporter-centralized/node-exporter/
   chmod +x setup.sh
   ./setup.sh <VM_NAME> <ENVIRONMENT>
   # Example: ./setup.sh web-server-01 production
   ```

2. **On the central server**, create a target file:
   ```bash
   cat > prometheus/targets/<vm-name>.json << EOF
   [
     {
       "targets": ["<REMOTE_IP>:9100"],
       "labels": {
         "vm_name": "<VM_NAME>",
         "environment": "production"
       }
     }
   ]
   EOF
   ```

3. Prometheus auto-discovers new targets every 30 seconds — no restart needed.

## Monitoring Architecture

This monitoring stack uses a **centralized approach** with dedicated metrics exporters and optional log collection:

### Architecture Overview

**Metrics Collection** (Core — always running):
- **Node Exporter**: Specialized host system metrics collection
  - CPU, memory, disk, network metrics
  - Process and filesystem monitoring
  - System load and performance indicators
- **cAdvisor**: Specialized Docker container metrics
  - Container resource usage (CPU, memory, I/O)
  - Container performance and health metrics
  - Network and storage statistics per container

**Log Collection** (Optional — enabled with `--with-logs`):
- **Grafana Alloy**: Advanced log collection and processing
  - System logs (journald and file-based)
  - Container logs with metadata enrichment
  - Log parsing and structured data extraction
  - Efficient shipping to Loki

**Probe Monitoring**:
- **Blackbox Exporter**: External service monitoring
  - HTTP/HTTPS endpoint monitoring
  - TCP connection testing
  - ICMP/Ping checks
  - DNS query testing

### Probe Monitoring Configuration

Blackbox exporter provides comprehensive probe-based monitoring:

1. **HTTP Probing**:
   - Endpoint availability monitoring
   - SSL/TLS certificate validation
   - Response content validation
   - HTTP header checks

2. **Network Probing**:
   - TCP connection testing
   - ICMP ping checks
   - DNS query validation

3. **Usage Example**:
   ```yaml
   scrape_configs:
     - job_name: 'blackbox'
       metrics_path: /probe
       params:
         module: [http_2xx]  # Use the HTTP 2xx module
       static_configs:
         - targets:
           - https://example.com   # Target to probe
           - http://internal.app   # Internal service
       relabel_configs:
         - source_labels: [__address__]
           target_label: __param_target
         - source_labels: [__param_target]
           target_label: instance
         - target_label: __address__
           replacement: blackbox_exporter:9115  # Blackbox exporter address
   ```

4. **Key Metrics**:
   - `probe_success`: Indicates if the probe was successful
   - `probe_duration_seconds`: Time taken for the probe
   - `probe_http_ssl_earliest_cert_expiry`: SSL certificate expiry
   - `probe_dns_lookup_time_seconds`: DNS resolution time

### Benefits of Centralized Architecture

- **Centralized Monitoring**: One server monitors multiple remote VMs
- **Reliable Metrics**: Dedicated exporters ensure consistent metrics collection
- **Optional Logging**: Enable Loki/Alloy only when log aggregation is needed
- **Flexible Configuration**: Independent configuration for metrics and logs
- **Production Proven**: Using industry-standard exporters with extensive community support

### Current Configuration Capabilities

The monitoring stack provides comprehensive observability coverage:

- **System Metrics**: CPU, memory, disk, network metrics (via Node Exporter)
- **Container Metrics**: Docker container resource usage (via cAdvisor)
- **Probe Monitoring**: External service availability and performance (via Blackbox Exporter)
- **Remote Monitoring**: File-based service discovery for centralized VM monitoring
- **Log Aggregation**: System and container logs (optional, via Alloy + Loki)

### Manual Setup (Alternative)

If you prefer manual setup or need to customize the installation:

1. **Create environment file (optional):**
   ```bash
   cp .example.env .env
   # Edit .env with your PostgreSQL credentials if using postgres_exporter
   ```

2. **Start services:**
   ```bash
   # Using the unified compose configuration
   docker compose up -d
   ```

### Service Management Scripts

The stack includes three management scripts for different operations:

#### Setup Script (`setup.sh`)

Initial setup and configuration of the monitoring stack. Creates directories, sets permissions, pulls images, and starts services in dependency order.

**Setup modes:**
- **Default** — Updates 6 core services: node-exporter, cadvisor, prometheus, grafana, alertmanager, blackbox_exporter
- **`--with-logs`** — Updates all 8 services (core + loki + alloy). Use this if you initially set up with `./setup.sh --with-logs`

```bash
./setup.sh                    # Core setup (metrics only — recommended)
./setup.sh --with-logs        # Full setup including Loki + Alloy
./setup.sh --quick            # Quick setup for development (skip pull + validation)
./setup.sh --skip-pull        # Setup without pulling latest images
./setup.sh --help             # Show detailed help with service lists
```

#### Stop Script (`stop.sh`)

Service shutdown and cleanup. Automatically detects optional services (Loki/Alloy) regardless of how they were started.

```bash
./stop.sh                     # Stop and remove containers (data preserved)
./stop.sh -s                  # Stop services only (keep containers)
./stop.sh --all               # Remove everything (containers, volumes, networks, images, data)
./stop.sh -v                  # Stop, remove containers and Docker volumes
./stop.sh --status            # Show what's currently running
./stop.sh --help              # Show detailed help
```

#### Update Script (`update.sh`)

Update Docker images and restart services. Supports both batch and rolling update modes.

**Update modes:**
- **Default** — Updates 6 core services: node-exporter, cadvisor, prometheus, grafana, alertmanager, blackbox_exporter
- **`--with-logs`** — Updates all 8 services (core + loki + alloy). Use this if you initially set up with `./setup.sh --with-logs`

```bash
./update.sh                   # Update core services
./update.sh --with-logs       # Update all services including Loki + Alloy
./update.sh -r                # Rolling update (one service at a time, 3s pause)
./update.sh --backup --verify # Update with backup + health check
./update.sh -p                # Just pull images, don't restart
./update.sh -v                # Show current and available image versions
./update.sh --status          # See what's running right now
./update.sh --help            # Show detailed help with service lists
```

#### Remote Node Exporter Setup (`exporter-centralized/node-exporter/setup.sh`)

Deploys a standalone node-exporter container on a remote VM for centralized monitoring. After running this on a remote machine, add its IP to the central Prometheus targets directory.

```bash
# On the REMOTE VM:
./exporter-centralized/node-exporter/setup.sh <VM_NAME> <ENVIRONMENT>

# Examples:
./exporter-centralized/node-exporter/setup.sh web-server-01 production
./exporter-centralized/node-exporter/setup.sh db-server staging
./exporter-centralized/node-exporter/setup.sh --help
```

The script will output the exact JSON target to add to your central Prometheus server.

## Monitoring Capabilities

### Metrics Collection and Monitoring

The stack provides comprehensive metrics monitoring through dedicated exporters:

- **Host System Metrics**: CPU, memory, disk usage, network traffic, system load (via Node Exporter)
- **Container Metrics**: Resource usage, performance, and health status for all running containers (via cAdvisor)
- **Remote VM Metrics**: Centralized monitoring of remote machines (via file-based service discovery)
- **Application Metrics**: Custom application metrics via Prometheus exporters
- **Database Metrics**: PostgreSQL performance monitoring (when enabled)
- **Web Server Metrics**: Nginx performance and request metrics (when enabled)

### Log Aggregation and Analysis

Centralized logging capabilities through Alloy's advanced log processing:

- **System Logs**: Operating system logs and kernel messages via journald and file collection
- **Application Logs**: Structured logging from your applications with advanced parsing
- **Container Logs**: Automatic collection of Docker container stdout/stderr with container metadata
- **Web Server Logs**: Nginx access and error logs with parsing and field extraction
- **API Logs**: Backend application request/response logging with structured data
- **Custom Log Sources**: Configurable log collection from any file or service with advanced processing

### Supported Log Formats

- **JSON**: Structured logging with automatic field extraction
- **Standard formats**: Nginx, Apache, syslog formats
- **Custom formats**: Configurable parsing with regex patterns
- **Multi-line logs**: Java stack traces, application error logs

## Pre-Configured Dashboards

The monitoring stack comes with 5 pre-configured dashboards that are automatically provisioned when Grafana starts. Additional dashboards for optional services are available in `grafana/dashboards-optional/`.

### System Monitoring Dashboards

#### 1. Node Exporter Full Dashboard (ID: 1860)

Comprehensive host system metrics:

- Hardware status (CPU, memory, disk)
- System load and resource utilization
- Network traffic and statistics
- Disk I/O performance metrics
- System processes and service status

#### 2. Node Exporter Server Metrics (ID: 11076)

Streamlined server health overview:

- Core system performance indicators
- Resource utilization over time
- Quick health checks and status monitoring

### Container Monitoring

#### 3. cAdvisor Docker Insights (ID: 19908)

Container resource monitoring:

- Per-container CPU and memory usage
- Network and disk I/O statistics
- Container health and restart counts

### Probe Monitoring

#### 4. Blackbox Prober (ID: 13659)

HTTP/HTTPS endpoint probing dashboard:

- Probe success/failure rates
- Response time monitoring
- SSL certificate expiry tracking

### Alerting

#### 5. Alert History Dashboard

Alert status and history overview:

- Current active alerts with severity classification
- Historical alert patterns and trends
- Alert grouping by service and severity

### Optional Dashboards (not auto-loaded)

Available in `grafana/dashboards-optional/` — move to `grafana/provisioning/dashboards/` if you enable the corresponding exporter:

- **cadvisor-full.json** — cAdvisor deep analysis (heavier version of cadvisor-docker-insights)
- **postgresql-database.json** — PostgreSQL (requires `postgres_exporter`)
- **nginx.json** — NGINX (requires `nginx_exporter`)
- **redis.json** + **redis-streaming.json** — Redis (requires Redis datasource)

### Accessing Dashboards

1. Open Grafana at http://localhost:3000
2. Log in with your credentials (default: admin/admin)
3. Navigate to **Dashboards > General** to see all pre-configured dashboards
4. Use **Explore** to query metrics (Prometheus) and logs (Loki) directly

### Dashboard Features

- **Auto-refresh**: All dashboards automatically refresh to show real-time data
- **Time range selection**: Easily switch between different time periods
- **Variable templating**: Dynamic dashboard filtering by host, container, or service
- **Alerting integration**: Visual alert indicators directly on dashboard panels
- **Export capabilities**: Save dashboard data as images or PDFs

### Customizing Dashboards

These dashboards can be customized to suit your specific needs:

1. Open a dashboard and click the gear icon (⚙️) in the top menu
2. Select **Save As...** to create your own copy
3. Modify panels, thresholds, queries, and visualizations as needed
4. Add custom panels for application-specific metrics

Your customized dashboards will persist in the Grafana data volume.

## Log Management with Loki and Grafana Alloy

### Log Collection Strategy

The stack uses **Grafana Alloy** to collect logs from multiple sources with enhanced capabilities compared to the legacy Promtail setup:

#### Enhanced Container Log Collection
- **Docker Container Discovery**: Advanced automatic discovery and collection of container logs
- **Dynamic Service Discovery**: Real-time discovery of new containers with configurable filters
- **Rich Label Enrichment**: Comprehensive automatic labeling with container and service metadata
- **Performance Optimization**: Better resource utilization and log processing throughput

#### Advanced File-Based Log Collection
- **System Logs**: Enhanced collection from `/var/log/*` with better parsing capabilities
- **Application Logs**: Flexible custom application log files from configured paths
- **Structured Logs**: Advanced JSON log parsing with comprehensive field extraction
- **Multi-line Log Support**: Improved handling of stack traces and multi-line log entries

### Alloy Configuration Advantages

Compared to the legacy Promtail configuration, Alloy provides:

- **Better Performance**: More efficient log processing and lower resource consumption
- **Enhanced Parsing**: Advanced pipeline stages with more flexible data transformation
- **Improved Discovery**: More sophisticated service discovery mechanisms
- **Unified Configuration**: Single configuration format for multiple observability data types
- **Future-Proof Architecture**: Active development and long-term support from Grafana Labs

#### Application Integration Examples

**Node.js/Express Application:**
```javascript
// Example: Structured logging that integrates with Loki
const logger = winston.createLogger({
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console(), // Docker captures this
    new winston.transports.File({ filename: 'logs/api/app.log' })
  ]
});

// Log with structured data
logger.info('User login', {
  userId: '12345',
  endpoint: '/api/login',
  ip: req.ip,
  userAgent: req.get('User-Agent')
});
```

**Python/FastAPI Application:**
```python
# Example: Python structured logging for Loki
import logging
import json
from datetime import datetime

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_entry = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "message": record.getMessage(),
            "service": "backend-api"
        }
        return json.dumps(log_entry)

logger = logging.getLogger("api")
handler = logging.StreamHandler()  # Docker captures stdout
handler.setFormatter(JSONFormatter())
logger.addHandler(handler)
```

### Log Querying with LogQL

Loki uses LogQL for powerful log querying:

```logql
# All logs from a specific service
{job="backend-api"}

# Error logs only
{job="backend-api"} |= "ERROR"

# Logs for specific endpoint
{job="backend-api"} | json | endpoint="/api/users"

# HTTP errors with status codes
{job="nginx"} | json | status_code >= 400

# Rate of log entries
rate({job="backend-api"}[5m])

# Log aggregation and metrics
count_over_time({job="backend-api"} |= "ERROR"[1h])
```

### Log Retention and Storage

- **Loki Configuration**: Configured for efficient log storage with configurable retention
- **Chunk Storage**: Optimized storage format for fast queries and low storage overhead
- **Index Management**: Efficient indexing for fast log search and retrieval

## Data Retention Strategy

This project implements a comprehensive multi-tier storage strategy for both metrics and logs:

### 1. Hot Storage (Prometheus Native)
- **Duration**: 0-15 days (configured in compose files)
- **Location**: `data/prometheus`
- **Management**: Native Prometheus retention (`--storage.tsdb.retention.time=15d`)
- **Purpose**: Active querying and recent metrics analysis

```yaml
prometheus:
  command:
    - '--storage.tsdb.retention.time=15d'  # Prometheus will delete data after 15 days
```

### 2. Warm Storage (Archives)
- **Duration**: 16-90 days (configured in `data-retention.sh`)
- **Location**: `./archives`
- **Management**: Custom `data-retention.sh` script
- **Purpose**: Historical data for occasional access and trend analysis

```bash
# data-retention.sh configuration
RETENTION_DAYS=16      # One day buffer after Prometheus retention
ARCHIVE_RETENTION_DAYS=90
```

### 3. Cold Storage (Backups)
- **Duration**: Based on external storage policies
- **Location**: `./backups`
- **Management**: `backup.sh` script
- **Purpose**: Disaster recovery, compliance, and long-term historical analysis

### 4. Log Storage (Loki)
- **Duration**: Configurable in `loki-config.yaml`
- **Location**: `data/loki`
- **Management**: Loki's native retention policies
- **Purpose**: Centralized log storage with efficient querying

### Why 15 vs 16 days Buffer?

The 1-day buffer between Prometheus native retention (15 days) and our archiving script (16 days) serves as a safety mechanism:

1. **Graceful Deletion**: Prometheus marks data for deletion at 15 days but may not immediately delete it
2. **Safe Archiving**: The `data-retention.sh` script archives data older than 16 days
3. **Data Integrity**: Ensures data is safely archived before Prometheus completely removes it
4. **No Duplication**: Prevents data duplication during the transition period

### Storage Optimization

- **Compression**: All archived data is compressed using gzip
- **Incremental Backups**: Only changed data is backed up
- **Selective Archiving**: Focus on important metrics and logs
- **Cleanup Automation**: Automatic removal of old archives based on retention policies

## Backup and Disaster Recovery

### Comprehensive Backup Strategy

The backup system captures all critical components:

1. **Configuration Files**: All config files for Prometheus, AlertManager, Loki, and Promtail
2. **Grafana Data**: Dashboards, users, plugins, and all Grafana state
3. **Recent Metrics**: Last 7 days of metrics data (configurable)
4. **Log Configuration**: Loki and Promtail configurations for log pipeline restore

#### Manual Backup
```bash
# Run comprehensive backup
./scripts/backup.sh

# Or using bash directly
bash ./scripts/backup.sh
```

#### Backup Contents
- **Grafana Backup**: `grafana_YYYY-MM-DD.tar.gz`
- **Prometheus Config**: `prometheus_config_YYYY-MM-DD.tar.gz`
- **Recent Metrics**: `prometheus_recent_YYYY-MM-DD.tar.gz`

### Disaster Recovery Procedures

### Disaster Recovery Procedures

The monitoring stack includes a robust restore system to recover from data loss, corruption, or system migration.

#### Restore Script Usage

```bash
# Make script executable (first time only)
chmod +x ./scripts/restore.sh

# List all available backups
./scripts/restore.sh list

# Restore specific components
./scripts/restore.sh grafana ./backups/grafana_2025-08-18.tar.gz
./scripts/restore.sh prometheus-config ./backups/prometheus_config_2025-08-18.tar.gz
./scripts/restore.sh prometheus-data ./backups/prometheus_recent_2025-08-18.tar.gz
```

#### Recovery Scenarios

**Complete System Recovery:**
1. Fresh installation on new system
2. Run setup script: `./setup.sh`
3. Stop services: `./stop.sh -s`
4. Restore Grafana data and configurations
5. Restart services: `./update.sh -f`

**Configuration Corruption:**
1. Stop affected services
2. Restore configuration backup
3. Validate configurations
4. Restart with `./update.sh -c`

**Data Migration:**
1. Create backup on source system
2. Transfer backup files to target system
3. Run setup on target system
4. Restore data and configurations
5. Verify all services and dashboards

#### Backup Validation

Regularly test your backup and restore procedures:

```bash
# Test configuration restoration (dry run)
./scripts/restore.sh prometheus-config --dry-run ./backups/latest_config.tar.gz

# Verify backup integrity
tar -tzf ./backups/grafana_2025-08-18.tar.gz

# Test service restart after restore
./update.sh --no-backup -c
```

## Maintenance and Operations

### Automated Maintenance Scripts

The stack includes several scripts for routine maintenance operations:

#### Data Retention Script
Manages the archiving and deletion of old metrics data:

```bash
./scripts/data-retention.sh
```

**Configuration Parameters:**
- `RETENTION_DAYS`: When to archive data (16 days)
- `ARCHIVE_RETENTION_DAYS`: When to delete archives (90 days)

**What it does:**
- Archives Prometheus data older than 16 days
- Compresses archived data to save space
- Removes archives older than 90 days
- Maintains data integrity during transitions

#### Backup Script
Creates compressed backups of configuration and data:

```bash
./scripts/backup.sh
```

**Configuration Parameters:**
- `BACKUP_DIR`: Where backups are stored (`./backups`)
- `DATA_DIR`: Source data directory (`./data`)
- `CONFIG_FILES`: Configuration files to backup

**Features:**
- Handles permission issues with Docker containers
- Creates timestamped backups
- Compresses data to minimize storage usage
- Supports both manual and automated execution

#### Combined Maintenance
For comprehensive scheduled maintenance:

```bash
./scripts/maintenance.sh
```

**Execution Order:**
1. Creates backup of current state
2. Runs data retention and archiving
3. Logs all operations for audit trail

### Scheduled Operations

#### Windows Task Scheduler
```powershell
# Schedule weekly maintenance (Run as Administrator)
schtasks /create /tn "GrafanaMonitoringMaintenance" /tr "C:\Program Files\Git\bin\bash.exe -c 'cd /d/path/to/grafana-host-monit && ./scripts/maintenance.sh'" /sc weekly /d SUN /st 02:00
```

#### Linux/macOS Cron Jobs
```bash
# Add to crontab for weekly maintenance
0 2 * * 0 cd /path/to/grafana-host-monit && ./scripts/maintenance.sh > ./logs/maintenance.log 2>&1

# Daily backup (optional)
0 1 * * * cd /path/to/grafana-host-monit && ./scripts/backup.sh > ./logs/backup.log 2>&1

# Monthly archive cleanup
0 3 1 * * cd /path/to/grafana-host-monit && ./scripts/data-retention.sh > ./logs/retention.log 2>&1
```

### Monitoring the Monitoring Stack

#### Health Checks
All services include health checks for monitoring their own status:

```bash
# Check all service health
./update.sh --status

# Individual service health
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Service-specific health endpoints
curl http://localhost:9090/-/healthy  # Prometheus
curl http://localhost:3000/api/health # Grafana
curl http://localhost:3100/ready     # Loki
```

#### Log Monitoring
Monitor the monitoring stack's own logs:

```bash
# View real-time logs
docker logs -f prometheus
docker logs -f grafana
docker logs -f loki

# Check for errors in logs
docker logs grafana 2>&1 | grep -i error
docker logs loki 2>&1 | grep -i error
```

#### Resource Usage Monitoring
The stack monitors its own resource usage through cAdvisor and can alert on:

- High memory usage by monitoring containers
- CPU spikes in Prometheus or Grafana
- Disk space usage in data directories
- Network connectivity issues between services

## Optional Services Configuration

The monitoring stack includes optional services that can be enabled based on your requirements:

### Blackbox Exporter for Endpoint Monitoring

Enable comprehensive URL and endpoint monitoring:

1. **Configure Service:**
   ```yaml
   # Already configured in compose.yaml
   blackbox_exporter:
     image: prom/blackbox-exporter:v0.24.0
     ports:
       - "9115:9115"
     volumes:
       - ./blackbox_exporter/blackbox.yml:/config/blackbox.yml:ro
     command:
       - --config.file=/config/blackbox.yml
   ```

2. **Setup Probe Targets:**
   ```yaml
   # Add to prometheus.yaml under scrape_configs
   - job_name: 'blackbox'
     metrics_path: /probe
     params:
       module: [http_2xx]  # Module for HTTP 2xx check
     static_configs:
       - targets:
         - https://example.com
         - http://your-app:8080/health
     relabel_configs:
       - source_labels: [__address__]
         target_label: __param_target
       - source_labels: [__param_target]
         target_label: instance
       - target_label: __address__
         replacement: blackbox_exporter:9115
   ```

3. **Custom Probe Configuration:**
   ```yaml
   # In blackbox_exporter/blackbox.yml
   modules:
     http_2xx:
       prober: http
       timeout: 5s
       http:
         valid_status_codes: [200, 201, 202, 204]
         tls_config:
           insecure_skip_verify: false
     
     http_post_2xx:
       prober: http
       http:
         method: POST
         headers:
           Content-Type: application/json
         body: '{"test": "probe"}'
   ```

4. **Available Metrics:**
   - `probe_success`: Indicates if the probe was successful
   - `probe_duration_seconds`: Time taken for the probe
   - `probe_http_ssl_earliest_cert_expiry`: SSL certificate expiry
   - `probe_http_status_code`: HTTP response code
   - `probe_http_version`: HTTP version used
   - `probe_ip_protocol`: IP protocol version (4/6)
   - `probe_dns_lookup_time_seconds`: DNS resolution time

### PostgreSQL Monitoring

Enable database monitoring by uncommenting the `postgres_exporter` service in your compose file:

1. **Configure Environment Variables:**
   ```bash
   cp .example.env .env
   # Edit .env with your PostgreSQL credentials:
   POSTGRES_USER=your_username
   POSTGRES_PASS=your_password
   POSTGRES_DB=your_database
   POSTGRES_HOST=postgres_container_name
   POSTGRES_PORT=5432
   ```

2. **Enable the Service:**
   ```yaml
   # Uncomment in compose-linux/compose.yaml or compose-windows/compose.yaml
   postgres_exporter:
     image: quay.io/prometheuscommunity/postgres-exporter
     ports:
       - "9187:9187"
     environment:
       DATA_SOURCE_NAME: "postgresql://${POSTGRES_USER}:${POSTGRES_PASS}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}?sslmode=disable"
   ```

3. **Update Prometheus Configuration:**
   ```yaml
   # Uncomment in prometheus.yaml
   - job_name: postgres
     static_configs:
       - targets: ["postgres_exporter:9187"]
   ```

### Nginx Monitoring

Enable web server monitoring:

1. **Configure Nginx with stub_status:**
   ```nginx
   # Add to your nginx.conf
   location /nginx_status {
       stub_status on;
       access_log off;
       allow 127.0.0.1;
       deny all;
   }
   ```

2. **Enable the Exporter:**
   ```yaml
   # Uncomment in your compose file
   nginx_exporter:
     image: nginx/nginx-prometheus-exporter:latest
     ports:
       - "9113:9113"
     command:
       - -nginx.scrape-uri=http://nginx/nginx_status
   ```

3. **Update Prometheus:**
   ```yaml
   # Uncomment in prometheus.yaml
   - job_name: 'nginx'
     static_configs:
       - targets: ['nginx_exporter:9113']
   ```

### Redis Monitoring

Enable Redis metrics collection through Grafana's Redis datasource:

1. **Install Redis Plugin** (uncomment in compose.yaml):
   ```yaml
   # Uncomment in compose.yaml under grafana environment
   # - GF_INSTALL_PLUGINS=redis-datasource
   ```

2. **Configure Redis Datasource:**
   ```yaml
   # Uncomment in grafana/provisioning/datasources/datasource.yml
   - name: Redis
     type: redis-datasource
     url: redis://redis:6379
   ```

3. **Network Configuration:**
   ```yaml
   # Ensure Redis and Grafana are on the same network
   networks:
     - monitoring-network
   ```

### External Service Integration

The monitoring stack can be extended to monitor external services:

#### API Endpoint Monitoring
```yaml
# Add to prometheus.yaml
- job_name: 'api-endpoints'
  metrics_path: /metrics
  static_configs:
    - targets: ['api.example.com:8080']
```

#### Custom Application Metrics
```yaml
# Add custom application monitoring
- job_name: 'custom-app'
  static_configs:
    - targets: ['app:9090']
  scrape_interval: 30s
```

## Security Configuration

### Container Security and User Permissions

#### User Permissions Strategy

**Prometheus: `user: "nobody:nobody"`**
- The `nobody` user is a special unprivileged system account with minimal permissions
- Running Prometheus as `nobody` follows security best practices by:
  - Reducing attack surface if the container is compromised
  - Preventing unauthorized access to host system resources
  - Following the principle of least privilege

**AlertManager: `user: "65534:65534"`**
- This is the numeric user ID (UID) and group ID (GID) for the `nobody` user
- Using numeric IDs instead of names ensures consistency across different Linux distributions
- Both `nobody:nobody` and `65534:65534` achieve the same security goal using different syntax

### Process and System Access

#### Node Exporter: `pid: "host"`
- This configuration shares the host's process namespace with the container
- Required to accurately monitor all processes running on the host system
- Without this setting, Node Exporter would only see processes inside its own container
- Critical for collecting accurate system-wide metrics like:
  - Total process count
  - CPU usage across all processes
  - System-wide load metrics

#### Volume Mounts Security
Node Exporter mounts several system directories in read-only mode:
```yaml
volumes:
  - /proc:/host/proc:ro
  - /sys:/host/sys:ro
  - /:/rootfs:ro
```

This provides necessary system access while maintaining security through:
- **Read-only mounts**: Prevents container from modifying host system
- **Minimal exposure**: Only essential directories are mounted
- **Isolated access**: Container cannot modify host file system

### Network Security

#### Service Isolation
- Services communicate through internal Docker networks
- External access only through explicitly exposed ports
- No unnecessary network permissions or capabilities

#### Port Exposure Strategy
- **3000**: Grafana web interface (external access required)
- **9090**: Prometheus web interface (external access for administration)
- **9093**: AlertManager web interface (external access for administration)
- **3100**: Loki API (external access for log ingestion from external sources)
- **8080, 9100**: Metrics endpoints (consider restricting to internal network in production)

### Data Security

#### Persistent Data Protection
- Data directories use appropriate ownership and permissions
- Backup encryption recommended for sensitive environments
- Secure storage of configuration files containing credentials

#### Credential Management
- Environment variable support for sensitive configuration
- `.env` file for local credential management (not committed to version control)
- Support for Docker secrets in production environments

### Production Security Recommendations

1. **Network Isolation:**
   ```yaml
   # Use custom networks for service isolation
   networks:
     monitoring:
       internal: true  # No external internet access
     frontend:
       # Only for services needing external access
   ```

2. **TLS Configuration:**
   - Enable HTTPS for Grafana in production
   - Use proper SSL certificates
   - Configure TLS for inter-service communication

3. **Authentication:**
   - Change default Grafana credentials immediately
   - Implement LDAP/OAuth integration for user management
   - Enable multi-factor authentication where possible

4. **Resource Limits:**
   ```yaml
   # Add resource constraints to prevent resource exhaustion
   deploy:
     resources:
       limits:
         memory: 512M
         cpus: '0.5'
   ```

5. **Regular Security Updates:**
   - Use specific image tags instead of `latest`
   - Regularly update base images and dependencies
   - Monitor security advisories for used components

## Alerting and Notifications

### Alert Configuration

Alert rules are defined in `alerts.yml` and processed by Prometheus. The system includes pre-configured alerts for common issues:

#### System-Level Alerts
- **InstanceDown**: Triggers when Node Exporter becomes unavailable
- **HighCPULoad**: Alerts when CPU usage exceeds 80% for more than 1 minute
- **HighMemoryLoad**: Warns when memory usage exceeds 80%
- **HighDiskUsage**: Alerts when disk usage exceeds 85% for 5 minutes

#### Custom Alert Examples
```yaml
# Example: Custom application alert
- alert: HighErrorRate
  expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
  for: 2m
  labels:
    severity: warning
  annotations:
    summary: "High error rate detected"
    description: "Error rate is {{ $value }} errors per second"

# Example: Log-based alert (requires Loki)
- alert: TooManyLogErrors
  expr: rate({job="backend-api"} |= "ERROR"[5m]) > 0.5
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "High error log rate"
    description: "Application is logging errors at {{ $value }} per second"
```

### AlertManager Configuration

AlertManager handles alert routing and notifications. The default configuration uses a null receiver, but can be extended:

#### Notification Channels
```yaml
# Example: Email notifications
receivers:
- name: 'email-notifications'
  email_configs:
  - to: 'admin@example.com'
    from: 'monitoring@example.com'
    subject: 'Alert: {{ .GroupLabels.alertname }}'
    body: |
      {{ range .Alerts }}
      Alert: {{ .Annotations.summary }}
      Description: {{ .Annotations.description }}
      {{ end }}

# Example: Slack notifications
- name: 'slack-notifications'
  slack_configs:
  - api_url: 'YOUR_SLACK_WEBHOOK_URL'
    channel: '#monitoring'
    title: 'Alert: {{ .GroupLabels.alertname }}'
    text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

#### Alert Routing
```yaml
# Route critical alerts immediately, warnings with delays
route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default-receiver'
  routes:
  - match:
      severity: critical
    receiver: 'critical-alerts'
    group_wait: 0s
  - match:
      severity: warning
    receiver: 'warning-alerts'
    group_wait: 30s
```

### Alert Testing and Validation

```bash
# Test alert rules syntax
promtool check rules alerts.yml

# Test AlertManager configuration
promtool check config alertmanager.yml

# Manually trigger test alert
curl -X POST http://localhost:9093/api/v1/alerts -H "Content-Type: application/json" -d '[
  {
    "labels": {
      "alertname": "TestAlert",
      "service": "test",
      "severity": "warning"
    },
    "annotations": {
      "summary": "This is a test alert"
    }
  }
]'
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Permission Denied When Backing Up Data
```bash
# Solution 1: Use container-based backup method
docker run --rm -v $(pwd)/data:/source -v $(pwd)/backups:/backup alpine tar -czf /backup/grafana_backup.tar.gz -C /source grafana

# Solution 2: Fix ownership (Linux/macOS)
sudo chown -R $(id -u):$(id -g) data/
```

#### 2. AlertManager Keeps Restarting
```bash
# Check logs for configuration errors
docker logs alertmanager

# Validate AlertManager configuration
promtool check config alertmanager.yml

# Check file permissions
ls -la alertmanager.yml
```

#### 3. Data Retention Script Not Finding Old Data
```bash
# Run with debug output
bash -x ./scripts/data-retention.sh

# Check if data directories exist
ls -la data/prometheus/

# Verify file permissions and ownership
find data/prometheus/ -type d -mtime +16 -ls
```

#### 4. Dashboard Shows No Data
```bash
# Check service status
./update.sh --status

# Verify Node Exporter is collecting metrics
curl http://localhost:9100/metrics

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Verify network connectivity
docker network ls
docker network inspect monitoring-network
```

#### 5. Loki Not Receiving Logs
```bash
# Check Alloy configuration and status
docker logs alloy

# Verify Loki is accessible
curl http://localhost:3100/ready

# Test log ingestion
curl -X POST "http://localhost:3100/loki/api/v1/push" \
  -H "Content-Type: application/json" \
  -d '{"streams": [{"stream": {"job": "test"}, "values": [["'$(date +%s)'000000000", "test log message"]]}]}'

# Check Alloy metrics and targets
curl http://localhost:12345/metrics

# Verify Alloy configuration syntax
docker exec alloy alloy fmt /etc/alloy/config.alloy
```

#### 6. High Resource Usage
```bash
# Monitor container resource usage
docker stats

# Check Prometheus memory usage
curl http://localhost:9090/api/v1/query?query=prometheus_tsdb_symbol_table_size_bytes

# Optimize Loki configuration for lower resource usage
# Edit loki/loki-config.yaml and reduce cache sizes
```

#### 8. Node Exporter Full Dashboard Query Issues
```bash
# If the Node Exporter Full dashboard shows "N/A" for filesystem metrics
# This happens when using Alloy instead of traditional node-exporter

# Check if metrics are available with different mountpoint labels
curl http://localhost:9090/api/v1/query?query=node_filesystem_size_bytes

# The dashboard expects mountpoint="/rootfs/..." but Alloy uses mountpoint="/..."
# To fix: Edit dashboard queries to use the correct mountpoint pattern or
# Use the "Node Exporter Server Metrics" dashboard which works better with Alloy
```

> **Tip**: When using Grafana Alloy, the "Node Exporter Server Metrics" (ID: 11076) dashboard works better than "Node Exporter Full" (ID: 1860) for filesystem monitoring due to different mountpoint labeling.

### Debugging Commands

#### Health Check Commands
```bash
# Check all service health endpoints
curl -f http://localhost:9090/-/healthy   # Prometheus
curl -f http://localhost:3000/api/health  # Grafana
curl -f http://localhost:9093/-/healthy   # AlertManager
curl -f http://localhost:3100/ready       # Loki
curl -f http://localhost:12345/metrics     # Alloy
curl -f http://localhost:8080/healthz     # cAdvisor
```

#### Configuration Validation
```bash
# Validate all configurations
promtool check config prometheus.yaml
promtool check rules alerts.yml

# Check Grafana configuration
docker exec grafana grafana-cli admin settings list

# Validate Docker Compose
docker compose config
```

#### Performance Troubleshooting
```bash
# Check query performance
curl "http://localhost:9090/api/v1/query?query=up" | jq '.data.result | length'

# Monitor query duration
curl "http://localhost:9090/api/v1/query?query=prometheus_engine_query_duration_seconds"

# Check Loki query performance
curl "http://localhost:3100/loki/api/v1/query?query={job=\"test\"}&limit=10"
```

## Best Practices and Recommendations

### Operational Best Practices

1. **Regular Monitoring of the Monitoring Stack**
   - Monitor disk usage growth patterns
   - Set up alerts for the monitoring infrastructure itself
   - Track query performance and optimize slow dashboards
   - Monitor container resource usage and set appropriate limits

2. **Data Management**
   - Regularly verify backup integrity and test restore procedures
   - Implement automated cleanup of old log files
   - Monitor data growth trends and adjust retention policies accordingly
   - Use compression for long-term data storage

3. **Alert Management**
   - Update alert thresholds based on your system's baseline performance
   - Implement alert fatigue reduction strategies (grouping, suppression)
   - Regular review and optimization of alert rules
   - Test notification channels periodically

4. **Security Considerations**
   - Change default Grafana credentials immediately after setup
   - Implement proper network isolation in production environments
   - Regular security updates for all container images
   - Use secrets management for sensitive configuration data
   - Enable audit logging for administrative actions

5. **Performance Optimization**
   - Optimize Prometheus queries for better dashboard performance
   - Configure appropriate scrape intervals based on your needs
   - Use recording rules for frequently computed metrics
   - Implement proper log sampling for high-volume applications

### Production Deployment Guidelines

#### Scaling Considerations
```yaml
# Example: Production resource limits
services:
  prometheus:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 1G
          cpus: '0.5'

  grafana:
    deploy:
      resources:
        limits:
          memory: 512M
          cpus: '0.5'
```

#### High Availability Setup
- Consider Prometheus federation for multi-site monitoring
- Implement Grafana clustering for high availability
- Use external databases for Grafana configuration storage
- Set up redundant AlertManager instances

#### Backup Strategy for Production
```bash
# Example: Production backup with encryption
./scripts/backup.sh
gpg --symmetric --cipher-algo AES256 backups/grafana_$(date +%Y-%m-%d).tar.gz
```

### Integration Guidelines

#### CI/CD Integration
- Integrate monitoring setup in your deployment pipeline
- Automate dashboard updates through version control
- Include alert rule testing in CI processes
- Implement infrastructure as code for monitoring configuration

#### Application Integration
- Implement structured logging in applications
- Add custom metrics endpoints for business metrics
- Use consistent labeling across all monitored services
- Implement health checks and readiness probes

### Compliance and Auditing

#### Data Retention Compliance
- Configure appropriate retention periods for regulatory requirements
- Implement audit trails for configuration changes
- Regular backup verification and disaster recovery testing
- Document monitoring procedures and runbooks

## Contributing and Support

### Contributing to the Project

This monitoring stack is designed to be extensible and customizable. Contributions are welcome:

1. **Dashboard Improvements**: Submit new dashboard configurations or improvements to existing ones
2. **Alert Rules**: Contribute useful alert rules for common scenarios
3. **Integration Examples**: Add examples for monitoring additional services
4. **Documentation**: Improve documentation and troubleshooting guides
5. **Bug Fixes**: Report and fix issues with the monitoring stack

### Getting Help

- **Documentation**: Start with this comprehensive README and inline comments
- **Logs**: Check service logs using `docker logs <service_name>`
- **Health Checks**: Use the built-in health check endpoints
- **Community**: Leverage Prometheus, Grafana, and Loki community resources

### Version Information

This monitoring stack is regularly updated to include:
- Latest stable versions of all components
- Security patches and updates
- New features and integrations
- Improved documentation and examples

## Resources and References

### Official Documentation
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [Grafana Alloy Documentation](https://grafana.com/docs/alloy/)
- [Promtail to Alloy Migration Guide](https://grafana.com/docs/alloy/latest/tasks/migrate/from-promtail/)
- [AlertManager Documentation](https://prometheus.io/docs/alerting/latest/alertmanager/)

### Community Resources
- [Grafana Dashboard Library](https://grafana.com/grafana/dashboards/)
- [Prometheus Community](https://prometheus.io/community/)
- [Docker Monitoring Best Practices](https://docs.docker.com/config/daemon/prometheus/)

### Useful Tools
- [Promtool](https://prometheus.io/docs/prometheus/latest/command-line/promtool/) - Prometheus configuration validation
- [LogQL Documentation](https://grafana.com/docs/loki/latest/logql/) - Loki query language
- [Alert Rule Examples](https://awesome-prometheus-alerts.grep.to/) - Community alert rules

Created and maintained with ❤️ for robust infrastructure monitoring

---

*Last updated: May 18, 2026*
*Version: 4.0 - Centralized Monitoring with Optional Logging*

### Recent Updates (v4.0)
- **Centralized Monitoring**: Monitor remote VMs by deploying only node-exporter on them
- **Optional Log Aggregation**: Loki + Alloy moved behind Docker Compose profiles (`--profile logs`)
- **File-Based Service Discovery**: Add remote targets via JSON files with 30s auto-discovery
- **All Images Pinned**: cAdvisor pinned to v0.45.0, no more unpinned `:latest` tags
- **Bug Fixes**: Fixed version mismatches, remote exporter script bug, profile-aware stop/update
- **New Flags**: `--with-logs` flag on setup.sh and update.sh for optional log aggregation

### Previous Updates (v3.1)
- **Hybrid Architecture**: Docker-based metrics exporters (node-exporter, cadvisor) with Alloy for log collection
- **Optimized Performance**: Specialized exporters for reliable metrics collection
- **Updated Scripts**: Modified setup.sh and stop.sh to handle Docker-based exporters

### Previous Updates (v3.0)
- **Complete Architecture Redesign**: Unified Grafana Alloy agent replaces multiple specialized collectors
- **Simplified Deployment**: Single `compose.yaml` file for all platforms instead of platform-specific configurations
- **Enhanced Log Processing**: Advanced log collection and processing capabilities through Alloy