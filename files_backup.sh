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

# Create a list of files/folders to back up
SOURCE_DIRS_LIST=""
for DIR in "${SOURCE_DIRS[@]}"; do
    SOURCE_DIRS_LIST+="$DIR "
done

# Exclude directories or files specified in .env
EXCLUDE_ARGS=""
for EXCLUDE in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_ARGS+="--exclude $EXCLUDE "
done

# Set timestamp for unique backup name
TIMESTAMP=$(date "+%Y-%m-%d_%H-%M-%S")

# Run Borg backup for files/folders
echo "Starting Borg backup for files/folders..."
borg create --compression "$BORG_COMPRESSION" --stats $EXCLUDE_ARGS "$BORG_REPO_FILES::files-$TIMESTAMP" $SOURCE_DIRS_LIST

# Check if the backup command succeeded
if [ $? -eq 0 ]; then
    echo "File/Folder backup completed successfully!"
    # Send success notification (replace with your actual send function)
    ./notifications.sh success "Backup completed for files at $TIMESTAMP"
else
    echo "Backup failed!"
    # Send error notification (replace with your actual send function)
    ./notifications.sh error "Backup failed for files at $TIMESTAMP"
fi

# Prune old backups
echo "Pruning old file/folder backups..."
borg prune -v --list "$BORG_REPO_FILES" -a 'files-*' $BORG_KEEP_FILES

# Clean up local backup directory (if desired)
echo "Cleaning up local files..."
rm -rf $BACKUP_DIR/files

echo "File/Folder backup process completed!"
