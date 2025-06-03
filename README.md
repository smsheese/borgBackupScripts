# 🗂️ **Backup Automation with BorgBackup** 📦

## 🚀 **Overview**
This repository contains scripts to automate **database** and **file/folder** backups using **BorgBackup**. It allows you to back up your databases and important files, while keeping backups organized and encrypted. The script handles everything from database dumps to remote backups on an SSH server. **Notifications** can be sent via Telegram and/or email, and logs are rotated automatically.

## 💻 **Getting Started**
### 1. Clone the repository
Clone this repository to your local machine:
```bash
git clone https://github.com/smsheese/borgBackupScripts.git
cd borgBackupScripts
chmod +x *.sh      # make the scripts executable
```

### 2. Create and Configure `.env` file
Copy the `example.env` file to `.env`:
```bash
cp example.env .env
```
Update the `.env` file with the appropriate details, such as:
- **Database Details** (e.g., MySQL/MariaDB)
- **Backup Directories** for files/folders
- **BorgBackup Configuration** (remote server, compression settings, etc.)
- **Notification Settings** (Telegram and/or email)
- **Log Retention** (how many log files to keep)
- **Backup Type** (choose between specified directories or all user htdocs)

> **Note:** Ensure that you enter valid SSH credentials and set up your remote server for BorgBackup.

### 3. Run the Setup Script
Run the `setup.sh` script to initialize everything:
```bash
bash setup.sh
```
This will:
- Check if **BorgBackup** is installed (and install it if needed).
- Show system and environment checks (distro, architecture, user, permissions, etc).
- Create necessary SSH keys for authentication.
- Initialize Borg repositories on your remote server.
- Help set up **cron jobs** for automated backups.
- Let you choose the files backup type (specified directories or user htdocs).

## 🔧 **Important Script Details**
The scripts `database_backup.sh` and `files_backup.sh` are responsible for the backup process.

### Database Backup Script
- **MySQL/MariaDB Dumps:** The script connects to your database and dumps all databases except for system ones (configurable; you can add other databases that you want to exclude).
- **Borg Command:** The databases are backed up to your remote Borg repository using compression (`lzma` by default).
- **Logging:** Each run creates a dated log file. The number of logs to keep is set in `.env` (`LOGS_KEEP_COUNT`).
- **Notifications:** After each backup, the full log is sent via Telegram and/or email (if enabled).

  Example command:
  ```bash
  borg create --compression lzma --stats "$BORG_REPO_DB::databases-$TIMESTAMP" "$BACKUP_DIR/databases"
  ```

### Files/Folders Backup Script
- **Backup Type:** You can choose to back up either specified directories (`SOURCE_DIRS`) or all `/home/*/htdocs` directories. Set `FILES_BACKUP_TYPE` in `.env` to `specified` or `userdirs`.
- **File Exclusions:** The script will exclude directories like `node_modules` or `.git` by default (see `EXCLUDE_DIRS`).
- **Borg Command:** It backs up the selected files/folders to your remote Borg repository.
- **Logging:** Each run creates a dated log file. The number of logs to keep is set in `.env` (`LOGS_KEEP_COUNT`).
- **Notifications:** After each backup, the full log is sent via Telegram and/or email (if enabled).

  Example command:
  ```bash
  borg create --compression lzma --stats --exclude */node_modules/* "$BORG_REPO_FILES::files-$TIMESTAMP" $SOURCE_DIRS_LIST
  ```

### Cron Jobs
Cron jobs are set up to back up your databases and files every hour. You can customize the backup frequency by modifying the cron job entries. The setup script can help you add these jobs automatically.

## 📧 **Notifications**
- **Telegram:** Set `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` in `.env`.
- **Email:** Set `EMAIL_NOTIFICATIONS_ENABLED` to `yes` and fill in the SMTP/email details in `.env`. The notification script will use `sendmail` (ensure it is installed and configured on your system).
- **Full Log Delivery:** After each backup, the entire log file (including source and target details) is sent via Telegram and/or email.

## 📝 **Log Management**
- Each backup run creates a log file named with the date and time.
- Set `LOGS_KEEP_COUNT` in `.env` to control how many logs are kept (set to `-1` for unlimited).

## ⚙️ **Customizable Borg Backup Flags**
You can modify the `.env` file to adjust the following Borg flags:
- **Compression Type** (`BORG_COMPRESSION`): You can set this to `lzma`, `zlib`, `bzip2`, etc.
- **Retention Policies** (`BORG_KEEP_DB`, `BORG_KEEP_FILES`): Configure how long backups are retained (hourly, daily, weekly, etc.).

For example:
```bash
# Retain hourly backups for 7 days, daily for 30 days
BORG_KEEP_DB="--keep-hourly=168 --keep-daily=30"
```

Check out [BorgBackup Documentation](https://borgbackup.readthedocs.io/) for more information on Borg's retention and compression options.

## 🌍 **Useful Links**
- [BorgBackup Docs](https://borgbackup.readthedocs.io/)
- [BorgBackup Installation](https://borgbackup.readthedocs.io/en/stable/installation.html)
- [BorgBackup Encryption Options](https://borgbackup.readthedocs.io/en/stable/usage/creating.html#encryption)
- [BorgBackup Pruning](https://borgbackup.readthedocs.io/en/stable/usage/pruning.html)

## 💬 **Contributing**
Feel free to contribute by:
1. Forking the repository.
2. Making improvements.
3. Creating pull requests.

## 📜 **License**
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Disclaimer
These scripts were created with the help of ChatGPT. If you encounter any issues or have suggestions for improvements, feel free to reach out. Your feedback is highly appreciated, and we're always looking to make things better! 😊

---
### 🤖 **Happy Backing Up!** 🎉
