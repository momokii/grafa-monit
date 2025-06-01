# Grafana-Host-Monitoring

A complete monitoring solution for host systems using Prometheus, Grafana, Node Exporter, AlertManager, and cAdvisor.

## Overview

This project provides a containerized monitoring stack for system metrics collection, storage, visualization, and alerting. It's designed with data retention strategies and automated backup procedures to ensure reliability and efficient resource usage.

## Architecture

The monitoring stack includes:

- **Node Exporter**: Collects system metrics (CPU, memory, disk, network)
- **Prometheus**: Time-series database for metrics storage
- **Grafana**: Visualization and dashboarding
- **AlertManager**: Alert handling and notifications
- **cAdvisor**: Container metrics collection

## Project Structure

```
grafana-host-monitoring/
├── compose.yaml                # Docker Compose configuration
├── prometheus.yaml             # Prometheus configuration
├── alerts.yml                  # Alert rules
├── alertmanager.yml            # AlertManager configuration
├── data/                       # Data storage (gitignored)
│   ├── prometheus/             # Prometheus data
│   └── grafana/                # Grafana data
├── archives/                   # Long-term data archive (gitignored)
├── backups/                    # Backup storage (gitignored)
├── logs/                       # Application logs (gitignored)
│   ├── prometheus/
│   ├── grafana/
│   └── alertmanager/
├── grafana/                    # Grafana configuration
│   └── provisioning/
│       ├── dashboards/         # Auto-provisioned dashboards
│       └── datasources/        # Auto-provisioned data sources
├── scripts/
│   ├── data-retention.sh       # Data retention management
│   ├── backup.sh               # Backup script
│   └── maintenance.sh          # Combined maintenance script
└── README.md                   # This documentation
```

## Setup and Configuration

### Prerequisites
- Docker and Docker Compose
- Bash shell (Git Bash on Windows)
- 2GB+ RAM recommended
- 10GB+ disk space (depends on retention policies)

### Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/grafana-host-monit.git
   cd grafana-host-monit
   ```

2. Create required directories:
   ```bash
   mkdir -p data/prometheus data/grafana logs/prometheus logs/grafana logs/alertmanager archives backups
   ```

3. Start the monitoring stack:
   ```bash
   docker-compose up -d
   ```

4. Access the interfaces:
   - Grafana: http://localhost:3000 (admin/admin)
   - Prometheus: http://localhost:9090
   - AlertManager: http://localhost:9093
   - cAdvisor: http://localhost:8080

## Pre-Configured Dashboards

The monitoring stack comes with pre-configured dashboards for immediate visibility into your systems. These dashboards are automatically provisioned when Grafana starts.

### Host System Monitoring

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

#### 3. Container Metrics Dashboard (ID: 19908)

Built to visualize cAdvisor metrics for container monitoring:

- Per-container CPU usage
- Memory consumption analysis
- Network traffic per container
- Disk I/O operations
- Container health indicators

Essential for environments running multiple containers to identify resource-intensive containers and performance bottlenecks.

### Alerting Overview

#### 4. Alert Dashboard

A custom dashboard showing:

- Current alert status
- Historical alert triggers
- Alert grouping by severity
- Time-based analysis of incidents
- Alert resolution tracking

Provides a consolidated view of system health and ongoing incidents.

### Accessing Dashboards

1. Open Grafana at http://localhost:3000
2. Log in with your credentials (default: admin/admin)
3. Navigate to Dashboards > General to see all pre-configured dashboards

### Customizing Dashboards

These dashboards can be customized to suit your specific needs:

1. Open a dashboard
2. Click the gear icon in the top menu
3. Select "Save As..." to create your own copy
4. Modify panels, thresholds, and visualizations as needed

Your customized dashboards will persist in the Grafana data volume.

## Data Retention Strategy

This project implements a multi-tier storage strategy:

### 1. Hot Storage (Prometheus Native)
- **Duration**: 0-15 days (configured in `compose.yaml`)
- **Location**: `data/prometheus`
- **Management**: Native Prometheus retention (`--storage.tsdb.retention.time=15d`)
- **Purpose**: Active querying and recent metrics

```yaml
prometheus:
  command:
    - '--storage.tsdb.retention.time=15d'  # Prometheus will delete data after 15 days
```

### 2. Warm Storage (Archives)
- **Duration**: 16-90 days (configured in `data-retention.sh`)
- **Location**: `./archives`
- **Management**: Custom `data-retention.sh` script
- **Purpose**: Historical data for occasional access

```bash
# data-retention.sh
RETENTION_DAYS=16      # One day buffer after Prometheus retention
ARCHIVE_RETENTION_DAYS=90
```

### Why 15 vs 16 days?

The 1-day buffer between Prometheus native retention (15 days) and our archiving script (16 days) serves as a safety mechanism:

1. Prometheus marks data for deletion at 15 days but may not immediately delete it
2. The `data-retention.sh` script archives data older than 16 days
3. This ensures data is safely archived before Prometheus completely removes it
4. No data duplication in the interim period (data exists either in Prometheus or archive)

### 3. Cold Storage (Backups)
- **Duration**: Based on external storage policies
- **Location**: `backups`
- **Management**: `backup.sh` script
- **Purpose**: Disaster recovery and compliance

## Backup Strategy

The backup system captures:

1. **Configuration**: All config files for Prometheus, AlertManager, and alert rules
2. **Grafana Data**: Dashboards, users, and other Grafana state
3. **Recent Metrics**: Last 7 days of metrics data (configurable)

Run backups manually:
```bash
./backup.sh
```

## Restore Functionality

The monitoring stack includes a robust restore system to recover from data loss or system migration. The restore script complements the existing backup procedures and provides a structured way to restore different components.

### Restore Script

Located at `scripts/restore.sh`, this script provides the following capabilities:

- List available backups in both backups and archives directories
- Restore Grafana data and configuration
- Restore Prometheus configuration files (prometheus.yaml, alerts.yml)
- Restore Prometheus metrics data

### Usage

```bash
# Make script executable (first time only)
chmod +x ./scripts/restore.sh

# or ofcourse you can using bash
bash ./scripts/restore.sh

# List all available backups
./scripts/restore.sh list

# Restore Grafana data
./scripts/restore.sh grafana ./backups/grafana_2025-05-30.tar.gz

# Restore Prometheus configuration
./scripts/restore.sh prometheus-config ./backups/prometheus_config_2025-05-30.tar.gz

# Restore Prometheus data
./scripts/restore.sh prometheus-data ./backups/prometheus_recent_2025-05-30.tar.gz
```

## Maintenance Scripts

### Data Retention Script

Manages the archiving and deletion of old metrics data:

```bash
./data-retention.sh
```

Parameters:
- `RETENTION_DAYS`: When to archive data (16 days)
- `ARCHIVE_RETENTION_DAYS`: When to delete archives (90 days)

### Backup Script

Creates compressed backups of configuration and data:

```bash
./backup.sh
```

Parameters:
- `BACKUP_DIR`: Where backups are stored (`./backups`)
- `DATA_DIR`: Source data directory (`./data`)

### Combined Maintenance

For scheduled maintenance, use:

```bash
./maintenance.sh
```

This runs backup first, then retention management.

## Scheduled Operations

For Windows:
```powershell
# Schedule weekly maintenance
schtasks /create /tn "GrafanaPrometheusWeeklyMaintenance" /tr "C:\Program Files\Git\bin\bash.exe -c 'cd /d/path/to/grafana-host-monit && ./maintenance.sh'" /sc weekly /d SUN /st 02:00
```

For Linux/MacOS:
```bash
# Add to crontab
0 2 * * 0 cd /path/to/grafana-host-monit && ./maintenance.sh > ./logs/maintenance.log 2>&1
```

## Permission Handling

Docker containers run with specific users to enhance security:

- Prometheus: `nobody:nobody` (user ID 65534)
- Grafana: Uses default Grafana user
- AlertManager: Uses `nobody:nobody` (user ID 65534)

This may cause permission issues when backing up data. The backup script uses either:
- Container-based backup (recommended)
- Elevated permissions through sudo

## Container Security and Technical Details

### User Permissions

#### Prometheus: `user: "nobody:nobody"`
- The `nobody` user is a special unprivileged system account with minimal permissions
- Running Prometheus as `nobody` follows security best practices by:
  - Reducing attack surface if the container is compromised
  - Preventing unauthorized access to host system resources
  - Following the principle of least privilege

#### AlertManager: `user: "65534:65534"`
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

#### Volume Mounts
Node Exporter mounts several system directories:
```yaml
volumes:
  - /proc:/host/proc:ro
  - /sys:/host/sys:ro
  - /:/rootfs:ro

## Alerts

Alert rules are defined in `alerts.yml` and processed by Prometheus. Notifications are managed by AlertManager.

Common alerts included:
- High CPU usage
- Memory pressure
- Disk space running low
- Service downtime

## Troubleshooting

### Common Issues

1. **Permission denied when backing up data**:
   ```bash
   # Use the container-based backup method
   docker run --rm -v $(pwd)/data:/source -v $(pwd)/backups:/backup alpine tar -czf /backup/grafana_backup.tar.gz -C /source grafana
   ```

2. **Alertmanager keeps restarting**:
   - Check `docker-compose logs alertmanager` for configuration errors
   - Verify `alertmanager.yml` syntax and permissions

3. **Data retention script not finding old data**:
   - Check if `data/prometheus/chunks_head` exists
   - Run with debug flag: `bash -x ./data-retention.sh`
   - Verify file permissions

4. **Dashboard shows no data**:
   - Verify Node Exporter is running: `docker-compose ps node-exporter`
   - Check Prometheus targets: http://localhost:9090/targets
   - Ensure proper network configuration in `compose.yaml`

## Best Practices

1. **Monitor disk usage** - Data can grow quickly
2. **Regularly verify backups** - Test restore procedures
3. **Update alert thresholds** - Adjust based on your system's baseline
4. **Security considerations** - Use secure passwords, consider network isolation

Created and maintained with ❤️ 

*Last updated: June 1, 2025*