#!/bin/bash

# ============================================================================
# BORGMATIC MIGRATION SETUP SCRIPT
# ============================================================================
# This script automates the migration from custom bash scripts to borgmatic

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/etc/borgmatic"
SCRIPTS_DIR="/usr/local/bin"
LOG_DIR="/var/log"

# Configuration files
CONFIG_DB="$SCRIPT_DIR/config-databases.yaml"
CONFIG_FILES="$SCRIPT_DIR/config-files.yaml"
ENV_FILE="$SCRIPT_DIR/.env"
DISCOVER_SCRIPT="$SCRIPT_DIR/scripts/discover-htdocs.sh"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
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

check_command() {
    if command -v "$1" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# ============================================================================
# PREREQUISITE CHECKS
# ============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then 
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    print_success "Running as root ✓"
    
    # Check for Borg
    if check_command borg; then
        BORG_VERSION=$(borg --version)
        print_success "Borg is installed: $BORG_VERSION ✓"
    else
        print_error "Borg is not installed!"
        echo "Please install Borg first:"
        echo "  sudo apt update"
        echo "  sudo apt install borgbackup"
        echo ""
        echo "Or visit: https://borgbackup.readthedocs.io/en/stable/installation.html"
        exit 1
    fi
    
    # Check for pipx
    if ! check_command pipx; then
        print_warning "pipx not found, installing..."
        apt update
        apt install -y pipx
        print_success "pipx installed ✓"
    else
        print_success "pipx is installed ✓"
    fi
    
    # Check for jq (needed for some operations)
    if ! check_command jq; then
        print_warning "jq not found, installing..."
        apt install -y jq
        print_success "jq installed ✓"
    else
        print_success "jq is installed ✓"
    fi
}

# ============================================================================
# INSTALL BORGMATIC
# ============================================================================

install_borgmatic() {
    print_header "Installing borgmatic"
    
    if check_command borgmatic; then
        BORGMATIC_VERSION=$(borgmatic --version)
        print_warning "borgmatic is already installed: $BORGMATIC_VERSION"
        read -p "Do you want to reinstall? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi
    
    print_step "Installing borgmatic via pipx..."
    pipx install borgmatic
    
    if check_command borgmatic; then
        print_success "borgmatic installed successfully ✓"
        borgmatic --version
    else
        print_error "Failed to install borgmatic"
        exit 1
    fi
    
    # Install Apprise for notifications
    print_step "Installing Apprise for notifications..."
    if ! check_command apprise; then
        pip install apprise
        print_success "Apprise installed ✓"
    else
        print_success "Apprise already installed ✓"
    fi
}

# ============================================================================
# SETUP CONFIGURATION
# ============================================================================

setup_configuration() {
    print_header "Setting up Configuration"
    
    # Create config directory
    if [ ! -d "$CONFIG_DIR" ]; then
        mkdir -p "$CONFIG_DIR"
        print_success "Created config directory: $CONFIG_DIR ✓"
    fi
    
    # Check for .env file
    if [ ! -f "$ENV_FILE" ]; then
        print_warning ".env file not found!"
        if [ -f "$SCRIPT_DIR/example.env" ]; then
            print_step "Copying example.env to .env..."
            cp "$SCRIPT_DIR/example.env" "$ENV_FILE"
            print_warning "Please edit $ENV_FILE with your actual values before continuing"
            print_warning "Press Enter when you've configured the file..."
            read -r
        else
            print_error "example.env not found in $SCRIPT_DIR"
            exit 1
        fi
    fi
    
    # Source the .env file
    print_step "Loading environment variables from .env..."
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    print_success "Environment variables loaded ✓"
    
    # Validate required variables
    print_step "Validating configuration..."
    REQUIRED_VARS=(
        "BORG_REMOTE_USER"
        "BORG_REMOTE_HOST"
        "BORG_PASSPHRASE"
        "DB_USER"
        "DB_PASS"
    )
    
    MISSING_VARS=()
    for var in "${REQUIRED_VARS[@]}"; do
        if [ -z "${!var:-}" ]; then
            MISSING_VARS+=("$var")
        fi
    done
    
    if [ ${#MISSING_VARS[@]} -gt 0 ]; then
        print_error "Missing required variables: ${MISSING_VARS[*]}"
        print_error "Please configure them in $ENV_FILE"
        exit 1
    fi
    
    print_success "All required variables are set ✓"
    
    # Copy configuration files
    print_step "Copying borgmatic configuration files..."
    
    # Copy database config
    cp "$CONFIG_DB" "$CONFIG_DIR/config-databases.yaml"
    print_success "Copied config-databases.yaml ✓"
    
    # Copy files config
    cp "$CONFIG_FILES" "$CONFIG_DIR/config-files.yaml"
    print_success "Copied config-files.yaml ✓"
    
    # Set proper permissions
    chmod 600 "$CONFIG_DIR"/config-*.yaml
    print_success "Set proper permissions (600) on config files ✓"
    
    # Validate configurations
    print_step "Validating borgmatic configurations..."
    
    # Validate database config
    if BORG_PASSPHRASE="$BORG_PASSPHRASE" borgmatic config validate --config "$CONFIG_DIR/config-databases.yaml"; then
        print_success "Database configuration is valid ✓"
    else
        print_error "Database configuration validation failed"
        exit 1
    fi
    
    # Validate files config
    if BORG_PASSPHRASE="$BORG_PASSPHRASE" borgmatic config validate --config "$CONFIG_DIR/config-files.yaml"; then
        print_success "Files configuration is valid ✓"
    else
        print_error "Files configuration validation failed"
        exit 1
    fi
}

# ============================================================================
# INSTALL SCRIPTS
# ============================================================================

install_scripts() {
    print_header "Installing Support Scripts"
    
    # Ensure scripts directory exists
    mkdir -p "$SCRIPTS_DIR"
    
    # Copy discovery script
    print_step "Installing htdocs discovery script..."
    cp "$DISCOVER_SCRIPT" "$SCRIPTS_DIR/discover-htdocs.sh"
    chmod +x "$SCRIPTS_DIR/discover-htdocs.sh"
    print_success "Installed discover-htdocs.sh ✓"
    
    # Test discovery script
    print_step "Testing htdocs discovery..."
    if "$SCRIPTS_DIR/discover-htdocs.sh"; then
        print_success "Discovery script works correctly ✓"
    else
        print_warning "Discovery script failed (may be expected if no CloudPanel users exist yet)"
    fi
}

# ============================================================================
# CREATE REPOSITORIES
# ============================================================================

create_repositories() {
    print_header "Creating Borg Repositories"
    
    print_warning "This will create new Borg repositories on the remote server."
    print_warning "If repositories already exist, they will be reused."
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Skipping repository creation"
        return 0
    fi
    
    # Create database repository
    print_step "Creating database repository..."
    if BORG_PASSPHRASE="$BORG_PASSPHRASE" borgmatic repo-create --config "$CONFIG_DIR/config-databases.yaml" --encryption repokey; then
        print_success "Database repository created (or already exists) ✓"
    else
        print_warning "Database repository creation failed (may already exist)"
    fi
    
    # Create files repository
    print_step "Creating files repository..."
    if BORG_PASSPHRASE="$BORG_PASSPHRASE" borgmatic repo-create --config "$CONFIG_DIR/config-files.yaml" --encryption repokey; then
        print_success "Files repository created (or already exists) ✓"
    else
        print_warning "Files repository creation failed (may already exist)"
    fi
}

# ============================================================================
# SETUP SYSTEMD TIMERS
# ============================================================================

setup_systemd_timers() {
    print_header "Setting up Systemd Timers"
    
    # Database backup service
    print_step "Creating database backup service..."
    cat > /etc/systemd/system/borgmatic-databases.service << 'EOF'
[Unit]
Description=Borgmatic Database Backup
After=network.target

[Service]
Type=oneshot
Nice=19
IOSchedulingClass=idle
IOSchedulingPriority=7
Environment="TZ={{ env 'TIMEZONE' | default('UTC') }}"
ExecStart=/usr/local/bin/borgmatic create --config /etc/borgmatic/config-databases.yaml --verbosity 1 --stats
ExecStartPost=/usr/local/bin/borgmatic check --config /etc/borgmatic/config-databases.yaml

[Install]
WantedBy=multi-user.target
EOF
    print_success "Created borgmatic-databases.service ✓"
    
    # Database backup timer
    print_step "Creating database backup timer..."
    cat > /etc/systemd/system/borgmatic-databases.timer << 'EOF'
[Unit]
Description=Hourly Database Backup
Requires=borgmatic-databases.service

[Timer]
OnCalendar=hourly
Persistent=true

[Install]
WantedBy=timers.target
EOF
    print_success "Created borgmatic-databases.timer ✓"
    
    # Files backup service
    print_step "Creating files backup service..."
    cat > /etc/systemd/system/borgmatic-files.service << 'EOF'
[Unit]
Description=Borgmatic Files Backup
After=network.target

[Service]
Type=oneshot
Nice=19
IOSchedulingClass=idle
IOSchedulingPriority=7
Environment="TZ={{ env 'TIMEZONE' | default('UTC') }}"
ExecStart=/usr/local/bin/borgmatic create --config /etc/borgmatic/config-files.yaml --verbosity 1 --stats
ExecStartPost=/usr/local/bin/borgmatic check --config /etc/borgmatic/config-files.yaml

[Install]
WantedBy=multi-user.target
EOF
    print_success "Created borgmatic-files.service ✓"
    
    # Files backup timer
    print_step "Creating files backup timer..."
    cat > /etc/systemd/system/borgmatic-files.timer << 'EOF'
[Unit]
Description=Every 6 Hours Files Backup
Requires=borgmatic-files.service

[Timer]
OnCalendar=*:0/6:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
    print_success "Created borgmatic-files.timer ✓"
    
    # Reload systemd
    print_step "Reloading systemd daemon..."
    systemctl daemon-reload
    print_success "Systemd reloaded ✓"
    
    # Enable timers
    print_step "Enabling timers..."
    systemctl enable borgmatic-databases.timer
    systemctl enable borgmatic-files.timer
    print_success "Timers enabled ✓"
    
    # Start timers
    print_step "Starting timers..."
    systemctl start borgmatic-databases.timer
    systemctl start borgmatic-files.timer
    print_success "Timers started ✓"
    
    # Show timer status
    echo ""
    echo "=== Timer Status ==="
    systemctl list-timers borgmatic-*
}

# ============================================================================
# RUN TEST BACKUPS
# ============================================================================

run_test_backups() {
    print_header "Running Test Backups"
    
    print_warning "This will run a test backup to verify everything works."
    read -p "Run test backups? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Skipping test backups"
        return 0
    fi
    
    # Test database backup
    print_step "Running test database backup..."
    if BORG_PASSPHRASE="$BORG_PASSPHRASE" borgmatic create --config "$CONFIG_DIR/config-databases.yaml" --verbosity 1 --stats; then
        print_success "Database backup test passed ✓"
    else
        print_error "Database backup test failed!"
        exit 1
    fi
    
    # Test files backup
    print_step "Running test files backup..."
    if BORG_PASSPHRASE="$BORG_PASSPHRASE" borgmatic create --config "$CONFIG_DIR/config-files.yaml" --verbosity 1 --stats; then
        print_success "Files backup test passed ✓"
    else
        print_error "Files backup test failed!"
        exit 1
    fi
}

# ============================================================================
# SUMMARY
# ============================================================================

print_summary() {
    print_header "Setup Complete!"
    
    echo "✓ borgmatic installed and configured"
    echo "✓ Repositories created"
    echo "✓ Systemd timers configured"
    echo ""
    echo "=== Configuration Files ==="
    echo "Database config: $CONFIG_DIR/config-databases.yaml"
    echo "Files config:    $CONFIG_DIR/config-files.yaml"
    echo "Environment:     $ENV_FILE"
    echo ""
    echo "=== Scripts ==="
    echo "Discovery script: $SCRIPTS_DIR/discover-htdocs.sh"
    echo ""
    echo "=== Schedules ==="
    echo "Database backups: Every hour"
    echo "Files backups:     Every 6 hours"
    echo ""
    echo "=== Useful Commands ==="
    echo "View timer status:     systemctl list-timers borgmatic-*"
    echo "View logs:            journalctl -u borgmatic-* -f"
    echo "Manual database backup:  sudo borgmatic create --config $CONFIG_DIR/config-databases.yaml --verbosity 1"
    echo "Manual files backup:     sudo borgmatic create --config $CONFIG_DIR/config-files.yaml --verbosity 1"
    echo "List archives:          sudo borgmatic list --config $CONFIG_DIR/config-databases.yaml"
    echo ""
    echo "=== Next Steps ==="
    echo "1. Verify backups are running: systemctl list-timers borgmatic-*"
    echo "2. Check logs for any errors: journalctl -u borgmatic-databases -n 50"
    echo "3. Test restore: sudo borgmatic extract --config $CONFIG_DIR/config-databases.yaml --list"
    echo "4. (Optional) Disable old backup scripts after verifying new system works"
    echo ""
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    print_header "Borgmatic Migration Setup"
    echo "This script will migrate your backup system to borgmatic"
    echo ""
    
    check_prerequisites
    install_borgmatic
    setup_configuration
    install_scripts
    create_repositories
    setup_systemd_timers
    run_test_backups
    print_summary
}

main "$@"