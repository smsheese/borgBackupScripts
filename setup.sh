#!/bin/bash

# Check if Borg is installed
if ! command -v borg &> /dev/null; then
    echo "BorgBackup is not installed."
    read -p "Do you want instructions to install BorgBackup? (y/n): " INSTALL_CHOICE
    if [[ "$INSTALL_CHOICE" == "y" || "$INSTALL_CHOICE" == "Y" ]]; then
        echo "To install BorgBackup, run the following command:"
        echo "------------------------------------------------"
        echo "sudo apt update && sudo apt install borgbackup -y"
        echo "------------------------------------------------"
        echo "Refer to https://borgbackup.readthedocs.io/ for more details."
    else
        echo "Skipping installation instructions. Exiting."
    fi
    exit 1
else
    echo "BorgBackup is installed: $(borg --version)"
fi

# Determine the script's directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")

# Load the .env file from the script's directory
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
else
    echo ".env file not found in $SCRIPT_DIR. Exiting."
    exit 1
fi

# Fix permissions of .env
chmod 600 $SCRIPT_DIR/.env

# Prompt user to select the database type
echo "Select the database type:"
echo "1. MySQL (my)"
echo "2. MariaDB (ma)"
read -p "Enter your choice (my/ma): " DB_SELECTION

# Set the correct database command based on the user's selection
if [ "$DB_SELECTION" == "my" ]; then
    DB_TYPE="mysql"
    DB_DUMP="mysqldump"
    echo "MySQL selected for database backup."
elif [ "$DB_SELECTION" == "ma" ]; then
    DB_TYPE="mariadb"
    DB_DUMP="mariadb-dump"
    echo "MariaDB selected for database backup."
else
    echo "Invalid selection. Exiting script."
    exit 1
fi

# Update the .env file with the selected database type and dump command
echo "Updating .env file with the selected database type and dump command..."
sed -i "s/^DB_TYPE=.*$/DB_TYPE=\"$DB_TYPE\"/" $SCRIPT_DIR/.env
sed -i "s/^DB_DUMP=.*$/DB_DUMP=\"$DB_DUMP\"/" $SCRIPT_DIR/.env

echo ".env file updated successfully:"
echo "DB_TYPE=\"$DB_TYPE\""
echo "DB_DUMP=\"$DB_DUMP\""

# Generate SSH keypair with restricted permissions
echo "Generating SSH key pair for backup user..."
ssh-keygen -t ed25519 -f "$SSH_PRIVATE_KEY" -C "borgBackupKey" -q -N ""

# Set restrictive permissions for the SSH key pair
chmod 600 $SSH_PRIVATE_KEY
chmod 644 $SSH_PRIVATE_KEY.pub

# Copy the public key to the remote server
echo "Copying the public key to the remote server..."
ssh-copy-id -i $SSH_PRIVATE_KEY -p $SSH_PORT -s "$BORG_REMOTE_USER@$BORG_REMOTE_HOST"

# Initialize Borg repositories on the remote server
echo "Initializing Borg repositories on the remote server..."
ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT "$BORG_REMOTE_USER@$BORG_REMOTE_HOST" "mkdir -p ./$BORG_REMOTE_PATH_DB ./$BORG_REMOTE_PATH_FILES"
export BORG_RSH="ssh -i $SSH_PRIVATE_KEY -p $SSH_PORT"
export BORG_PASSPHRASE="$BORG_PASSPHRASE"
borg init --encryption=repokey "ssh://$BORG_REMOTE_USER@$BORG_REMOTE_HOST:$SSH_PORT/./$BORG_REMOTE_PATH_DB"
borg init --encryption=repokey "ssh://$BORG_REMOTE_USER@$BORG_REMOTE_HOST:$SSH_PORT/./$BORG_REMOTE_PATH_FILES"

# Set restrictive permissions for the backup directory and SSH key
echo "Setting restrictive permissions for the backup directory and SSH key..."
chmod 700 $BACKUP_DIR
chmod 600 $SSH_PRIVATE_KEY
chmod 644 $SSH_PRIVATE_KEY.pub

# Final message
echo "SSH keypair created, public key copied to the remote server, and Borg repositories initialized."
echo "The database backup script has been updated for $DB_SELECTION."

# Generate the cron job entries
echo "Generating cron job entries..."

# Paths to the backup scripts
DB_BACKUP_SCRIPT="$SCRIPT_DIR/database_backup.sh"
FILES_BACKUP_SCRIPT="$SCRIPT_DIR/files_backup.sh"

# Suggested cron jobs (run every hour)
DB_CRON="0 * * * * /bin/bash $DB_BACKUP_SCRIPT >> $SCRIPT_DIR/logs/db_backup.log 2>&1"
FILES_CRON="0 * * * * /bin/bash $FILES_BACKUP_SCRIPT >> $SCRIPT_DIR/logs/files_backup.log 2>&1"

# Display the commands for the user
echo -e "\nAdd the following lines to your crontab to schedule backups:"
echo "------------------------------------------------------------"
echo "$DB_CRON"
echo "$FILES_CRON"
echo "------------------------------------------------------------"

# Offer to copy the cron jobs into the crontab
read -p "Do you want to automatically add these to your crontab? (y/n): " ADD_CRON

if [[ "$ADD_CRON" == "y" || "$ADD_CRON" == "Y" ]]; then
    (crontab -l 2>/dev/null; echo "$DB_CRON"; echo "$FILES_CRON") | crontab -
    echo "Cron jobs added successfully!"
else
    echo "Cron jobs not added. You can manually add them by running 'crontab -e' and copying the commands."
fi
