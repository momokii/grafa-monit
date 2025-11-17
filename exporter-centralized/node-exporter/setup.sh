#!/bin/bash

# Setup Node Exporter for VM monitoring
# Usage: ./setup-node-exporter.sh <VM_NAME> <ENVIRONMENT>

VM_NAME=${1:-"unknown-vm"}
ENVIRONMENT=${2:-"production"}

echo "Setting up Node Exporter for: $VM_NAME ($ENVIRONMENT)"

# Create docker-compose file
cat > compose.yaml << EOF
version: "3.7"

services:
  node-exporter:
    image: prom/node-exporter:v1.6.1
    container_name: node-exporter
    restart: unless-stopped
    ports:
      - "9100:9100"
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    labels:
      - "vm.name=$VM_NAME"
      - "vm.environment=$ENVIRONMENT"
    networks:
      - monitoring

networks:
  monitoring:
    driver: bridge
EOF

# Start node-exporter
docker compose -f  up -d

echo "Node Exporter started for $VM_NAME"
echo "Metrics available at: http://$(hostname -I | awk '{print $1}'):9100/metrics"