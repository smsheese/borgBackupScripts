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

# Dump all databases, excluding system databases
for DB in $($DB_TYPE -u $DB_USER -p$DB_PASS -h "$DB_HOST" -P "$DB_PORT" -e "SHOW DATABASES;" | grep -v -E "$DB_EXCLUDE"); do
    echo "Dumping database: $DB"
    $DB_DUMP -u $DB_USER -p$DB_PASS -h "$DB_HOST" -P "$DB_PORT" "$DB" > "$BACKUP_DIR/databases/$DB.sql"
done

# Run Borg backup for databases
echo "Starting Borg backup for databases..."
borg create --compression "$BORG_COMPRESSION" --stats "$BORG_REPO_DB::databases-$TIMESTAMP" "$BACKUP_DIR/databases"

# Prune old database backups
echo "Pruning old database backups..."
borg prune -v --list "$BORG_REPO_DB" -a 'databases-*' $BORG_KEEP_DB

# Cleanup local database dumps
echo "Cleaning up local database dumps..."
rm -rf "$BACKUP_DIR/databases"

echo "Database backup completed successfully!"