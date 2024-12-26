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

# Discover user subdirectories dynamically
echo "Discovering user subdirectories..."
SOURCE_DIRS_LIST=""
for user_dir in /home/*; do
    htdocs_path="$user_dir/htdocs"
    if [[ -d "$htdocs_path" ]]; then
        SOURCE_DIRS_LIST+="$htdocs_path "
    fi
done

# Exit if no directories found
if [[ -z "$SOURCE_DIRS_LIST" ]]; then
    echo "No valid htdocs directories found to back up. Exiting."
    exit 1
fi

# Exclude directories or files specified in .env
EXCLUDE_ARGS=""
for EXCLUDE in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_ARGS+="--exclude $EXCLUDE "
done

# Run Borg backup for discovered directories
echo "Starting Borg backup for user subdirectories..."
borg create --compression "$BORG_COMPRESSION" --stats $EXCLUDE_ARGS "$BORG_REPO_FILES::sites-$TIMESTAMP" $SOURCE_DIRS_LIST

# Check if the backup command succeeded
if [ $? -eq 0 ]; then
    echo "Backup completed successfully!"
    # Send success notification (replace with your actual send function)
    $SCRIPT_DIR/notifications.sh success "Backup completed for htdocs directories at $TIMESTAMP"
else
    echo "Backup failed!"
    # Send error notification (replace with your actual send function)
    $SCRIPT_DIR/notifications.sh error "Backup failed for htdocs directories at $TIMESTAMP"
fi

# Prune old backups
echo "Pruning old backups..."
borg prune -v --list "$BORG_REPO_FILES" -a 'sites-*' $BORG_KEEP_FILES

# Clean up local backup directory (if desired)
echo "Cleaning up local files..."
rm -rf $BACKUP_DIR/files

echo "Backup process completed!"
