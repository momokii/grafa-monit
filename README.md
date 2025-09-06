# Grafana Host Monitoring Stack

A comprehensive monitoring and observability solution for host systems and containerized applications, featuring metrics collection, log aggregation, visualization, and alerting capabilities.

## Overview

This project provides a complete containerized monitoring stack that combines metrics monitoring with centralized logging. It's designed with data retention strategies, automated backup procedures, and cross-platform compatibility to ensure reliability and efficient resource usage across different environments.

## Architecture

The monitoring stack includes:

### Core Monitoring Services
- **Prometheus**: Time-series database for metrics storage and querying
- **Grafana**: Unified visualization platform for metrics and logs
- **AlertManager**: Alert handling, routing, and notifications

### Unified Observability Services
- **Grafana Alloy**: Next-generation unified observability agent that provides:
  - **System Metrics Collection**: Replaces node-exporter for host system metrics
  - **Container Metrics Collection**: Replaces cAdvisor for Docker container metrics
  - **Log Collection**: Advanced log aggregation and shipping to Loki
- **Loki**: Log aggregation system with efficient storage and querying

> **Architecture Simplification**: This monitoring stack now uses **Grafana Alloy as a unified observability agent**, replacing the previous separate components (node-exporter, cAdvisor, and Promtail) with a single, more efficient solution.

### Optional Services (Configurable)
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
├── setup.sh                     # Simplified setup script
├── stop.sh                      # Service management script
├── update.sh                    # Update and restart script
├── data/                        # Data storage (gitignored)
│   ├── prometheus/              # Prometheus TSDB data
│   ├── grafana/                 # Grafana database and plugins
│   ├── loki/                    # Loki chunks and index data
│   └── alloy_data/              # Alloy persistent storage and positions
├── logs/                        # Application logs (gitignored)
│   ├── grafana/                 # Grafana application logs
│   ├── alertmanager/            # AlertManager logs
│   ├── api/                     # Backend API logs
│   ├── nginx/                   # Nginx access and error logs
│   └── app/                     # Custom application logs
├── archives/                    # Long-term data archive (gitignored)
├── backups/                     # Configuration and data backups (gitignored)
├── loki/                        # Loki configuration
│   └── loki-config.yaml
├── alloy/                       # Grafana Alloy configuration (primary log collector)
│   └── alloy-config.alloy
├── promtail/                    # Legacy Promtail configuration (deprecated)
│   └── promtail-config.yaml
├── promtail-to-alloy-config.sh  # Migration script for converting Promtail to Alloy config
├── grafana/                     # Grafana provisioning
│   └── provisioning/
│       ├── dashboards/          # Auto-provisioned dashboards
│       │   ├── dashboard.yml    # Dashboard provider config
│       │   ├── 1860.json        # Node Exporter Full dashboard
│       │   ├── 11076.json       # Node Exporter Server Metrics
│       │   ├── 19908.json       # cAdvisor Docker Insights
│       │   ├── 9628.json        # PostgreSQL Database dashboard
│       │   ├── nginx.json       # Nginx Exporter dashboard
│       │   ├── redis.json       # Redis monitoring dashboard
│       │   ├── redis-streaming.json # Redis streaming dashboard
│       │   └── alerts.json      # Alert History dashboard
│       └── datasources/         # Auto-provisioned data sources
│           └── datasource.yml   # Prometheus, Loki, and Redis configs
└── scripts/                     # Maintenance and utility scripts
    ├── backup.sh                # Backup script for data and configs
    ├── restore.sh               # Restore script for disaster recovery
    ├── data-retention.sh        # Data archiving and cleanup
    └── maintenance.sh           # Combined maintenance operations

### Migration and Conversion Tools

- **promtail-to-alloy-config.sh**: Automated script for converting Promtail YAML configurations to Alloy format
  ```bash
  # Convert Promtail configuration to Alloy
  ./promtail-to-alloy-config.sh promtail/promtail-config.yaml
  
  # Interactive conversion with options
  ./promtail-to-alloy-config.sh
  
  # Specify custom output location
  ./promtail-to-alloy-config.sh -o alloy/custom-config.alloy promtail-config.yaml
  ```
```

## Setup and Configuration

### Prerequisites
- Docker Engine 20.10+ and Docker Compose 2.0+
- Bash shell (Git Bash on Windows, native on Linux/macOS)
- 4GB+ RAM recommended (2GB minimum)
- 20GB+ disk space (depends on retention policies and log volume)
- Network ports 3000, 3100, 9090, 9093, 12345 available

### Cross-Platform Support

This monitoring stack uses a **unified Docker Compose configuration** that works across different platforms:

- **Simplified Architecture**: Single `compose.yaml` file for all platforms
- **Unified Alloy Agent**: Replaces multiple specialized agents with one efficient solution
- **Consistent Performance**: Same functionality across Linux, Windows, and macOS environments

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone https://github.com/yourusername/grafana-host-monit.git
   cd grafana-host-monit
   ```

2. **Run the setup script:**
   ```bash
   # The script automatically configures the unified monitoring stack
   chmod +x setup.sh
   ./setup.sh
   
   # Or using bash directly
   bash setup.sh
   ```

3. **Access the interfaces:**
   - **Grafana**: http://localhost:3000 (admin/admin)
   - **Prometheus**: http://localhost:9090
   - **AlertManager**: http://localhost:9093
   - **Loki**: http://localhost:3100

> **Note**: Grafana credentials can be customized by setting `GF_SECURITY_ADMIN_USER` and `GF_SECURITY_ADMIN_PASSWORD` environment variables in your `.env` file before starting the services.
   - **Grafana Alloy**: http://localhost:12345/metrics

## Unified Observability with Grafana Alloy

This monitoring stack has been **completely redesigned around Grafana Alloy** as a unified observability agent, providing significant simplifications and improvements:

### Architecture Simplification

**Previous Architecture** (Multiple Agents):
- Node Exporter (system metrics)
- cAdvisor (container metrics) 
- Promtail/Alloy (log collection)
- Multiple ports and configurations

**Current Architecture** (Unified Agent):
- **Grafana Alloy**: Single agent handling all observability data
  - System metrics collection (replaces node-exporter)
  - Container metrics collection (replaces cAdvisor)
  - Log collection and processing
  - Unified configuration and management

### Benefits of Unified Approach

- **Simplified Deployment**: Single `compose.yaml` file instead of platform-specific configurations
- **Reduced Resource Usage**: One agent instead of multiple specialized collectors
- **Unified Configuration**: Single Alloy configuration file for all observability data
- **Better Performance**: Optimized data collection and processing pipeline
- **Future-Proof**: Built on Grafana's next-generation observability platform

### Current Configuration Capabilities

The Alloy configuration provides comprehensive observability coverage:

- **System Metrics**: CPU, memory, disk, network metrics (via `prometheus.exporter.unix`)
- **Container Metrics**: Docker container resource usage (via `prometheus.exporter.cadvisor`)
- **System Logs**: Journal logs and file-based log collection
- **Container Logs**: Docker container log collection with parsing
- **Unified Export**: Both metrics and logs sent to appropriate destinations

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
- **Purpose**: Initial setup and configuration of the unified monitoring stack
- **Features**: Directory creation, network setup, permission handling, service orchestration
- **Usage**: 
  ```bash
  ./setup.sh                    # Full setup with all checks
  ./setup.sh --quick            # Quick setup for development
  ./setup.sh --skip-pull        # Setup without pulling latest images
  ```

#### Stop Script (`stop.sh`)
- **Purpose**: Service shutdown and cleanup
- **Features**: Graceful shutdown, container removal, data preservation options
- **Usage**:
  ```bash
  ./stop.sh                     # Stop and remove containers (default)
  ./stop.sh -s                  # Stop services only (keep containers)
  ./stop.sh --all               # Remove everything (containers, volumes, networks, images, data)
  ./stop.sh --status            # Show current status
  ```

#### Update Script (`update.sh`)
- **Purpose**: Update images and restart services
- **Features**: Configuration validation, backup creation, rolling updates
- **Usage**:
  ```bash
  ./update.sh                   # Default: validate, backup, rolling restart
  ./update.sh -f                # Full restart with validation and backup
  ./update.sh -c                # Only reload configurations
  ./update.sh -u                # Update images and restart services
  ```

## Monitoring Capabilities

### Metrics Collection and Monitoring

The stack provides comprehensive metrics monitoring through the unified Alloy agent:

- **Host System Metrics**: CPU, memory, disk usage, network traffic, system load (via Alloy's unix exporter)
- **Container Metrics**: Resource usage, performance, and health status for all running containers (via Alloy's cAdvisor exporter)
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

The monitoring stack comes with pre-configured dashboards for immediate visibility into your systems. These dashboards are automatically provisioned when Grafana starts and cover both metrics and logs.

### System Monitoring Dashboards

#### 1. Node Exporter Full Dashboard (ID: 1860)

This comprehensive dashboard provides detailed metrics about your host system:

- Hardware status (CPU, memory, disk)
- System load and resource utilization
- Network traffic and statistics
- Disk I/O performance metrics
- System processes and service status

Perfect for system administrators who need complete visibility into server health and performance.

#### 2. Node Exporter Server Metrics (ID: 11074)

A streamlined dashboard focused on key server metrics:

- Core system performance indicators
- Resource utilization over time
- Critical system metrics
- Basic performance analysis

Ideal for quick system health checks and status monitoring.

### Container Monitoring

#### 3. cAdvisor Docker Insights Dashboard (ID: 19908)

Built to visualize cAdvisor metrics for comprehensive container monitoring:

- Per-container CPU and memory usage trends
- Network I/O statistics for each container
- Disk I/O operations and storage metrics
- Container health indicators and restart counts
- Resource limit utilization and throttling

Essential for environments running multiple containers to identify resource-intensive containers and performance bottlenecks.

### Database Monitoring

#### 4. PostgreSQL Database Dashboard (ID: 9628)

Comprehensive database performance monitoring (available when postgres_exporter is enabled):

- Database connection metrics and active sessions
- Query performance and slow query analysis
- Database size, table statistics, and index usage
- Lock monitoring and blocking query detection
- Replication status and WAL metrics

Critical for database administrators monitoring PostgreSQL performance and health.

### Web Server Monitoring

#### 5. Nginx Exporter Dashboard (ID: 12708)

Web server performance monitoring (available when nginx_exporter is enabled):

- Request rate, response time, and error rate metrics
- Active connections and connection handling
- Upstream server status and load balancing metrics
- HTTP status code distribution
- Server resource utilization

Perfect for monitoring web application performance and identifying bottlenecks.

### Caching and Data Store Monitoring

#### 6. Redis Monitoring Dashboard

Real-time Redis performance monitoring (available when Redis datasource is configured):

- Memory usage patterns and key expiration
- Command execution statistics and slow commands
- Connected clients and blocked clients
- Hit/miss ratios for cache effectiveness
- Replication and persistence metrics

#### 7. Redis Streaming Dashboard

Advanced Redis streaming and pub/sub monitoring:

- Stream processing metrics and consumer groups
- Message throughput and processing lag
- Pub/sub channel statistics
- Real-time data flow visualization

### Alerting and Incident Management

#### 8. Alert History Dashboard

A custom dashboard providing comprehensive alerting overview:

- Current active alerts with severity classification
- Historical alert patterns and trends
- Alert resolution time analysis
- Time-based incident analysis
- Alert grouping by service and severity

Provides a consolidated view of system health, ongoing incidents, and historical patterns for proactive monitoring.

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

1. **Install Redis Plugin** (already configured in Grafana):
   ```yaml
   # Already enabled in compose files
   environment:
     - GF_INSTALL_PLUGINS=redis-datasource
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

*Last updated: August 30, 2025*  
*Version: 3.0 - Unified Alloy-Based Observability Stack*

### Recent Updates (v3.0)
- **Complete Architecture Redesign**: Unified Grafana Alloy agent replaces multiple specialized collectors
- **Simplified Deployment**: Single `compose.yaml` file for all platforms instead of platform-specific configurations
- **Unified Metrics Collection**: Alloy now handles system metrics (replaces node-exporter) and container metrics (replaces cAdvisor)
- **Enhanced Log Processing**: Advanced log collection and processing capabilities through Alloy
- **Streamlined Scripts**: Simplified setup, stop, and update scripts reflecting the unified architecture
- **Reduced Resource Usage**: Single agent approach reduces overall system resource consumption
- **Future-Proof Foundation**: Built on Grafana's next-generation observability platform