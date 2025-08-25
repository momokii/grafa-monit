#!/bin/bash
# filepath: setup.sh

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

# Function to detect OS and set compose directory
detect_os_and_set_compose_dir() {
    case "$(uname -s)" in
        Linux*)
            OS="linux"
            if [ -d "compose-linux" ] && [ -f "compose-linux/compose.yaml" ]; then
                COMPOSE_DIR="compose-linux"
            else
                print_error "Linux compose directory 'compose-linux' or 'compose-linux/compose.yaml' not found!"
                exit 1
            fi
            ;;
        MINGW*|CYGWIN*|MSYS*)
            OS="windows"
            if [ -d "compose-windows" ] && [ -f "compose-windows/compose.yaml" ]; then
                COMPOSE_DIR="compose-windows"
            else
                print_error "Windows compose directory 'compose-windows' or 'compose-windows/compose.yaml' not found!"
                exit 1
            fi
            ;;
        *)
            print_error "Unsupported operating system: $(uname -s)"
            exit 1
            ;;
    esac
}

# Function to check if Docker is running
check_docker() {
    print_step "Checking Docker installation and status..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    if ! command -v docker compose &> /dev/null && ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    print_success "Docker and Docker Compose are available"
}

# Function to create required directories
create_directories() {
    print_step "Creating required directories..."
    
    local directories=(
        "data/prometheus"
        "data/grafana" 
        "data/loki"
        "logs/grafana"
        "logs/alertmanager"
        "logs/nginx"
        "logs/api"
        "logs/app"
        "backups"
        "loki"
        "promtail"
        "grafana/provisioning/datasources"
        "grafana/provisioning/dashboards"
        "grafana/provisioning/notifiers"
    )
    
    for dir in "${directories[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_info "Created directory: $dir"
        else
            print_info "Directory already exists: $dir"
        fi
    done
    
    print_success "All required directories created"
}

# Function to set proper permissions
set_permissions() {
    print_step "Setting proper permissions..."
    
    # Set permissions for data directories (avoiding permission issues)
    if [ "$OS" = "linux" ]; then
        # Prometheus data directory
        if [ -d "data/prometheus" ]; then
            sudo chown -R 65534:65534 data/prometheus 2>/dev/null || {
                print_warning "Could not set prometheus permissions, you may need to run: sudo chown -R 65534:65534 data/prometheus"
            }
        fi
        
        # Grafana data directory  
        if [ -d "data/grafana" ]; then
            sudo chown -R 472:472 data/grafana 2>/dev/null || {
                print_warning "Could not set grafana permissions, you may need to run: sudo chown -R 472:472 data/grafana"
            }
        fi
        
        # Loki data directory
        if [ -d "data/loki" ]; then
            sudo chown -R 10001:10001 data/loki 2>/dev/null || {
                print_warning "Could not set loki permissions, you may need to run: sudo chown -R 10001:10001 data/loki"
            }
        fi
        
        # Log directories
        chmod -R 755 logs/ 2>/dev/null || print_warning "Could not set log directory permissions"
    fi
    
    print_success "Permissions set successfully"
}

# Function to check configuration files
check_config_files() {
    print_step "Checking configuration files..."
    
    local config_files=(
        "prometheus.yaml:Prometheus configuration"
        "alerts.yml:Alertmanager rules"
        "alertmanager.yml:Alertmanager configuration"
        "loki/loki-config.yaml:Loki configuration"
        "promtail/promtail-config.yaml:Promtail configuration"
        "grafana/provisioning/datasources/datasource.yml:Grafana datasource configuration"
    )
    
    local missing_files=()
    
    for config in "${config_files[@]}"; do
        IFS=':' read -r file description <<< "$config"
        if [ ! -f "$file" ]; then
            missing_files+=("$file ($description)")
        else
            print_info "Found: $file"
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        print_warning "Missing configuration files:"
        for file in "${missing_files[@]}"; do
            echo "  - $file"
        done
        print_warning "Please ensure all configuration files are present before starting services"
    else
        print_success "All configuration files found"
    fi
}

# Function to validate configuration files
validate_configs() {
    print_step "Validating configuration files..."
    
    # Validate prometheus.yaml if promtool is available
    if command -v promtool &> /dev/null && [ -f "prometheus.yaml" ]; then
        print_info "Validating Prometheus configuration..."
        if promtool check config prometheus.yaml; then
            print_success "Prometheus configuration is valid"
        else
            print_error "Prometheus configuration validation failed!"
            exit 1
        fi
    else
        print_warning "promtool not found, skipping Prometheus config validation"
    fi
    
    # Check if Loki config file exists and is readable
    if [ -f "loki/loki-config.yaml" ]; then
        print_info "Loki configuration file found"
    else
        print_warning "Loki configuration file not found: loki/loki-config.yaml"
    fi
    
    # Check if Promtail config file exists and is readable
    if [ -f "promtail/promtail-config.yaml" ]; then
        print_info "Promtail configuration file found"
    else
        print_warning "Promtail configuration file not found: promtail/promtail-config.yaml"
    fi
}

# Function to create external networks
create_networks() {
    print_step "Creating Docker networks..."
    
    # Create monitoring network if it doesn't exist
    if ! docker network ls --format "{{.Name}}" | grep -q "^monitoring-network$"; then
        print_info "Creating monitoring-network..."
        if docker network create monitoring-network; then
            print_success "monitoring-network created successfully"
        else
            print_error "Failed to create monitoring-network"
            exit 1
        fi
    else
        print_info "monitoring-network already exists"
    fi
}

# Function to pull Docker images
pull_images() {
    print_step "Pulling latest Docker images..."
    
    cd "$COMPOSE_DIR"
    
    if docker compose pull; then
        print_success "All images pulled successfully"
    else
        print_error "Failed to pull some images"
        cd ..
        exit 1
    fi
    
    cd ..
}

# Function to start services
start_services() {
    print_step "Starting monitoring services..."
    
    cd "$COMPOSE_DIR"
    
    # Start services with dependency order
    print_info "Starting core monitoring services..."
    if docker compose up -d prometheus alertmanager; then
        print_success "Core monitoring services started"
    else
        print_error "Failed to start core monitoring services"
        cd ..
        exit 1
    fi
    
    sleep 5
    
    print_info "Starting log aggregation services..."
    if docker compose up -d loki promtail; then
        print_success "Log aggregation services started"
    else
        print_error "Failed to start log aggregation services"
        cd ..
        exit 1
    fi
    
    sleep 5
    
    print_info "Starting visualization and metric collection services..."
    if docker compose up -d grafana node-exporter cadvisor; then
        print_success "All monitoring services started"
    else
        print_error "Failed to start some services"
        cd ..
        exit 1
    fi
    
    cd ..
}

# Function to wait for services to be ready
wait_for_services() {
    print_step "Waiting for services to be ready..."
    
    local services=(
        "prometheus:9090:/-/healthy"
        "grafana:3000:/api/health"
        "alertmanager:9093:/-/healthy"
        "node-exporter:9100:/metrics"
        "cadvisor:8080:/healthz"
        "loki:3100:/ready"
        "promtail:9080:/metrics"
    )
    
    local max_wait=180 # 3 minutes
    local wait_time=0
    
    for service_info in "${services[@]}"; do
        IFS=':' read -r service port endpoint <<< "$service_info"
        
        print_info "Waiting for $service to be ready..."
        
        while [ $wait_time -lt $max_wait ]; do
            if curl -f -s "http://localhost:$port$endpoint" &>/dev/null; then
                print_success "$service is ready"
                break
            fi
            
            sleep 5
            wait_time=$((wait_time + 5))
            
            if [ $wait_time -ge $max_wait ]; then
                print_warning "$service is taking longer than expected to be ready"
                break
            fi
        done
        
        wait_time=0
    done
}

# Function to show service status
show_status() {
    print_step "Checking service status..."
    echo
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(prometheus|grafana|alertmanager|cadvisor|node-exporter|loki|promtail|NAMES)"
    echo
}

# Function to show access information
show_access_info() {
    print_step "Service Access Information"
    echo
    print_info "Core Services:"
    print_info "  📊 Grafana:       http://localhost:3000 (admin/admin)"
    print_info "  🔍 Prometheus:    http://localhost:9090"
    print_info "  🚨 Alertmanager:  http://localhost:9093"
    echo
    print_info "Monitoring Services:"
    print_info "  📈 Node Exporter: http://localhost:9100/metrics"
    print_info "  🐳 cAdvisor:      http://localhost:8080"
    echo
    print_info "Log Services:"
    print_info "  📝 Loki:          http://localhost:3100"
    print_info "  📋 Promtail:      http://localhost:9080/metrics"
    echo
    print_info "Optional Services (commented in compose):"
    print_info "  🐘 PostgreSQL Exporter: http://localhost:9187/metrics (if enabled)"
    print_info "  🌐 Nginx Exporter:      http://localhost:9113/metrics (if enabled)"
    echo
    print_success "Setup completed successfully!"
    print_info "You can now start monitoring your infrastructure."
    echo
    print_warning "Note: If you need PostgreSQL or Nginx monitoring, uncomment the relevant services in $COMPOSE_DIR/compose.yaml"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help           Show this help message"
    echo "  --skip-pull          Skip pulling latest Docker images"
    echo "  --skip-validation    Skip configuration validation"
    echo "  --skip-permissions   Skip setting directory permissions"
    echo "  --quick              Quick setup (skip pull, validation, and wait)"
    echo
    echo "Examples:"
    echo "  $0                   # Full setup with all checks"
    echo "  $0 --quick           # Quick setup for development"
    echo "  $0 --skip-pull       # Setup without pulling latest images"
}

# Main function
main() {
    local skip_pull=false
    local skip_validation=false
    local skip_permissions=false
    local quick_setup=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --skip-pull)
                skip_pull=true
                shift
                ;;
            --skip-validation)
                skip_validation=true
                shift
                ;;
            --skip-permissions)
                skip_permissions=true
                shift
                ;;
            --quick)
                quick_setup=true
                skip_pull=true
                skip_validation=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}    Grafana Host Monitoring Setup Script${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo
    
    # Detect OS and set compose directory
    detect_os_and_set_compose_dir
    print_info "Operating System: $OS"
    print_info "Using compose configuration: ./$COMPOSE_DIR/"
    echo
    
    # Check Docker
    check_docker
    
    # Create directories
    create_directories
    
    # Set permissions
    if [ "$skip_permissions" = false ]; then
        set_permissions
    fi
    
    # Check configuration files
    check_config_files
    
    # Validate configurations
    if [ "$skip_validation" = false ]; then
        validate_configs
    fi
    
    # Create networks
    create_networks
    
    # Pull images
    if [ "$skip_pull" = false ]; then
        pull_images
    fi
    
    # Start services
    start_services
    
    # Wait for services (skip in quick mode)
    if [ "$quick_setup" = false ]; then
        wait_for_services
    fi
    
    # Show status
    show_status
    
    # Show access information
    show_access_info
}

# Check if running as script (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi