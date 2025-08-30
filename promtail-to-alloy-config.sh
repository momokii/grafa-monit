#!/bin/bash
# filepath: promtail-to-alloy-config.sh

# Promtail to Alloy Configuration Converter
# This script converts Promtail YAML configuration to Grafana Alloy format using Docker

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
DEFAULT_ALLOY_VERSION="v1.9.1"
DEFAULT_OUTPUT_DIR="alloy"
DEFAULT_OUTPUT_FILE="alloy-config.alloy"

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

print_header() {
    echo -e "${CYAN}================================================${NC}"
    echo -e "${CYAN}    Promtail to Alloy Configuration Converter${NC}"
    echo -e "${CYAN}================================================${NC}"
    echo
}

# Function to show usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "This script converts Promtail YAML configuration to Grafana Alloy format."
    echo
    echo "Options:"
    echo "  -i, --input PATH         Input Promtail config path (relative to current directory)"
    echo "                           Example: promtail/promtail-config.yaml"
    echo "  -o, --output PATH        Output Alloy config path (relative to current directory)"
    echo "                           Default: alloy/alloy-config.alloy"
    echo "  -v, --version VERSION    Grafana Alloy Docker image version"
    echo "                           Default: $DEFAULT_ALLOY_VERSION"
    echo "  -f, --force              Overwrite existing output file without confirmation"
    echo "  -h, --help               Show this help message"
    echo
    echo "Examples:"
    echo "  $0 -i promtail/promtail-config.yaml"
    echo "  $0 -i promtail/promtail-config.yaml -o alloy/custom-config.alloy"
    echo "  $0 -i config/promtail.yaml -v v1.8.0 -f"
    echo
    echo "Interactive Mode:"
    echo "  $0                       # Run in interactive mode with prompts"
    echo
    echo "Prerequisites:"
    echo "  - Docker must be installed and running"
    echo "  - Input Promtail configuration file must exist"
    echo "  - Current user must have Docker execution permissions"
}

# Function to validate Docker installation
check_docker() {
    print_step "Checking Docker installation..."
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        print_info "Please install Docker first: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker is not running or accessible"
        print_info "Please start Docker daemon or check permissions"
        exit 1
    fi
    
    print_success "Docker is available and running"
}

# Function to validate input file
validate_input_file() {
    local input_file="$1"
    
    if [[ ! -f "$input_file" ]]; then
        print_error "Input file does not exist: $input_file"
        return 1
    fi
    
    if [[ ! -r "$input_file" ]]; then
        print_error "Input file is not readable: $input_file"
        return 1
    fi
    
    # Basic YAML validation (check if it's likely a YAML file)
    if ! [[ "$input_file" =~ \.(yaml|yml)$ ]]; then
        print_warning "Input file doesn't have .yaml or .yml extension"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    print_success "Input file validated: $input_file"
    return 0
}

# Function to create output directory
create_output_directory() {
    local output_path="$1"
    local output_dir=$(dirname "$output_path")
    
    if [[ ! -d "$output_dir" ]]; then
        print_step "Creating output directory: $output_dir"
        if mkdir -p "$output_dir"; then
            print_success "Output directory created: $output_dir"
        else
            print_error "Failed to create output directory: $output_dir"
            return 1
        fi
    else
        print_info "Output directory already exists: $output_dir"
    fi
    
    return 0
}

# Function to check if output file exists and handle overwrite
check_output_file() {
    local output_file="$1"
    local force_overwrite="$2"
    
    if [[ -f "$output_file" ]]; then
        if [[ "$force_overwrite" == "true" ]]; then
            print_warning "Output file exists, will be overwritten (force mode): $output_file"
            return 0
        else
            print_warning "Output file already exists: $output_file"
            read -p "Overwrite existing file? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Conversion cancelled by user"
                return 1
            fi
        fi
    fi
    
    return 0
}

# Function to pull Alloy Docker image
pull_alloy_image() {
    local version="$1"
    local image="grafana/alloy:$version"
    
    print_step "Checking Grafana Alloy Docker image: $image"
    
    if ! docker image inspect "$image" &> /dev/null; then
        print_info "Pulling Grafana Alloy image: $image"
        if docker pull "$image"; then
            print_success "Image pulled successfully"
        else
            print_error "Failed to pull Docker image: $image"
            return 1
        fi
    else
        print_info "Docker image already available: $image"
    fi
    
    return 0
}

# Function to perform the conversion
convert_config() {
    local input_file="$1"
    local output_file="$2"
    local version="$3"
    
    local image="grafana/alloy:$version"
    local docker_input="/config/$input_file"
    local docker_output="/config/$output_file"
    
    print_step "Converting Promtail configuration to Alloy format..."
    print_info "Input:  $input_file"
    print_info "Output: $output_file"
    print_info "Using:  $image"
    echo
    
    # Run the Docker conversion command
    local docker_cmd="docker run --rm -v \"${PWD}:/config\" \"$image\" convert --source-format=promtail --output=\"$docker_output\" \"$docker_input\""
    
    print_info "Executing Docker command..."
    if docker run --rm -v "${PWD}:/config" "$image" convert \
        --source-format=promtail \
        --output="$docker_output" \
        "$docker_input"; then
        
        print_success "Configuration converted successfully!"
        print_info "Alloy configuration saved to: $output_file"
        
        # Show file size
        if [[ -f "$output_file" ]]; then
            local file_size=$(du -h "$output_file" | cut -f1)
            print_info "Output file size: $file_size"
        fi
        
        return 0
    else
        print_error "Conversion failed!"
        print_info "Please check your Promtail configuration syntax"
        return 1
    fi
}

# Function to get user input interactively
interactive_mode() {
    print_info "Running in interactive mode..."
    echo
    
    # Get input file
    local input_file=""
    while [[ -z "$input_file" ]]; do
        read -p "Enter Promtail config path (e.g., promtail/promtail-config.yaml): " input_file
        if [[ -z "$input_file" ]]; then
            print_warning "Input path cannot be empty"
        elif ! validate_input_file "$input_file"; then
            input_file=""
        fi
    done
    
    # Get output file
    echo
    read -p "Enter output path (default: $DEFAULT_OUTPUT_DIR/$DEFAULT_OUTPUT_FILE): " output_file
    if [[ -z "$output_file" ]]; then
        output_file="$DEFAULT_OUTPUT_DIR/$DEFAULT_OUTPUT_FILE"
    fi
    
    # Get Alloy version
    echo
    read -p "Enter Alloy version (default: $DEFAULT_ALLOY_VERSION): " version
    if [[ -z "$version" ]]; then
        version="$DEFAULT_ALLOY_VERSION"
    fi
    
    # Confirm settings
    echo
    print_info "Configuration Summary:"
    echo "  Input:   $input_file"
    echo "  Output:  $output_file"
    echo "  Version: $version"
    echo
    read -p "Proceed with conversion? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Conversion cancelled by user"
        exit 0
    fi
    
    # Set global variables for main execution
    INPUT_FILE="$input_file"
    OUTPUT_FILE="$output_file"
    ALLOY_VERSION="$version"
    FORCE_OVERWRITE="false"
}

# Function to show conversion results
show_results() {
    local output_file="$1"
    
    if [[ -f "$output_file" ]]; then
        echo
        print_success "Conversion completed successfully!"
        echo
        print_info "Next steps:"
        print_info "1. Review the generated Alloy configuration:"
        print_info "   cat $output_file"
        echo
        print_info "2. Test the Alloy configuration:"
        print_info "   docker run --rm -v \"\${PWD}:/config\" grafana/alloy:$ALLOY_VERSION validate /config/$output_file"
        echo
        print_info "3. Run Alloy with the new configuration:"
        print_info "   docker run -d --name alloy -v \"\${PWD}:/config\" -p 12345:12345 grafana/alloy:$ALLOY_VERSION run /config/$output_file"
        echo
        print_info "Documentation:"
        print_info "- Alloy Configuration: https://grafana.com/docs/alloy/latest/"
        print_info "- Migration Guide: https://grafana.com/docs/alloy/latest/tasks/migrate/"
    fi
}

# Main function
main() {
    local input_file=""
    local output_file="$DEFAULT_OUTPUT_DIR/$DEFAULT_OUTPUT_FILE"
    local version="$DEFAULT_ALLOY_VERSION"
    local force_overwrite="false"
    local interactive="true"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--input)
                input_file="$2"
                interactive="false"
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -v|--version)
                version="$2"
                shift 2
                ;;
            -f|--force)
                force_overwrite="true"
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_header
    
    # Check Docker availability
    check_docker
    
    # Run interactive mode if no input file specified
    if [[ "$interactive" == "true" ]]; then
        interactive_mode
        input_file="$INPUT_FILE"
        output_file="$OUTPUT_FILE"
        version="$ALLOY_VERSION"
        force_overwrite="$FORCE_OVERWRITE"
    fi
    
    # Validate input file
    if ! validate_input_file "$input_file"; then
        exit 1
    fi
    
    # Create output directory
    if ! create_output_directory "$output_file"; then
        exit 1
    fi
    
    # Check output file
    if ! check_output_file "$output_file" "$force_overwrite"; then
        exit 1
    fi
    
    # Pull Alloy image
    if ! pull_alloy_image "$version"; then
        exit 1
    fi
    
    # Perform conversion
    if convert_config "$input_file" "$output_file" "$version"; then
        show_results "$output_file"
    else
        exit 1
    fi
}

# Check if running as script (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi