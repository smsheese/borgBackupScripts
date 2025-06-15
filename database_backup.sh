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

# Define Borg environment variables
BORG_REPO_DB="$BORG_REMOTE_USER@$BORG_REMOTE_HOST:$BORG_REMOTE_PATH_DB"
export BORG_RSH="ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT"
export BORG_PASSPHRASE="$BORG_PASSPHRASE"

# Ensure the backup directory exists
mkdir -p $BACKUP_DIR/databases

# Prepare log file
LOG_DIR="$SCRIPT_DIR/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/db_backup_${TIMESTAMP}.log"

# Track overall status
BACKUP_STATUS=0

# Dump all databases, excluding system databases
for DB in $($DB_TYPE -u $DB_USER -p$DB_PASS -h "$DB_HOST" -P "$DB_PORT" -e "SHOW DATABASES;" | grep -v -E "$DB_EXCLUDE"); do
    echo "Dumping database: $DB" | tee -a "$LOG_FILE"
    if ! $DB_DUMP -u $DB_USER -p$DB_PASS -h "$DB_HOST" -P "$DB_PORT" "$DB" > "$BACKUP_DIR/databases/$DB.sql" 2>>"$LOG_FILE"; then
        BACKUP_STATUS=1
        break
    fi
    echo "Dumped $DB to $BACKUP_DIR/databases/$DB.sql" | tee -a "$LOG_FILE"
done

# Run Borg backup for databases
if [ $BACKUP_STATUS -eq 0 ]; then
    echo "Starting Borg backup for databases..." | tee -a "$LOG_FILE"
    if ! borg create --compression "$BORG_COMPRESSION" --stats "$BORG_REPO_DB::databases-$TIMESTAMP" "$BACKUP_DIR/databases" 2>&1 | tee -a "$LOG_FILE"; then
        BACKUP_STATUS=1
    fi
fi

# Prune old database backups
if [ $BACKUP_STATUS -eq 0 ]; then
    echo "Pruning old database backups..." | tee -a "$LOG_FILE"
    if ! borg prune -v --list "$BORG_REPO_DB" -a 'databases-*' $BORG_KEEP_DB 2>&1 | tee -a "$LOG_FILE"; then
        BACKUP_STATUS=1
    fi
fi

# Cleanup local database dumps
if [ $BACKUP_STATUS -eq 0 ]; then
    echo "Cleaning up local database dumps..." | tee -a "$LOG_FILE"
    rm -rf "$BACKUP_DIR/databases"
fi

# Notify based on status, send log
if [ $BACKUP_STATUS -eq 0 ]; then
    echo "Database backup completed successfully!" | tee -a "$LOG_FILE"
    "$SCRIPT_DIR/notifications.sh" success "$LOG_FILE"
else
    echo "Database backup failed!" | tee -a "$LOG_FILE"
    "$SCRIPT_DIR/notifications.sh" error "$LOG_FILE"
fi

# Log rotation: keep only LOGS_KEEP_COUNT most recent logs (if not -1)
if [ -n "$LOGS_KEEP_COUNT" ] && [ "$LOGS_KEEP_COUNT" -ne -1 ]; then
    find "$LOG_DIR" -type f -name 'db_backup_*.log' | sort | head -n -$LOGS_KEEP_COUNT | xargs -r rm --
fi
