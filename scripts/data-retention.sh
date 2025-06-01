#!/bin/bash

# Parameters
PROMETHEUS_DIR="./data/prometheus"
ARCHIVE_DIR="./archives"
RETENTION_DAYS=16  # one more day from Prometheus retention
ARCHIVE_RETENTION_DAYS=90  # hpw long to keep archives

# Create archive directory if it doesn't exist
mkdir -p "$ARCHIVE_DIR"

# Format date for file name
DATE=$(date +"%Y-%m-%d")

# Part 1: Archive old Prometheus data (Prometheus will delete it after retention period)
echo "Checking for data older than $RETENTION_DAYS days to archive"
find "$PROMETHEUS_DIR" -type d -mtime +$RETENTION_DAYS | while read -r dir; do

    echo "Found directory: $dir"  # Debug output to see what directories are found

    # just process directories that contain metrics data (ignore system directories)
    if [[ "$dir" == *"/chunks_head"* || "$dir" == *"/wal"* ]]; then
        dir_name=$(basename "$dir")
        parent_dir=$(basename "$(dirname "$dir")")
        archive_name="$ARCHIVE_DIR/prometheus_${parent_dir}_${dir_name}_$DATE.tar.gz"
        
        echo "Archiving $dir to $archive_name"
        tar -czf "$archive_name" -C "$(dirname "$dir")" "$(basename "$dir")"
        
        # data not deleted because Prometheus will manage it itself
        # this only creates a backup before Prometheus deletes it
    fi
done

# Part 2: Manage archive rotation (delete archives older than ARCHIVE_RETENTION_DAYS)
echo -e "\nChecking for archives older than $ARCHIVE_RETENTION_DAYS days to remove"
find "$ARCHIVE_DIR" -name "prometheus_*.tar.gz" -type f -mtime +$ARCHIVE_RETENTION_DAYS | while read -r archive; do
    echo "Removing old archive: $archive"
    rm -f "$archive"
done

echo "Data archiving completed."