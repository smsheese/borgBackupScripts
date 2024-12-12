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

# Function to send a Telegram message
send_telegram_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d chat_id="$TELEGRAM_CHAT_ID" \
        -d text="$message" > /dev/null
}

# Default timezone is UTC
TIMEZONE="UTC"
DATE_FORMAT="+%Y-%m-%d %H:%M:%S"  # Default datetime format

# Check for timezone argument and validate
if [ -n "$2" ]; then
    if [ "$(timedatectl list-timezones | grep -i "$2")" ]; then
        TIMEZONE="$2"
    else
        echo "Invalid timezone specified. Using UTC as default."
    fi
fi

# Set the timezone for the current session
export TZ=$TIMEZONE

# Get current date and time in the specified format
CURRENT_DATETIME=$(date "$DATE_FORMAT")

# Check input arguments
if [ "$1" == "success" ]; then
    send_telegram_message "✅ Backup Successful for *$BACKUP_NAME* at $CURRENT_DATETIME"
elif [ "$1" == "error" ]; then
    send_telegram_message "❌ Backup Failed for *$BACKUP_NAME* at $CURRENT_DATETIME. Error details: $2"
else
    echo "Usage: notifications.sh [success|error] [error_details]"
fi