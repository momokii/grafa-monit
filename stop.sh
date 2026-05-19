#!/bin/bash
# filepath: stop.sh

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Function to detect OS and set compose directory
detect_os_and_set_compose_dir() {
    # Simplified since we now use a single compose.yaml file
    if [ -f "compose.yaml" ]; then
        COMPOSE_DIR="."
        print_info "Using unified compose.yaml configuration"
    else
        print_error "compose.yaml not found!"
        exit 1
    fi
}

# Function to stop services gracefully
stop_services() {
    print_info "Stopping monitoring services gracefully..."
    
    cd "$COMPOSE_DIR"
    
    # Stop services in reverse dependency order (core services first, then optional)
    local services=("grafana" "blackbox_exporter" "alertmanager" "prometheus" "cadvisor" "node-exporter")

    # Check if optional services (loki/alloy) are running and add them
    # Must use --profile logs to detect profile-gated services
    for svc in alloy loki; do
        if docker compose --profile logs ps -q "$svc" &>/dev/null && [ -n "$(docker compose --profile logs ps -q "$svc")" ]; then
            services+=("$svc")
        fi
    done

    for service in "${services[@]}"; do
        local profile_flag=""
        if [ "$service" = "loki" ] || [ "$service" = "alloy" ]; then
            profile_flag="--profile logs"
        fi
        if docker compose $profile_flag ps -q "$service" &>/dev/null && [ -n "$(docker compose $profile_flag ps -q "$service")" ]; then
            print_info "Stopping $service..."
            docker compose $profile_flag stop "$service"
        else
            print_warning "$service is not running"
        fi
    done
    
    cd ..
    print_success "All services stopped"
}

# Function to remove containers
remove_containers() {
    print_info "Removing containers..."
    
    cd "$COMPOSE_DIR"
    
    if docker compose down; then
        print_success "All containers removed"
    else
        print_error "Failed to remove some containers"
    fi
    
    cd ..
}

# Function to remove volumes
remove_volumes() {
    print_info "Removing Docker volumes..."
    
    cd "$COMPOSE_DIR"
    
    if docker compose down -v; then
        print_success "All volumes removed"
    else
        print_warning "Some volumes might not have been removed"
    fi
    
    cd ..
}

# Function to remove networks
remove_networks() {
    print_info "Removing custom networks..."

    # Remove monitoring network if it exists and no containers are using it
    if docker network ls --format "{{.Name}}" | grep -q "^monitoring-network$"; then
        if docker network rm monitoring-network 2>/dev/null; then
            print_success "monitoring-network removed"
        else
            print_warning "monitoring-network is still in use or couldn't be removed"
        fi
    else
        print_info "monitoring-network doesn't exist"
    fi
}

# Function to remove images
remove_images() {
    print_info "Removing Docker images..."
    
    local images=(
        "prom/node-exporter:v1.6.1"
        "zcube/cadvisor:v0.45.0"
        "prom/prometheus:v2.47.0"
        "grafana/grafana:12.1.1"
        "prom/alertmanager:v0.28.1"
        "grafana/loki:3.3.2"
        "grafana/alloy:v1.9.1"
        "prom/blackbox-exporter:v0.27.0"
    )
    
    for image in "${images[@]}"; do
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^$image$"; then
            print_info "Removing image: $image"
            if docker rmi "$image" 2>/dev/null; then
                print_success "Removed: $image"
            else
                print_warning "Could not remove: $image (might be in use)"
            fi
        else
            print_info "Image not found: $image"
        fi
    done
}

# Function to clean up data directories
cleanup_data() {
    print_warning "This will remove all monitoring data!"
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Cleaning up data directories..."
        
        local data_dirs=("data/prometheus" "data/grafana" "data/loki")
        
        for dir in "${data_dirs[@]}"; do
            if [ -d "$dir" ]; then
                print_info "Removing: $dir"
                rm -rf "$dir"
            fi
        done
        
        print_success "Data directories cleaned"
    else
        print_info "Data cleanup cancelled"
    fi
}

# Function to show current status
show_status() {
    print_info "Current container status:"
    echo
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(node-exporter|cadvisor|prometheus|grafana|alertmanager|loki|alloy|blackbox_exporter|NAMES)"
    echo
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Stop the Grafana Host Monitoring Stack."
    echo "Automatically detects and stops all running services including"
    echo "optional Loki + Alloy if they were started with --with-logs."
    echo
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  -s, --stop           Stop services only (keep containers)"
    echo "  -d, --down           Stop and remove containers (default)"
    echo "  -v, --volumes        Also remove Docker volumes (deletes stored data)"
    echo "  -n, --networks       Also remove custom Docker networks"
    echo "  -i, --images         Also remove Docker images"
    echo "  -c, --cleanup        Also remove data directories (data/, logs/)"
    echo "  --all                Remove everything (containers, volumes, networks, images, data)"
    echo "  --status             Show current service status only"
    echo
    echo "Examples:"
    echo "  $0                   # Stop and remove containers (data preserved)"
    echo "  $0 -s                # Stop services but keep containers"
    echo "  $0 --all             # Complete cleanup (removes everything)"
    echo "  $0 -v                # Stop, remove containers and volumes"
    echo "  $0 --status          # Show what's currently running"
}

# Main function
main() {
    local stop_only=false
    local remove_vols=false
    local remove_nets=false
    local remove_imgs=false
    local cleanup_dirs=false
    local show_status_only=false
    local remove_all=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -s|--stop)
                stop_only=true
                shift
                ;;
            -d|--down)
                # This is the default behavior
                shift
                ;;
            -v|--volumes)
                remove_vols=true
                shift
                ;;
            -n|--networks)
                remove_nets=true
                shift
                ;;
            -i|--images)
                remove_imgs=true
                shift
                ;;
            -c|--cleanup)
                cleanup_dirs=true
                shift
                ;;
            --all)
                remove_all=true
                remove_vols=true
                remove_nets=true
                remove_imgs=true
                cleanup_dirs=true
                shift
                ;;
            --status)
                show_status_only=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Show status only if requested
    if [ "$show_status_only" = true ]; then
        show_status
        exit 0
    fi
    
    print_info "Starting monitoring stack shutdown..."
    
    # Detect OS and set compose directory
    detect_os_and_set_compose_dir
    print_info "Using compose configuration: ./compose.yaml"
    
    # Show current status
    show_status
    
    # Stop services
    if [ "$stop_only" = true ]; then
        stop_services
    else
        # Remove containers (this also stops them)
        if [ "$remove_vols" = true ]; then
            remove_volumes
        else
            remove_containers
        fi
        
        # Remove networks if requested
        if [ "$remove_nets" = true ]; then
            remove_networks
        fi
        
        # Remove images if requested
        if [ "$remove_imgs" = true ]; then
            remove_images
        fi
        
        # Cleanup data directories if requested
        if [ "$cleanup_dirs" = true ]; then
            cleanup_data
        fi
    fi
    
    # Show final status
    echo
    show_status
    
    if [ "$remove_all" = true ]; then
        print_success "Complete monitoring stack cleanup completed!"
    elif [ "$stop_only" = true ]; then
        print_success "Monitoring services stopped successfully!"
        print_info "To start again, run: ./setup.sh"
    else
        print_success "Monitoring stack stopped and containers removed!"
        print_info "To start again, run: ./setup.sh"
    fi
}

# Check if running as script (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi