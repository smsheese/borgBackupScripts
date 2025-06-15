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

# Function to send an email
send_email() {
    local subject="$1"
    local body="$2"
    if [ "$EMAIL_NOTIFICATIONS_ENABLED" == "yes" ]; then
        {
            echo "Subject: $subject"
            echo "From: $EMAIL_FROM"
            echo "To: $EMAIL_TO"
            echo "Content-Type: text/plain; charset=UTF-8"
            echo
            echo -e "$body"
        } | \
        /usr/sbin/sendmail -t
    fi
}

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
if [ -n "$3" ]; then
    if [ "$(timedatectl list-timezones | grep -i "$3")" ]; then
        TIMEZONE="$3"
    else
        echo "Invalid timezone specified. Using UTC as default."
    fi
fi

# Set the timezone for the current session
export TZ=$TIMEZONE

# Get current date and time in the specified format
CURRENT_DATETIME=$(date "$DATE_FORMAT")

# Check input arguments
# $1 = success|error, $2 = log file, $3 = timezone (optional)
if [ "$1" == "success" ] || [ "$1" == "error" ]; then
    LOG_FILE="$2"
    if [ -f "$LOG_FILE" ]; then
        LOG_CONTENT=$(cat "$LOG_FILE")
    else
        LOG_CONTENT="$2"
    fi
    if [ "$1" == "success" ]; then
        MSG="✅ Backup Successful for *$BACKUP_NAME* at $CURRENT_DATETIME\n\n$LOG_CONTENT"
        send_telegram_message "$MSG"
        send_email "$EMAIL_SUBJECT - SUCCESS" "$MSG"
    else
        MSG="❌ Backup Failed for *$BACKUP_NAME* at $CURRENT_DATETIME\n\n$LOG_CONTENT"
        send_telegram_message "$MSG"
        send_email "$EMAIL_SUBJECT - ERROR" "$MSG"
    fi
else
    echo "Usage: notifications.sh [success|error] [log_file_or_message] [timezone]"
fi