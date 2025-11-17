#!/bin/bash

# Setup cAdvisor for container monitoring
# Usage: ./setup.sh <HOST_NAME> <ENVIRONMENT>

HOST_NAME=${1:-"unknown-host"}
ENVIRONMENT=${2:-"production"}

echo "Setting up cAdvisor for: $HOST_NAME ($ENVIRONMENT)"

# Create docker-compose file
cat > compose.yaml << EOF
version: "3.7"

services:
  cadvisor:
    image: zcube/cadvisor:latest
    container_name: cadvisor
    restart: unless-stopped
    ports:
      - "8080:8080"
    command:
      - '--port=8080'
      - '--docker_only=true'
      - '--storage_duration=5m'
      - '--housekeeping_interval=30s'
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:rw
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    devices:
      - /dev/kmsg
    privileged: true
    labels:
      - "host.name=$HOST_NAME"
      - "host.environment=$ENVIRONMENT"
    networks:
      - monitoring
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--spider", "http://localhost:8080/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 10s

networks:
  monitoring:
    driver: bridge
EOF

# Start cAdvisor
docker compose -f compose.yaml up -d

echo "cAdvisor started for $HOST_NAME"
echo "Metrics available at: http://$(hostname -I | awk '{print $1}'):8080/metrics"
echo "Web UI available at: http://$(hostname -I | awk '{print $1}'):8080"