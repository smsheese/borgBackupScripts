#!/bin/bash

# --- Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# --- Utility Functions ---
show_checks() {
    echo -e "\n${BOLD}===== SETUP CHECKS =====${RESET}"
    # Borg installed?
    if command -v borg &> /dev/null; then
        echo -e "${GREEN}[OK]${RESET} BorgBackup is installed: ${BLUE}$(borg --version)${RESET}"
    else
        echo -e "${RED}[FAIL]${RESET} BorgBackup is NOT installed."
    fi
    # System architecture
    ARCH=$(uname -m)
    echo -e "${BLUE}[INFO]${RESET} System architecture: ${CYAN}$ARCH${RESET}"
    # Distro
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo -e "${BLUE}[INFO]${RESET} Distro: ${CYAN}$NAME ($ID)${RESET}"
    else
        echo -e "${YELLOW}[WARN]${RESET} Could not detect Linux distribution."
    fi
    # Active user
    echo -e "${BLUE}[INFO]${RESET} Active user: ${CYAN}$(whoami)${RESET}"
    # .env exists?
    if [ -f "$SCRIPT_DIR/.env" ]; then
        echo -e "${GREEN}[OK]${RESET} .env file exists at $SCRIPT_DIR/.env"
        echo -e "${BLUE}[INFO]${RESET} .env realpath: ${CYAN}$(realpath "$SCRIPT_DIR/.env")${RESET}"
        echo -e "${BLUE}[INFO]${RESET} .env permissions: ${CYAN}$(stat -c '%A %U:%G' "$SCRIPT_DIR/.env")${RESET}"
        # Show DB type in .env
        DB_TYPE_VAL=$(grep '^DB_TYPE=' "$SCRIPT_DIR/.env" | head -n1 | cut -d'=' -f2 | tr -d '"')
        if [ -n "$DB_TYPE_VAL" ]; then
            echo -e "${BLUE}[INFO]${RESET} DB_TYPE in .env: ${CYAN}$DB_TYPE_VAL${RESET}"
        else
            echo -e "${YELLOW}[WARN]${RESET} DB_TYPE not set in .env"
        fi
        # Show FILES_BACKUP_TYPE in .env
        FILES_BACKUP_TYPE_VAL=$(grep '^FILES_BACKUP_TYPE=' "$SCRIPT_DIR/.env" | head -n1 | cut -d'=' -f2 | tr -d '"')
        if [ -n "$FILES_BACKUP_TYPE_VAL" ]; then
            echo -e "${BLUE}[INFO]${RESET} FILES_BACKUP_TYPE in .env: ${CYAN}$FILES_BACKUP_TYPE_VAL${RESET}"
        else
            echo -e "${YELLOW}[WARN]${RESET} FILES_BACKUP_TYPE not set in .env"
        fi
    else
        echo -e "${RED}[FAIL]${RESET} .env file does NOT exist at $SCRIPT_DIR/.env"
    fi
    # Backup directory check
    if [ -n "$BACKUP_DIR" ]; then
        if [ -d "$BACKUP_DIR" ]; then
            echo -e "${GREEN}[OK]${RESET} Backup directory exists: ${CYAN}$BACKUP_DIR${RESET}"
            echo -e "${BLUE}[INFO]${RESET} Backup dir owner/permissions: ${CYAN}$(stat -c '%A %U:%G' "$BACKUP_DIR")${RESET}"
        else
            echo -e "${YELLOW}[WARN]${RESET} Backup directory does not exist: $BACKUP_DIR"
        fi
    else
        echo -e "${YELLOW}[WARN]${RESET} BACKUP_DIR not set in .env"
    fi
    echo -e "${BOLD}========================${RESET}\n"
}

fix_env_permissions() {
    if [ -f "$SCRIPT_DIR/.env" ]; then
        chmod 600 "$SCRIPT_DIR/.env"
        echo ".env permissions set to 600."
    else
        echo ".env file not found."
    fi
}

change_db_type() {
    echo "Select the database type:"
    echo "1. MySQL (my)"
    echo "2. MariaDB (ma)"
    read -p "Enter your choice (my/ma): " DB_SELECTION
    if [ "$DB_SELECTION" == "my" ]; then
        DB_TYPE="mysql"
        DB_DUMP="mysqldump"
        echo "MySQL selected for database backup."
    elif [ "$DB_SELECTION" == "ma" ]; then
        DB_TYPE="mariadb"
        DB_DUMP="mariadb-dump"
        echo "MariaDB selected for database backup."
    else
        echo "Invalid selection."
        return
    fi
    sed -i "s/^DB_TYPE=.*$/DB_TYPE=\"$DB_TYPE\"/" "$SCRIPT_DIR/.env"
    sed -i "s/^DB_DUMP=.*$/DB_DUMP=\"$DB_DUMP\"/" "$SCRIPT_DIR/.env"
    echo ".env file updated: DB_TYPE=\"$DB_TYPE\", DB_DUMP=\"$DB_DUMP\""
}

generate_ssh_key() {
    # SSH_PRIVATE_KEY is optional for this task, prompt if not set
    if [ -z "$SSH_PRIVATE_KEY" ]; then
        read -p "Enter path for SSH private key (e.g. /root/.ssh/borgBackup): " SSH_PRIVATE_KEY
    fi
    echo "Generating SSH key pair for backup user..."
    ssh-keygen -t ed25519 -f "$SSH_PRIVATE_KEY" -C "borgBackupKey" -q -N ""
    chmod 600 "$SSH_PRIVATE_KEY"
    chmod 644 "$SSH_PRIVATE_KEY.pub"
    echo "SSH keypair created with restrictive permissions at $SSH_PRIVATE_KEY."
}

copy_ssh_key() {
    if [ -z "$SSH_PRIVATE_KEY" ] || [ -z "$SSH_PORT" ] || [ -z "$BORG_REMOTE_USER" ] || [ -z "$BORG_REMOTE_HOST" ]; then
        echo "Required SSH or remote variables not set in .env."
        return
    fi
    echo "Copying the public key to the remote server..."
    ssh-copy-id -i "$SSH_PRIVATE_KEY" -p "$SSH_PORT" "$BORG_REMOTE_USER@$BORG_REMOTE_HOST"
}

init_borg_repos() {
    if [ -z "$BORG_REMOTE_USER" ] || [ -z "$BORG_REMOTE_HOST" ] || [ -z "$BORG_REMOTE_PATH_DB" ] || [ -z "$BORG_REMOTE_PATH_FILES" ]; then
        echo "Required Borg variables not set in .env."
        return
    fi
    echo "Initializing Borg repositories on the remote server..."
    ssh -i "$SSH_PRIVATE_KEY" -p "$SSH_PORT" "$BORG_REMOTE_USER@$BORG_REMOTE_HOST" "mkdir -p $BORG_REMOTE_PATH_DB $BORG_REMOTE_PATH_FILES"
    export BORG_RSH="ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT"
    export BORG_PASSPHRASE="$BORG_PASSPHRASE"
    borg init --encryption=repokey "ssh://$BORG_REMOTE_USER@$BORG_REMOTE_HOST/$BORG_REMOTE_PATH_DB"
    borg init --encryption=repokey "ssh://$BORG_REMOTE_USER@$BORG_REMOTE_HOST/$BORG_REMOTE_PATH_FILES"
    echo "Borg repositories initialized."
}

set_backup_dir_permissions() {
    if [ -z "$BACKUP_DIR" ]; then
        echo "BACKUP_DIR not set in .env."
        return
    fi
    chmod 700 "$BACKUP_DIR"
    echo "Backup directory permissions set to 700."
}

install_borg() {
    if command -v borg &> /dev/null; then
        echo "BorgBackup is already installed: $(borg --version)"
        return
    fi
    echo "Attempting to detect your Linux distribution and install BorgBackup..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID=${ID,,}
        if [[ $DISTRO_ID == "ubuntu" || $DISTRO_ID == "debian" ]]; then
            echo "Detected Debian/Ubuntu. Installing with apt..."
            sudo apt update && sudo apt install borgbackup -y
        elif [[ $DISTRO_ID == "fedora" || $DISTRO_ID == "centos" || $DISTRO_ID == "rhel" ]]; then
            echo "Detected Fedora/CentOS/RHEL. Installing with dnf..."
            sudo dnf install borgbackup -y
        elif [[ $DISTRO_ID == "arch" || $DISTRO_ID == "manjaro" ]]; then
            echo "Detected Arch/Manjaro. Installing with pacman..."
            sudo pacman -Sy --noconfirm borg
        else
            echo "[WARN] Unsupported or unknown distro: $DISTRO_ID. Please install BorgBackup manually."
            return
        fi
    else
        echo "[WARN] Could not detect Linux distribution. Please install BorgBackup manually."
        return
    fi
    if command -v borg &> /dev/null; then
        echo "[OK] BorgBackup installed successfully: $(borg --version)"
    else
        echo "[FAIL] BorgBackup installation failed. Please install manually."
    fi
}

select_files_backup_type() {
    echo "Select files backup type:"
    echo "1. Specified directories (SOURCE_DIRS in .env)"
    echo "2. All user htdocs directories (/home/*/htdocs)"
    read -p "Enter your choice (1/2): " FILES_TYPE
    if [ "$FILES_TYPE" == "1" ]; then
        sed -i "s/^FILES_BACKUP_TYPE=.*/FILES_BACKUP_TYPE=\"specified\"/" "$SCRIPT_DIR/.env" 2>/dev/null || echo 'FILES_BACKUP_TYPE="specified"' >> "$SCRIPT_DIR/.env"
        echo "FILES_BACKUP_TYPE set to 'specified' in .env."
    elif [ "$FILES_TYPE" == "2" ]; then
        sed -i "s/^FILES_BACKUP_TYPE=.*/FILES_BACKUP_TYPE=\"userdirs\"/" "$SCRIPT_DIR/.env" 2>/dev/null || echo 'FILES_BACKUP_TYPE="userdirs"' >> "$SCRIPT_DIR/.env"
        echo "FILES_BACKUP_TYPE set to 'userdirs' in .env."
    else
        echo "Invalid selection."
    fi
}

create_cron_job_db() {
    DB_BACKUP_SCRIPT="$SCRIPT_DIR/database_backup.sh"
    LOG_DIR="$SCRIPT_DIR/logs"
    mkdir -p "$LOG_DIR"
    DB_CRON="0 * * * * /bin/bash $DB_BACKUP_SCRIPT >> $LOG_DIR/db_backup.log 2>&1"
    echo "Add the following line to your crontab to schedule database backups:"
    echo "$DB_CRON"
    read -p "Add to crontab now? (y/n): " ADD
    if [[ "$ADD" =~ ^[Yy]$ ]]; then
        (crontab -l 2>/dev/null; echo "$DB_CRON") | sort | uniq | crontab -
        echo "Database backup cron job added."
    fi
}

create_cron_job_files() {
    FILES_BACKUP_SCRIPT="$SCRIPT_DIR/files_backup.sh"
    LOG_DIR="$SCRIPT_DIR/logs"
    mkdir -p "$LOG_DIR"
    FILES_CRON="0 * * * * /bin/bash $FILES_BACKUP_SCRIPT >> $LOG_DIR/files_backup.log 2>&1"
    echo "Add the following line to your crontab to schedule files backups:"
    echo "$FILES_CRON"
    read -p "Add to crontab now? (y/n): " ADD
    if [[ "$ADD" =~ ^[Yy]$ ]]; then
        (crontab -l 2>/dev/null; echo "$FILES_CRON") | sort | uniq | crontab -
        echo "Files backup cron job added."
    fi
}

run_all() {
    fix_env_permissions
    change_db_type
    generate_ssh_key
    copy_ssh_key
    init_borg_repos
    set_backup_dir_permissions
    echo "All setup tasks completed."
}

# --- Main Menu Loop ---
SCRIPT_DIR=$(dirname "$(realpath "$0")")
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

while true; do
    show_checks
    echo -e "${CYAN}${BOLD}Select a task to perform:${RESET}"
    echo -e "${CYAN}1)${RESET} Run all setup tasks (complete)"
    echo -e "${CYAN}2)${RESET} Fix .env permissions"
    echo -e "${CYAN}3)${RESET} Change database type in .env"
    echo -e "${CYAN}4)${RESET} Generate SSH key with restrictive permissions"
    echo -e "${CYAN}5)${RESET} Copy SSH public key to remote server"
    echo -e "${CYAN}6)${RESET} Initialize Borg repositories on remote server"
    echo -e "${CYAN}7)${RESET} Set backup directory permissions"
    echo -e "${CYAN}8)${RESET} Install BorgBackup if not installed"
    echo -e "${CYAN}9)${RESET} Select files backup type (specified/userdirs)"
    echo -e "${CYAN}10)${RESET} Create cron job for database backup"
    echo -e "${CYAN}11)${RESET} Create cron job for files backup"
    echo -e "${CYAN}12)${RESET} Exit"
    read -p "Enter your choice [1-12]: " CHOICE
    case $CHOICE in
        1) run_all ;;
        2) fix_env_permissions ;;
        3) change_db_type ;;
        4) generate_ssh_key ;;
        5) copy_ssh_key ;;
        6) init_borg_repos ;;
        7) set_backup_dir_permissions ;;
        8) install_borg ;;
        9) select_files_backup_type ;;
        10) create_cron_job_db ;;
        11) create_cron_job_files ;;
        12) echo -e "${BOLD}Exiting.${RESET}"; exit 0 ;;
        *) echo -e "${RED}Invalid choice.${RESET}" ;;
    esac
    echo -e "\n${CYAN}Press Enter to continue...${RESET}"
    read
    if [ -f "$SCRIPT_DIR/.env" ]; then
        source "$SCRIPT_DIR/.env"
    fi
    clear
    # Loop continues
    done
