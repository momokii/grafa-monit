#!/bin/bash

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# Global flags
WITH_LOGS=false

# Function to detect OS and set compose directory
detect_os_and_set_compose_dir() {
    if [ -f "compose.yaml" ]; then
        COMPOSE_DIR="."
        COMPOSE_FILE="compose.yaml"
        print_info "Using unified compose.yaml configuration"
    else
        print_error "compose.yaml not found!"
        exit 1
    fi
}

# Function to check Docker status
check_docker() {
    print_step "Checking Docker status..."

    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi

    print_success "Docker is running"
}

# Function to backup current configuration
backup_config() {
    print_step "Creating configuration backup..."

    local backup_dir="backup/$(date +%Y%m%d_%H%M%S)"

    if [ "$1" = "--backup" ]; then
        mkdir -p "$backup_dir"

        # Backup configuration files
        if [ -f "prometheus.yaml" ]; then
            cp "prometheus.yaml" "$backup_dir/"
            print_info "Backed up prometheus.yaml"
        fi

        if [ -f "loki/loki-config.yaml" ]; then
            cp "loki/loki-config.yaml" "$backup_dir/"
            print_info "Backed up loki-config.yaml"
        fi

        if [ -f "alloy/alloy-config.alloy" ]; then
            cp "alloy/alloy-config.alloy" "$backup_dir/"
            print_info "Backed up alloy-config.alloy"
        fi

        if [ -f "compose.yaml" ]; then
            cp "compose.yaml" "$backup_dir/"
            print_info "Backed up compose.yaml"
        fi

        print_success "Configuration backup created at: $backup_dir"
    else
        print_info "Skipping configuration backup (use --backup to enable)"
    fi
}

# Function to show current versions
show_current_versions() {
    print_step "Current service versions:"
    echo

    # Detect which services are running (including optional ones)
    local services=("prometheus" "grafana" "alertmanager" "node-exporter" "cadvisor" "blackbox_exporter")
    for svc in loki alloy; do
        if docker compose --profile logs -f "$COMPOSE_FILE" ps -q "$svc" 2>/dev/null | grep -q .; then
            services+=("$svc")
        fi
    done

    for service in "${services[@]}"; do
        local profile_flag=""
        if [ "$service" = "loki" ] || [ "$service" = "alloy" ]; then
            profile_flag="--profile logs"
        fi
        local container_id=$(docker compose $profile_flag -f "$COMPOSE_FILE" ps -q "$service" 2>/dev/null)
        if [ -n "$container_id" ]; then
            local image=$(docker inspect --format='{{.Config.Image}}' "$container_id" 2>/dev/null)
            if [ -n "$image" ]; then
                printf "  %-20s: %s\n" "$service" "$image"
            else
                printf "  %-20s: %s\n" "$service" "Not running"
            fi
        else
            printf "  %-20s: %s\n" "$service" "Not running"
        fi
    done
    echo
}

# Function to pull latest images
pull_latest_images() {
    print_step "Pulling latest Docker images..."

    local compose_cmd="docker compose -f $COMPOSE_FILE"
    if [ "$WITH_LOGS" = true ]; then
        compose_cmd="$compose_cmd --profile logs"
    fi

    if $compose_cmd pull; then
        print_success "All images pulled successfully"
    else
        print_error "Failed to pull some images"
        exit 1
    fi
}

# Function to show updated versions
show_updated_versions() {
    print_step "Available image versions:"
    echo

    local images=(
        "prom/node-exporter:v1.6.1"
        "zcube/cadvisor:v0.45.0"
        "prom/prometheus:v2.47.0"
        "grafana/grafana:12.1.1"
        "prom/alertmanager:v0.28.1"
        "prom/blackbox-exporter:v0.27.0"
    )

    if [ "$WITH_LOGS" = true ]; then
        images+=(
            "grafana/loki:3.3.2"
            "grafana/alloy:v1.9.1"
        )
    fi

    for image in "${images[@]}"; do
        local service_name=$(echo "$image" | cut -d'/' -f2 | cut -d':' -f1)
        printf "  %-20s: %s\n" "$service_name" "$image"
    done
    echo
}

# Function to update services
update_services() {
    print_step "Updating monitoring services..."

    local services=("node-exporter" "cadvisor" "prometheus" "alertmanager" "blackbox_exporter" "grafana")
    if [ "$WITH_LOGS" = true ]; then
        services+=("loki" "alloy")
    fi

    local update_mode="$1"

    if [ "$update_mode" = "--rolling" ]; then
        print_info "Performing rolling update (one service at a time)..."

        for service in "${services[@]}"; do
            print_info "Updating $service..."

            local compose_cmd="docker compose -f $COMPOSE_FILE"
            if [ "$WITH_LOGS" = true ]; then
                compose_cmd="$compose_cmd --profile logs"
            fi

            if $compose_cmd up -d --no-deps "$service"; then
                print_success "$service updated successfully"
                sleep 3  # Brief pause between updates
            else
                print_error "Failed to update $service"
                return 1
            fi
        done
    else
        print_info "Performing batch update (all services at once)..."

        local compose_cmd="docker compose -f $COMPOSE_FILE"
        if [ "$WITH_LOGS" = true ]; then
            compose_cmd="$compose_cmd --profile logs"
        fi

        if $compose_cmd up -d; then
            print_success "All services updated successfully"
        else
            print_error "Failed to update services"
            return 1
        fi
    fi
}

# Function to wait for services to be healthy
wait_for_services() {
    print_step "Waiting for services to be ready..."

    local max_wait=120
    local wait_time=0
    local services=("prometheus" "grafana" "alertmanager" "node-exporter" "cadvisor" "blackbox_exporter")
    if [ "$WITH_LOGS" = true ]; then
        services+=("loki" "alloy")
    fi

    while [ $wait_time -lt $max_wait ]; do
        local all_ready=true

        for service in "${services[@]}"; do
            local profile_flag=""
            if [ "$service" = "loki" ] || [ "$service" = "alloy" ]; then
                profile_flag="--profile logs"
            fi
            if ! docker compose $profile_flag -f "$COMPOSE_FILE" ps "$service" 2>/dev/null | grep -q "running"; then
                all_ready=false
                break
            fi
        done

        if [ "$all_ready" = true ]; then
            print_success "All services are ready!"
            return 0
        fi

        sleep 5
        wait_time=$((wait_time + 5))
        print_info "Waiting... ($wait_time/${max_wait}s)"
    done

    print_warning "Some services might not be fully ready yet"
}

# Function to verify services health
verify_services() {
    print_step "Verifying service health..."

    local failed_services=()

    # Check Prometheus
    if curl -s http://localhost:9090/-/ready >/dev/null 2>&1; then
        print_success "Prometheus is healthy"
    else
        print_warning "Prometheus health check failed"
        failed_services+=("prometheus")
    fi

    # Check Grafana
    if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
        print_success "Grafana is healthy"
    else
        print_warning "Grafana health check failed"
        failed_services+=("grafana")
    fi

    # Check Alertmanager
    if curl -s http://localhost:9093/-/ready >/dev/null 2>&1; then
        print_success "Alertmanager is healthy"
    else
        print_warning "Alertmanager health check failed"
        failed_services+=("alertmanager")
    fi

    # Check Blackbox Exporter
    if curl -s http://localhost:9115/-/healthy >/dev/null 2>&1; then
        print_success "Blackbox Exporter is healthy"
    else
        print_warning "Blackbox Exporter health check failed"
        failed_services+=("blackbox_exporter")
    fi

    # Check optional services (only when logs profile is active)
    if [ "$WITH_LOGS" = true ]; then
        # Check Loki
        if curl -s http://localhost:3100/ready >/dev/null 2>&1; then
            print_success "Loki is healthy"
        else
            print_warning "Loki health check failed"
            failed_services+=("loki")
        fi

        # Check Alloy
        if curl -s http://localhost:12345/-/ready >/dev/null 2>&1; then
            print_success "Alloy is healthy"
        else
            print_warning "Alloy health check failed"
            failed_services+=("alloy")
        fi
    fi

    if [ ${#failed_services[@]} -gt 0 ]; then
        print_warning "Some services failed health checks: ${failed_services[*]}"
        print_info "You may want to check their logs: docker compose logs <service_name>"
    else
        print_success "All services passed health checks!"
    fi
}

# Function to show service status
show_status() {
    print_info "Current service status:"
    echo
    local compose_cmd="docker compose -f $COMPOSE_FILE"
    # Also show profile-gated services if they might be running
    docker compose -f "$COMPOSE_FILE" ps 2>/dev/null
    docker compose --profile logs -f "$COMPOSE_FILE" ps loki alloy 2>/dev/null | grep -v "^NAME\|^$" || true
    echo
}

# Function to show logs
show_recent_logs() {
    print_step "Recent service logs:"
    echo

    local services=("prometheus" "grafana" "alertmanager")
    if [ "$WITH_LOGS" = true ]; then
        services+=("loki" "alloy")
    fi

    for service in "${services[@]}"; do
        echo "=== $service logs ==="
        local profile_flag=""
        if [ "$service" = "loki" ] || [ "$service" = "alloy" ]; then
            profile_flag="--profile logs"
        fi
        docker compose $profile_flag -f "$COMPOSE_FILE" logs --tail=5 "$service" 2>/dev/null || echo "No logs available"
        echo
    done
}

# Function to clean up old images
cleanup_old_images() {
    print_step "Cleaning up old Docker images..."

    if [ "$1" = "--cleanup" ]; then
        # Remove dangling images
        local dangling=$(docker images -f "dangling=true" -q)
        if [ -n "$dangling" ]; then
            docker rmi $dangling >/dev/null 2>&1
            print_success "Removed dangling images"
        else
            print_info "No dangling images to remove"
        fi

        # Remove unused images
        docker image prune -f >/dev/null 2>&1
        print_success "Docker image cleanup completed"
    else
        print_info "Skipping image cleanup (use --cleanup to enable)"
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Update the Grafana Host Monitoring Stack."
    echo "By default updates core services only. Use --with-logs to also"
    echo "update optional Loki + Alloy log aggregation services."
    echo
    echo "Update Modes:"
    echo
    echo "  Default (no flags):"
    echo "    Updates the 6 core services:"
    echo "    - node-exporter, cadvisor, prometheus, grafana,"
    echo "      alertmanager, blackbox_exporter"
    echo
    echo "  --with-logs:"
    echo "    Updates all 8 services (core + loki + alloy)"
    echo "    Use this if you initially set up with ./setup.sh --with-logs"
    echo
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  --with-logs          Include Loki + Alloy in the update"
    echo "  -s, --status         Show current service status only"
    echo "  -v, --versions       Show current and available image versions"
    echo "  -p, --pull           Pull latest images only (no restart)"
    echo "  -r, --rolling        Rolling update (one service at a time, 3s pause)"
    echo "  -f, --force          Skip confirmation prompt"
    echo "  --backup             Create config backup before updating"
    echo "  --cleanup            Remove old Docker images after update"
    echo "  --verify             Run health checks after update"
    echo "  --logs               Show recent service logs after update"
    echo
    echo "Examples:"
    echo "  $0                   # Update core services"
    echo "  $0 --with-logs       # Update all services including Loki + Alloy"
    echo "  $0 -r                # Rolling update (safer, one at a time)"
    echo "  $0 --backup --verify # Update with backup + health check"
    echo "  $0 --status          # See what's running right now"
    echo "  $0 -p                # Just pull images, don't restart"
}

# Main function
main() {
    local show_status_only=false
    local show_versions_only=false
    local pull_only=false
    local rolling_update=false
    local force_update=false
    local create_backup=false
    local cleanup_images=false
    local verify_health=false
    local show_logs=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --with-logs)
                WITH_LOGS=true
                shift
                ;;
            -s|--status)
                show_status_only=true
                shift
                ;;
            -v|--versions)
                show_versions_only=true
                shift
                ;;
            -p|--pull)
                pull_only=true
                shift
                ;;
            -r|--rolling)
                rolling_update=true
                shift
                ;;
            -f|--force)
                force_update=true
                shift
                ;;
            --backup)
                create_backup=true
                shift
                ;;
            --cleanup)
                cleanup_images=true
                shift
                ;;
            --verify)
                verify_health=true
                shift
                ;;
            --logs)
                show_logs=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    print_info "Starting monitoring stack update process..."

    # Detect OS and set compose directory
    detect_os_and_set_compose_dir

    # Check Docker status
    check_docker

    # Show status only if requested
    if [ "$show_status_only" = true ]; then
        show_status
        exit 0
    fi

    # Show versions only if requested
    if [ "$show_versions_only" = true ]; then
        show_current_versions
        show_updated_versions
        exit 0
    fi

    # Show current versions
    show_current_versions

    # Create backup if requested
    if [ "$create_backup" = true ]; then
        backup_config --backup
    fi

    # Pull latest images
    if [ "$pull_only" = true ]; then
        pull_latest_images
        print_success "Image pull completed!"
        exit 0
    fi

    # Confirm update unless forced
    if [ "$force_update" = false ]; then
        echo
        read -p "Do you want to proceed with the update? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Update cancelled"
            exit 0
        fi
    fi

    # Pull latest images
    pull_latest_images

    # Update services
    if [ "$rolling_update" = true ]; then
        update_services --rolling
    else
        update_services
    fi

    # Wait for services to be ready
    wait_for_services

    # Verify services health if requested
    if [ "$verify_health" = true ]; then
        verify_services
    fi

    # Show recent logs if requested
    if [ "$show_logs" = true ]; then
        show_recent_logs
    fi

    # Clean up old images if requested
    if [ "$cleanup_images" = true ]; then
        cleanup_old_images --cleanup
    fi

    # Show final status
    show_status

    print_success "Monitoring stack update completed successfully!"
    print_info "All services should be running with the latest versions"

    echo
    print_info "Service access URLs:"
    echo "  - Grafana:       http://localhost:3000"
    echo "  - Prometheus:    http://localhost:9090"
    echo "  - Alertmanager:  http://localhost:9093"
    echo "  - Blackbox:      http://localhost:9115"
    if [ "$WITH_LOGS" = true ]; then
        echo "  - Loki:          http://localhost:3100"
        echo "  - Alloy:         http://localhost:12345"
    fi
}

# Check if running as script (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
