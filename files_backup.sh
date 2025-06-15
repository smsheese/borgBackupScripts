#!/bin/bash

# Determine the script's directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Load the .env file from the script's directory
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo ".env file not found in $SCRIPT_DIR. Exiting."
    exit 1
fi

# Ensure that required variables are set
if [ -z "$BORG_REMOTE_USER" ] || [ -z "$BORG_REMOTE_HOST" ] || [ -z "$BORG_REMOTE_PATH_FILES" ] || [ -z "$SSH_PRIVATE_KEY" ] || [ -z "$BORG_PASSPHRASE" ]; then
    echo "Required variables not set in .env. Exiting."
    exit 1
fi

# Define Borg repository for files
BORG_REPO_FILES="$BORG_REMOTE_USER@$BORG_REMOTE_HOST:$BORG_REMOTE_PATH_FILES"
export BORG_RSH="ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT"
export BORG_PASSPHRASE="$BORG_PASSPHRASE"

# Ensure the backup directory exists
mkdir -p $BACKUP_DIR/files

# Prepare log file
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/files_backup_${TIMESTAMP}.log"

# Determine source directories based on FILES_BACKUP_TYPE
SOURCE_DIRS_LIST=()
if [ "$FILES_BACKUP_TYPE" == "userdirs" ]; then
    echo "Discovering user subdirectories (all /home/*/htdocs)..."
    for user_dir in /home/*; do
        htdocs_path="$user_dir/htdocs"
        if [[ -d "$htdocs_path" ]]; then
            SOURCE_DIRS_LIST+=("$htdocs_path")
        fi
    done
    if [[ ${#SOURCE_DIRS_LIST[@]} -eq 0 ]]; then
        echo "No valid htdocs directories found to back up. Exiting."
        exit 1
    fi
else
    # Default to specified directories
    if [ -z "${SOURCE_DIRS[*]}" ]; then
        echo "No SOURCE_DIRS specified in .env. Exiting."
        exit 1
    fi
    for DIR in "${SOURCE_DIRS[@]}"; do
        SOURCE_DIRS_LIST+=("$DIR")
    done
fi

# Exclude directories or files specified in .env
EXCLUDE_ARGS=()
for EXCLUDE in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_ARGS+=(--exclude "$EXCLUDE")
done

# Run Borg backup for discovered directories and log all output
if [ "$FILES_BACKUP_TYPE" == "userdirs" ]; then
    ARCHIVE_NAME="sites-$TIMESTAMP"
else
    ARCHIVE_NAME="files-$TIMESTAMP"
fi

echo "Starting Borg backup for files/folders..." | tee "$LOG_FILE"
borg create --compression "$BORG_COMPRESSION" --stats "${EXCLUDE_ARGS[@]}" "$BORG_REPO_FILES::$ARCHIVE_NAME" "${SOURCE_DIRS_LIST[@]}" 2>&1 | tee -a "$LOG_FILE"
BACKUP_EXIT_CODE=${PIPESTATUS[0]}

if [ $BACKUP_EXIT_CODE -eq 0 ]; then
    echo "File/Folder backup completed successfully!" | tee -a "$LOG_FILE"
    $SCRIPT_DIR/notifications.sh success "Backup completed for files at $TIMESTAMP"
else
    echo "Backup failed!" | tee -a "$LOG_FILE"
    $SCRIPT_DIR/notifications.sh error "Backup failed for files at $TIMESTAMP"
fi

# Prune old backups
if [ "$FILES_BACKUP_TYPE" == "userdirs" ]; then
    PRUNE_PATTERN='sites-*'
else
    PRUNE_PATTERN='files-*'
fi

echo "Pruning old file/folder backups..." | tee -a "$LOG_FILE"
borg prune -v --list "$BORG_REPO_FILES" -a "$PRUNE_PATTERN" $BORG_KEEP_FILES 2>&1 | tee -a "$LOG_FILE"

echo "Cleaning up local files..." | tee -a "$LOG_FILE"
rm -rf $BACKUP_DIR/files

echo "File/Folder backup process completed!" | tee -a "$LOG_FILE"

# Log rotation: keep only LOGS_KEEP_COUNT most recent logs (if not -1)
if [ -n "$LOGS_KEEP_COUNT" ] && [ "$LOGS_KEEP_COUNT" -ne -1 ]; then
    find "$LOG_DIR" -type f -name 'files_backup_*.log' | sort | head -n -$LOGS_KEEP_COUNT | xargs -r rm --
fi
