#!/bin/bash

# Parameters
BACKUP_DIR="./backups"
DATA_DIR="./data"
CONFIG_FILES=("./prometheus.yaml" "./alerts.yml" "./alertmanager.yml")

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Format date for file name
DATE=$(date +"%Y-%m-%d")

# Backup Grafana data
if [ -d "$DATA_DIR/grafana" ]; then
    GRAFANA_BACKUP="$BACKUP_DIR/grafana_$DATE.tar.gz"
    echo "Creating Grafana backup: $GRAFANA_BACKUP"
    
    # Gunakan sudo untuk mengatasi permission issues
    sudo tar -czf "$GRAFANA_BACKUP" -C "$DATA_DIR" grafana
    # Reset ownership dari backup file ke user yang menjalankan script
    sudo chown $(whoami):$(whoami) "$GRAFANA_BACKUP"
    
    echo "Grafana backup completed."
fi

# Backup Prometheus configuration files
CONFIG_BACKUP="$BACKUP_DIR/prometheus_config_$DATE.tar.gz"
echo -e "\nCreating Prometheus configuration backup: $CONFIG_BACKUP"
tar -czf "$CONFIG_BACKUP" "${CONFIG_FILES[@]}"
echo "Prometheus configuration backup completed."

# Optional: Backup only the most recent Prometheus data
if [ -d "$DATA_DIR/prometheus" ]; then
    PROMETHEUS_BACKUP="$BACKUP_DIR/prometheus_recent_$DATE.tar.gz"
    echo -e "\nCreating recent Prometheus data backup: $PROMETHEUS_BACKUP"
    
    # Find the most recent directories only (adjust the -mtime value as needed)
    find "$DATA_DIR/prometheus" -type d -mtime -7 | tar -czf "$PROMETHEUS_BACKUP" -T -
    
    echo "Recent Prometheus data backup completed."
fi

echo "All backups completed to $BACKUP_DIR"