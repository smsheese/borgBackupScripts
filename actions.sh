#!/bin/bash

# --- Color Codes ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

SCRIPT_DIR=$(dirname "$(realpath "$0")")
DOWNLOAD_DIR="$SCRIPT_DIR/download"
mkdir -p "$DOWNLOAD_DIR"

# Load .env
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo -e "${RED}.env file not found in $SCRIPT_DIR. Exiting.${RESET}"
    exit 1
fi

# Helper: List backups in a repo
list_backups() {
    local repo="$1"
    borg list "$repo" 2>/dev/null | awk '{print $1}'
}

# Helper: Select a backup interactively
select_backup() {
    local repo="$1"
    local prompt="$2"
    local backups=( $(list_backups "$repo") )
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${YELLOW}No backups found.${RESET}"
        return 1
    fi
    echo -e "${CYAN}$prompt${RESET}"
    select backup in "${backups[@]}"; do
        [ -n "$backup" ] && { echo "$backup"; return 0; } || echo "Invalid selection";
    done
}

# Helper: Download a full backup
download_backup() {
    local repo="$1"
    local backup="$2"
    local dest="$3"
    mkdir -p "$dest"
    borg extract "$repo::$backup" --destination "$dest"
}

# Helper: Download a specific file/folder from a backup
extract_from_backup() {
    local repo="$1"
    local backup="$2"
    local path_in_backup="$3"
    local dest="$4"
    mkdir -p "$dest"
    borg extract "$repo::$backup" "$path_in_backup" --destination "$dest"
}

# --- Main Menu ---
while true; do
    echo -e "${CYAN}${BOLD}Select an action:${RESET}"
    echo -e "${CYAN}1)${RESET} Run database backup now"
    echo -e "${CYAN}2)${RESET} Run files backup now"
    echo -e "${CYAN}3)${RESET} Show list of database backups"
    echo -e "${CYAN}4)${RESET} Show list of files backups"
    echo -e "${CYAN}5)${RESET} Download database backup into folder"
    echo -e "${CYAN}6)${RESET} Download files backup into folder"
    echo -e "${CYAN}7)${RESET} Download a specific database (.sql) from backup"
    echo -e "${CYAN}8)${RESET} Download a specific file/folder from files backup"
    echo -e "${CYAN}9)${RESET} Exit"
    read -p "Enter your choice [1-9]: " CHOICE
    case $CHOICE in
        1)
            bash "$SCRIPT_DIR/database_backup.sh"
            ;;
        2)
            bash "$SCRIPT_DIR/files_backup.sh"
            ;;
        3)
            echo -e "${CYAN}Database backups:${RESET}"
            list_backups "$BORG_REMOTE_USER@$BORG_REMOTE_HOST:$BORG_REMOTE_PATH_DB"
            ;;
        4)
            echo -e "${CYAN}Files backups:${RESET}"
            list_backups "$BORG_REMOTE_USER@$BORG_REMOTE_HOST:$BORG_REMOTE_PATH_FILES"
            ;;
        5)
            repo="$BORG_REMOTE_USER@$BORG_REMOTE_HOST:$BORG_REMOTE_PATH_DB"
            backup=$(select_backup "$repo" "Select a database backup to download:") || continue
            dest="$DOWNLOAD_DIR/$backup"
            download_backup "$repo" "$backup" "$dest"
            echo -e "${GREEN}Downloaded database backup to $dest${RESET}"
            ;;
        6)
            repo="$BORG_REMOTE_USER@$BORG_REMOTE_HOST:$BORG_REMOTE_PATH_FILES"
            backup=$(select_backup "$repo" "Select a files backup to download:") || continue
            dest="$DOWNLOAD_DIR/$backup"
            download_backup "$repo" "$backup" "$dest"
            echo -e "${GREEN}Downloaded files backup to $dest${RESET}"
            ;;
        7)
            repo="$BORG_REMOTE_USER@$BORG_REMOTE_HOST:$BORG_REMOTE_PATH_DB"
            backup=$(select_backup "$repo" "Select a database backup:") || continue
            # List .sql files in backup
            echo -e "${CYAN}Fetching .sql files in backup...${RESET}"
            borg mount "$repo::$backup" /tmp/borgmnt 2>/dev/null
            mapfile -t sqls < <(find /tmp/borgmnt -name '*.sql' -type f)
            if [ ${#sqls[@]} -eq 0 ]; then
                echo -e "${YELLOW}No .sql files found in backup.${RESET}"
                fusermount -u /tmp/borgmnt
                continue
            fi
            select sqlfile in "${sqls[@]}"; do
                [ -n "$sqlfile" ] && break || echo "Invalid selection";
            done
            outname=$(basename "$sqlfile")
            dest="$DOWNLOAD_DIR/${backup}_$outname"
            cp "$sqlfile" "$dest"
            fusermount -u /tmp/borgmnt
            echo -e "${GREEN}Downloaded $outname from $backup to $dest${RESET}"
            ;;
        8)
            repo="$BORG_REMOTE_USER@$BORG_REMOTE_HOST:$BORG_REMOTE_PATH_FILES"
            backup=$(select_backup "$repo" "Select a files backup:") || continue
            borg mount "$repo::$backup" /tmp/borgmnt 2>/dev/null
            echo -e "${CYAN}Browse files in /tmp/borgmnt and enter the relative path to download:${RESET}"
            read -p "Enter path to file/folder to download: " relpath
            dest="$DOWNLOAD_DIR/${backup}_$(basename "$relpath")"
            cp -r "/tmp/borgmnt/$relpath" "$dest"
            fusermount -u /tmp/borgmnt
            echo -e "${GREEN}Downloaded $relpath from $backup to $dest${RESET}"
            ;;
        9)
            echo -e "${BOLD}Exiting.${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice.${RESET}"
            ;;
    esac
    echo -e "\n${CYAN}Press Enter to continue...${RESET}"
    read
    clear
    done
