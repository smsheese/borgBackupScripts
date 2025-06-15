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
    # Cron jobs info (inline)
    echo -e "${BOLD}===== CRON JOBS CHECK =====${RESET}"
    local db_pattern files_pattern
    db_pattern="database_backup.sh"
    files_pattern="files_backup.sh"
    local crontab_content
    crontab_content=$(crontab -l 2>/dev/null)
    if echo "$crontab_content" | grep -q "$db_pattern"; then
        echo -e "${GREEN}[OK]${RESET} Database backup cron job exists."
    else
        echo -e "${YELLOW}[INFO]${RESET} No database backup cron job found."
    fi
    if echo "$crontab_content" | grep -q "$files_pattern"; then
        echo -e "${GREEN}[OK]${RESET} Files backup cron job exists."
    else
        echo -e "${YELLOW}[INFO]${RESET} No files backup cron job found."
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
    while true; do
        echo "Enter the database type (mysql or mariadb):"
        read -p "Database type: " DB_SELECTION
        if [ "$DB_SELECTION" == "mysql" ]; then
            DB_TYPE="mysql"
            DB_DUMP="mysqldump"
            echo "MySQL selected for database backup."
            break
        elif [ "$DB_SELECTION" == "mariadb" ]; then
            DB_TYPE="mariadb"
            DB_DUMP="mariadb-dump"
            echo "MariaDB selected for database backup."
            break
        else
            echo -e "${RED}Invalid selection. Please enter 'mysql' or 'mariadb'.${RESET}"
        fi
    done
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

remove_old_cron_jobs() {
    # $1 = pattern (e.g. database_backup.sh or files_backup.sh)
    local pattern="$1"
    crontab -l 2>/dev/null | grep -v "$pattern" | crontab -
}

prompt_cron_schedule() {
    local script_path="$1"
    local log_path="$2"
    local job_type="$3" # 'Database' or 'Files'
    local cron_expr=""
    echo -e "\n${CYAN}How often do you want to run the $job_type backup?${RESET}"
    echo "1) Every n hours (e.g. 1, 3, 6, 12, 48, 120)"
    echo "2) Every n days at a specific time (e.g. every 2 days at 01:00)"
    echo "3) Every day of the week at a specific time (e.g. Mon at 03:30)"
    echo "4) Every day of the month (e.g. 1, 14, 21) at a specific time"
    echo "5) Every quarter (enter date and time, e.g. 01/01 01:00, 04/01 01:00, 07/01 01:00, 10/01 01:00)"
    echo "6) Every year (select month, enter date and time)"
    # Force flush output so user sees options before prompt
    sleep 0.1
    read -p "Select an option [1-6]: " opt
    case $opt in
        1)
            read -p "Enter interval in hours (e.g. 1, 3, 6, 12, 48): " n
            if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le 720 ]; then
                cron_expr="0 */$n * * *"
            else
                echo -e "${RED}Invalid value. Must be a number between 1 and 720.${RESET}"; return 1
            fi
            ;;
        2)
            read -p "Enter interval in days (e.g. 2, 5, 7): " n
            read -p "Enter time (HH:MM, e.g. 01:00): " t
            if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le 31 ] && [[ "$t" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
                min=${t#*:}; hour=${t%:*}
                cron_expr="$min $hour */$n * *"
            else
                echo -e "${RED}Invalid input. Days must be 1-31, time in HH:MM.${RESET}"; return 1
            fi
            ;;
        3)
            echo "Select day of week: 0=Sun, 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat"
            read -p "Enter day (0-6): " dow
            read -p "Enter time (HH:MM, e.g. 03:30): " t
            if [[ "$dow" =~ ^[0-6]$ ]] && [[ "$t" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
                min=${t#*:}; hour=${t%:*}
                cron_expr="$min $hour * * $dow"
            else
                echo -e "${RED}Invalid input. Day must be 0-6, time in HH:MM.${RESET}"; return 1
            fi
            ;;
        4)
            read -p "Enter day of month (1-31): " dom
            read -p "Enter time (HH:MM, e.g. 18:45): " t
            if [[ "$dom" =~ ^([1-9]|[12][0-9]|3[01])$ ]] && [[ "$t" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
                min=${t#*:}; hour=${t%:*}
                cron_expr="$min $hour $dom * *"
            else
                echo -e "${RED}Invalid input. Day must be 1-31, time in HH:MM.${RESET}"; return 1
            fi
            ;;
        5)
            read -p "Enter date for each quarter (MM/DD, e.g. 01/01): " qdate
            read -p "Enter time (HH:MM, e.g. 01:00): " t
            if [[ "$qdate" =~ ^(0[1-9]|1[0-2])/(0[1-9]|[12][0-9]|3[01])$ ]] && [[ "$t" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
                min=${t#*:}; hour=${t%:*}
                # Run on Jan/Apr/Jul/Oct
                cron_expr="$min $hour ${qdate#*/} 1,4,7,10 *"
            else
                echo -e "${RED}Invalid input. Date must be MM/DD, time in HH:MM.${RESET}"; return 1
            fi
            ;;
        6)
            echo "Select month: 1=Jan, 2=Feb, ..., 12=Dec"
            read -p "Enter month (1-12): " mon
            read -p "Enter day of month (1-31): " dom
            read -p "Enter time (HH:MM, e.g. 01:00): " t
            if [[ "$mon" =~ ^([1-9]|1[0-2])$ ]] && [[ "$dom" =~ ^([1-9]|[12][0-9]|3[01])$ ]] && [[ "$t" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
                min=${t#*:}; hour=${t%:*}
                cron_expr="$min $hour $dom $mon *"
            else
                echo -e "${RED}Invalid input. Month 1-12, day 1-31, time in HH:MM.${RESET}"; return 1
            fi
            ;;
        *)
            echo -e "${RED}Invalid option.${RESET}"; return 1
            ;;
    esac
    echo "$cron_expr"
}

create_cron_job_db() {
    DB_BACKUP_SCRIPT="$SCRIPT_DIR/database_backup.sh"
    LOG_DIR="$SCRIPT_DIR/logs"
    mkdir -p "$LOG_DIR"
    remove_old_cron_jobs "database_backup.sh"
    cron_expr=$(prompt_cron_schedule "$DB_BACKUP_SCRIPT" "$LOG_DIR/db_backup.log" "Database") || return
    DB_CRON="$cron_expr /bin/bash $DB_BACKUP_SCRIPT >> $LOG_DIR/db_backup.log 2>&1"
    echo "Add the following line to your crontab to schedule database backups:"
    echo "$DB_CRON"
    read -p "Add to crontab now? (y/n): " ADD
    if [[ "$ADD" =~ ^[Yy]$ ]]; then
        (crontab -l 2>/dev/null; echo "$DB_CRON") | grep -v "database_backup.sh" | sort | uniq | crontab -
        echo "Database backup cron job added."
    fi
}

create_cron_job_files() {
    FILES_BACKUP_SCRIPT="$SCRIPT_DIR/files_backup.sh"
    LOG_DIR="$SCRIPT_DIR/logs"
    mkdir -p "$LOG_DIR"
    remove_old_cron_jobs "files_backup.sh"
    cron_expr=$(prompt_cron_schedule "$FILES_BACKUP_SCRIPT" "$LOG_DIR/files_backup.log" "Files") || return
    FILES_CRON="$cron_expr /bin/bash $FILES_BACKUP_SCRIPT >> $LOG_DIR/files_backup.log 2>&1"
    echo "Add the following line to your crontab to schedule files backups:"
    echo "$FILES_CRON"
    read -p "Add to crontab now? (y/n): " ADD
    if [[ "$ADD" =~ ^[Yy]$ ]]; then
        (crontab -l 2>/dev/null; echo "$FILES_CRON") | grep -v "files_backup.sh" | sort | uniq | crontab -
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

# --- Cron Check & Install Functions ---
cron_status=""
check_cron_installed() {
    if command -v crontab &>/dev/null; then
        cron_status="${GREEN}Available${RESET}"
        return 0
    else
        cron_status="${YELLOW}Not Installed${RESET}"
        return 1
    fi
}

install_cron() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID=${ID,,}
        if [[ $DISTRO_ID == "ubuntu" || $DISTRO_ID == "debian" ]]; then
            echo "Installing cron with apt..."
            sudo apt update && sudo apt install cron -y
            sudo systemctl enable --now cron
        elif [[ $DISTRO_ID == "fedora" || $DISTRO_ID == "centos" || $DISTRO_ID == "rhel" ]]; then
            echo "Installing cronie with dnf..."
            sudo dnf install cronie -y
            sudo systemctl enable --now crond
        elif [[ $DISTRO_ID == "arch" || $DISTRO_ID == "manjaro" ]]; then
            echo "Installing cronie with pacman..."
            sudo pacman -Sy --noconfirm cronie
            sudo systemctl enable --now cronie
        else
            echo "[WARN] Unsupported or unknown distro: $DISTRO_ID. Please install cron manually."
            return 1
        fi
    else
        echo "[WARN] Could not detect Linux distribution. Please install cron manually."
        return 1
    fi
    if command -v crontab &>/dev/null; then
        echo "[OK] Cron installed successfully."
    else
        echo "[FAIL] Cron installation failed. Please install manually."
    fi
}

# --- .env Creation/Copy & Interactive Fill ---
create_or_copy_env() {
    local env_path="$SCRIPT_DIR/.env"
    if [ -f "$env_path" ]; then
        backup_path="$env_path.bak.$(date +%Y%m%d%H%M%S)"
        cp "$env_path" "$backup_path"
        echo "Backed up existing .env to $backup_path."
    fi
    cp "$SCRIPT_DIR/example.env" "$env_path"
    echo ".env copied from example.env."
    echo "Enter values for .env (leave blank to keep current):"
    while IFS= read -r line; do
        if [[ "$line" =~ ^([A-Z0-9_]+)=(.*)$ ]]; then
            var=${BASH_REMATCH[1]}
            curval=$(grep -E "^$var=" "$env_path" | head -n1 | cut -d'=' -f2- | sed 's/^\"//;s/\"$//')
            read -p "$var [$curval]: " val
            val=${val:-$curval}
            sed -i "s|^$var=.*|$var=\"$val\"|" "$env_path"
        fi
    done < <(grep -E '^[A-Z0-9_]+=' "$env_path")
    echo ".env updated."
}

# --- Enhanced Main Menu Loop ---
SCRIPT_DIR=$(dirname "$(realpath "$0")")
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

while true; do
    show_checks
    check_cron_installed
    # Status summaries
    borg_status="$(command -v borg &>/dev/null && echo "${GREEN}OK${RESET}" || echo "${RED}Not Installed${RESET}")"
    env_status="$( [ -f "$SCRIPT_DIR/.env" ] && echo "${GREEN}OK${RESET}" || echo "${RED}Missing${RESET}")"
    cron_summary="$cron_status"
    files_backup_type_val="$(grep '^FILES_BACKUP_TYPE=' "$SCRIPT_DIR/.env" 2>/dev/null | head -n1 | cut -d'=' -f2 | tr -d '"')"
    [ -z "$files_backup_type_val" ] && files_backup_type_val="unset"
    echo -e "${CYAN}${BOLD}Select a task to perform:${RESET}"
    echo -e "${CYAN}1)${RESET} Run all setup tasks (complete)   [Borg: $borg_status | .env: $env_status | Cron: $cron_summary]"
    echo -e "${CYAN}2)${RESET} Fix .env permissions             [.env: $env_status]"
    echo -e "${CYAN}3)${RESET} Change database type in .env      [.env: $env_status]"
    echo -e "${CYAN}4)${RESET} Generate SSH key with restrictive permissions"
    echo -e "${CYAN}5)${RESET} Copy SSH public key to remote server"
    echo -e "${CYAN}6)${RESET} Initialize Borg repositories on remote server"
    echo -e "${CYAN}7)${RESET} Set backup directory permissions"
    echo -e "${CYAN}8)${RESET} Install BorgBackup if not installed   [Borg: $borg_status]"
    echo -e "${CYAN}9)${RESET} Select files backup type (specified/userdirs)   [Current: $files_backup_type_val]"
    echo -e "${CYAN}10)${RESET} Create cron job for database backup $( [ "$cron_status" == "${GREEN}Available${RESET}" ] && echo "" || echo "${YELLOW}(install cron first!)${RESET}")"
    echo -e "${CYAN}11)${RESET} Create cron job for files backup   $( [ "$cron_status" == "${GREEN}Available${RESET}" ] && echo "" || echo "${YELLOW}(install cron first!)${RESET}")"
    echo -e "${CYAN}12)${RESET} Install cron feature (Debian/Fedora/Arch/RHEL)   [Cron: $cron_summary]"
    echo -e "${CYAN}13)${RESET} Exit"
    read -p "Enter your choice [1-13]: " CHOICE
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
        10)
            if check_cron_installed; then
                create_cron_job_db
            else
                echo -e "${YELLOW}Cron is not installed. Please install cron first!${RESET}"
            fi
            ;;
        11)
            if check_cron_installed; then
                create_cron_job_files
            else
                echo -e "${YELLOW}Cron is not installed. Please install cron first!${RESET}"
            fi
            ;;
        12) install_cron ;;
        13) echo -e "${BOLD}Exiting.${RESET}"; exit 0 ;;
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
