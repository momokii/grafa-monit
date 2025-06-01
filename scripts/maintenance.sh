#!/bin/bash

# Jalankan backup terlebih dahulu (untuk memastikan semua data aman)
echo "Running backup first..."
./backup.sh

# Kemudian jalankan data-retention untuk mengarsipkan data lama
echo -e "\nRunning data retention..."
./data-retention.sh

echo "Maintenance completed successfully"