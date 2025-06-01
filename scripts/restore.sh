#!/bin/bash

# Parameters
BACKUP_DIR="./backups"
DATA_DIR="./data"
ARCHIVE_DIR="./archives"

# Function to list available backups
list_backups() {
    echo "Available Grafana backups:"
    find "$BACKUP_DIR" -name "grafana_*.tar.gz" | sort
    
    echo -e "\nAvailable Prometheus config backups:"
    find "$BACKUP_DIR" -name "prometheus_config_*.tar.gz" | sort
    
    echo -e "\nAvailable Prometheus data backups:"
    find "$BACKUP_DIR" -name "prometheus_recent_*.tar.gz" | sort
    
    echo -e "\nAvailable Prometheus archives:"
    find "$ARCHIVE_DIR" -name "prometheus_*.tar.gz" | sort
}

# Function to restore Grafana data
restore_grafana() {
    if [ -z "$1" ]; then
        echo "Error: Please specify Grafana backup file to restore"
        return 1
    fi
    
    BACKUP_FILE="$1"
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "Error: Backup file $BACKUP_FILE not found"
        return 1
    fi
    
    echo "Stopping Grafana container..."
    docker-compose stop grafana
    
    echo "Restoring Grafana data from $BACKUP_FILE..."
    # Backup current data first
    if [ -d "$DATA_DIR/grafana" ]; then
        TEMP_BACKUP="$BACKUP_DIR/grafana_pre_restore_$(date +"%Y-%m-%d_%H-%M-%S").tar.gz"
        echo "Creating temporary backup of current data to $TEMP_BACKUP"
        sudo tar -czf "$TEMP_BACKUP" -C "$DATA_DIR" grafana
        sudo chown $(whoami):$(whoami) "$TEMP_BACKUP"
        
        # Remove current data to avoid conflicts
        echo "Removing current Grafana data"
        sudo rm -rf "$DATA_DIR/grafana"
    fi
    
    # Create data dir if it doesn't exist
    mkdir -p "$DATA_DIR"
    
    # Restore the backup
    echo "Extracting backup file..."
    sudo tar -xzf "$BACKUP_FILE" -C "$DATA_DIR"
    sudo chown -R 472:472 "$DATA_DIR/grafana"  # Set Grafana permissions (UID 472 is grafana)
    
    echo "Starting Grafana container..."
    docker-compose up -d grafana
    
    echo "Grafana restore completed."
}

# Function to restore Prometheus configuration
restore_prometheus_config() {
    if [ -z "$1" ]; then
        echo "Error: Please specify Prometheus config backup file to restore"
        return 1
    fi
    
    BACKUP_FILE="$1"
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "Error: Backup file $BACKUP_FILE not found"
        return 1
    fi
    
    echo "Restoring Prometheus configuration from $BACKUP_FILE..."
    
    # Backup current configs first
    CONFIG_FILES=("./prometheus.yaml" "./alerts.yml" "./alertmanager.yml")
    TEMP_BACKUP="$BACKUP_DIR/prometheus_config_pre_restore_$(date +"%Y-%m-%d_%H-%M-%S").tar.gz"
    
    echo "Creating temporary backup of current configuration to $TEMP_BACKUP"
    tar -czf "$TEMP_BACKUP" "${CONFIG_FILES[@]}" 2>/dev/null
    
    # Extract new configuration
    echo "Extracting configuration files..."
    tar -xzf "$BACKUP_FILE" -C "./"
    
    echo "Reloading Prometheus and Alertmanager..."
    docker-compose exec prometheus killall -HUP prometheus
    docker-compose exec alertmanager killall -HUP alertmanager
    
    echo "Prometheus configuration restore completed."
}

# Function to restore Prometheus data
restore_prometheus_data() {
    if [ -z "$1" ]; then
        echo "Error: Please specify Prometheus data backup file to restore"
        return 1
    fi
    
    BACKUP_FILE="$1"
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "Error: Backup file $BACKUP_FILE not found"
        return 1
    fi
    
    echo "Stopping Prometheus container..."
    docker-compose stop prometheus
    
    echo "Restoring Prometheus data from $BACKUP_FILE..."
    # Backup current data first
    if [ -d "$DATA_DIR/prometheus" ]; then
        TEMP_BACKUP="$BACKUP_DIR/prometheus_pre_restore_$(date +"%Y-%m-%d_%H-%M-%S").tar.gz"
        echo "Creating temporary backup of current data to $TEMP_BACKUP"
        sudo tar -czf "$TEMP_BACKUP" -C "$DATA_DIR" prometheus
        sudo chown $(whoami):$(whoami) "$TEMP_BACKUP"
        
        # Remove current data to avoid conflicts
        echo "Removing current Prometheus data"
        sudo rm -rf "$DATA_DIR/prometheus"
    fi
    
    # Create data dir if it doesn't exist
    mkdir -p "$DATA_DIR/prometheus"
    
    # Restore the backup
    echo "Extracting backup file..."
    sudo tar -xzf "$BACKUP_FILE" -C "$DATA_DIR" --strip-components=2
    # sudo chown -R nobody:nobody "$DATA_DIR"  # Set Prometheus permissions
    
    echo "Starting Prometheus container..."
    docker-compose up -d prometheus
    
    echo "Prometheus data restore completed."
}

# Main execution
case "$1" in
    list)
        list_backups
        ;;
    grafana)
        restore_grafana "$2"
        ;;
    prometheus-config)
        restore_prometheus_config "$2"
        ;;
    prometheus-data)
        restore_prometheus_data "$2"
        ;;
    *)
        echo "Usage: $0 {list|grafana|prometheus-config|prometheus-data} [backup_file]"
        echo ""
        echo "Commands:"
        echo "  list                      List all available backups"
        echo "  grafana [backup_file]     Restore Grafana from specified backup"
        echo "  prometheus-config [file]  Restore Prometheus configuration from backup"
        echo "  prometheus-data [file]    Restore Prometheus data from backup"
        echo ""
        echo "Examples:"
        echo "  $0 list"
        echo "  $0 grafana ./backups/grafana_2025-05-30.tar.gz"
        ;;
esac