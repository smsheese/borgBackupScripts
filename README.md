# 🗂️ **Borgmatic Backup Scripts for CloudPanel**

Automated backup solution for **CloudPanel** servers using **borgmatic** - a Python wrapper for BorgBackup.

## 🎯 **Overview**

This repository provides a complete backup solution specifically designed for **CloudPanel** environments. It automates database and file backups using **borgmatic**, offering:

- ✅ **Native MySQL/MariaDB database backups** - Automatic dumps with zero locking
- ✅ **Dynamic CloudPanel site discovery** - Auto-detects all `/home/*/htdocs` directories
- ✅ **Configuration-driven** - YAML-based instead of bash scripts
- ✅ **Built-in monitoring** - Optional health checks and notifications (50+ services)
- ✅ **Smart scheduling** - Systemd timers with proper persistence
- ✅ **Comprehensive documentation** - Migration guides and performance analysis

---

## 🆚 **What's New in v2.0.1**

### Migrated from Bash Scripts to borgmatic

| Old (Bash Scripts) | New (borgmatic) |
|-------------------|------------------|
| `database_backup.sh` | Native `mysql_databases` in config |
| `files_backup.sh` | `source_directories` with patterns |
| `files_userDirs_backup.sh` | Dynamic `discover-htdocs.sh` hook |
| `notifications.sh` | Apprise integration (50+ services) |
| Cron jobs | Systemd timers |
| Manual loop scripts | Configuration-driven |

### Key Improvements

- **Zero database locking** - InnoDB databases use `--single-transaction`
- **Automatic discovery** - No need to manually list CloudPanel sites
- **Better retention** - Separate policies for databases (hourly) and files (daily)
- **Active maintenance** - Built on well-supported borgmatic project
- **Built-in validation** - Repository and archive checks included

---

## 📦 **Prerequisites**

### Required Software

- **BorgBackup** >= 1.1
  ```bash
  sudo apt update
  sudo apt install borgbackup
  ```

- **Python** >= 3.7 (usually pre-installed)

- **pipx** (for borgmatic installation)
  ```bash
  sudo apt update
  sudo apt install pipx
  ```

### System Requirements

- CloudPanel server with `/home/*/htdocs` structure
- SSH access to remote backup server
- Existing SSH key for Borg authentication
- MySQL/MariaDB root access for database backups

---

## 🚀 **Quick Installation**

### 1. Clone the Repository

```bash
git clone https://github.com/smsheese/borgBackupScripts.git
cd borgBackupScripts
```

### 2. Make Scripts Executable

```bash
chmod +x setup.sh scripts/*.sh
```

### 3. Configure Environment Variables

```bash
cp example.env .env
nano .env
```

**Required Configuration:**

```bash
# Database Connection
DB_HOST="localhost"
DB_PORT="3306"
DB_USER="root"
DB_PASS="your_database_password"

# Borg Repository (Remote)
BORG_REMOTE_USER="backup_user"
BORG_REMOTE_HOST="backup.server.com"
BORG_PASSPHRASE="strong_encryption_passphrase"
SSH_PRIVATE_KEY=~/.ssh/borgBackup
BORG_REMOTE_PATH_DB="./databases"
BORG_REMOTE_PATH_FILES="./files"
BORG_COMPRESSION="lzma"

# CloudPanel Paths
CLOUDPANEL_HOME_BASE="/home"
CLOUDPANEL_HTDOCS_SUBDIR="htdocs"
```

**Optional Configuration:**

```bash
# Notifications (see docs/ENABLE_NOTIFICATIONS.md)
APRISE_URL="tgram://BOT_TOKEN/CHAT_ID"

# Health Checks
HEALTHCHECKS_PING_URL="https://hc-ping.com/your-uuid"
```

### 4. Run Setup Script

```bash
sudo bash setup.sh
```

The setup script will:
- ✓ Check prerequisites (Borg, pipx)
- ✓ Install borgmatic
- ✓ Copy configuration files
- ✓ Install discovery script
- ✓ Create Borg repositories
- ✓ Set up systemd timers
- ✓ Run test backups

---

## 🏗️ **Architecture**

```
┌─────────────────────────────────────────────────────────────┐
│              config-databases.yaml                         │
│  - MySQL/MariaDB configuration                           │
│  - Native database dumps with --single-transaction          │
│  - Hourly schedule                                       │
│  - Aggressive retention (168 hourly, 30 daily, etc.)        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 config-files.yaml                          │
│  - CloudPanel sites (dynamic via discover-htdocs.sh)        │
│  - Smart exclusions (node_modules, .git, logs, etc.)    │
│  - 6-hourly schedule                                     │
│  - Conservative retention (7 daily, 12 weekly, etc.)        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│           discover-htdocs.sh (hook script)                  │
│  - Discovers all /home/*/htdocs directories                  │
│  - Generates dynamic include file                           │
│  - Runs before each file backup                             │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              Systemd Timers (scheduling)                   │
│  - borgmatic-databases.timer (hourly)                       │
│  - borgmatic-files.timer (every 6 hours)                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 💻 **Usage**

### Manual Backups

```bash
# Database backup
sudo borgmatic create --config /etc/borgmatic/config-databases.yaml --verbosity 1 --stats

# Files backup
sudo borgmatic create --config /etc/borgmatic/config-files.yaml --verbosity 1 --stats

# Both backups
sudo borgmatic create --config /etc/borgmatic/config-databases.yaml --config /etc/borgmatic/config-files.yaml --verbosity 1 --stats
```

### List Archives

```bash
# List database archives
sudo borgmatic list --config /etc/borgmatic/config-databases.yaml

# List file archives
sudo borgmatic list --config /etc/borgmatic/config-files.yaml
```

### Restore Files

```bash
# List contents of an archive
sudo borgmatic extract --config /etc/borgmatic/config-files.yaml --archive sites-2024-02-16_12-00 --list

# Restore entire archive
sudo borgmatic extract --config /etc/borgmatic/config-files.yaml --archive sites-2024-02-16_12-00 --destination /restore/path

# Restore specific path
sudo borgmatic extract --config /etc/borgmatic/config-files.yaml --archive sites-2024-02-16_12-00 --path /home/user/htdocs --destination /restore/path
```

### Restore Databases

Databases are dumped as SQL files during backup:

```bash
# 1. Extract to temporary location
sudo borgmatic extract --config /etc/borgmatic/config-databases.yaml --archive databases-2024-02-16_12-00 --destination /tmp/restore

# 2. Import the SQL file
mysql -u root -p my_database < /tmp/restore/path/to/my_database.sql
```

### Prune Archives

```bash
# Apply retention policy
sudo borgmatic prune --config /etc/borgmatic/config-databases.yaml --stats
sudo borgmatic prune --config /etc/borgmatic/config-files.yaml --stats
```

### Check Backup Integrity

```bash
sudo borgmatic check --config /etc/borgmatic/config-databases.yaml
sudo borgmatic check --config /etc/borgmatic/config-files.yaml
```

---

## 📊 **Monitoring**

### Check Systemd Timers

```bash
# View timer status
systemctl list-timers borgmatic-*

# View next scheduled runs
systemctl show borgmatic-databases.timer | grep Next
systemctl show borgmatic-files.timer | grep Next
```

### View Logs

```bash
# Real-time logs
journalctl -u borgmatic-databases -f
journalctl -u borgmatic-files -f

# Last 50 lines
journalctl -u borgmatic-databases -n 50
```

### View Backup Statistics

```bash
sudo borgmatic info --config /etc/borgmatic/config-databases.yaml
sudo borgmatic info --config /etc/borgmatic/config-files.yaml
```

---

## 📈 **Database Backup Performance**

### Will Hourly Backups Slow Down Your Server?

**Short Answer**: For most modern databases (InnoDB), **NO**. The configuration uses `--single-transaction` which creates consistent snapshots without locking tables.

### Check Your Database Engine

Run the included checker script:
```bash
./scripts/check-db-engine.sh
```

This will tell you:
- Which storage engines your databases use (InnoDB vs MyISAM)
- Total database size
- Estimated backup duration
- Whether hourly backups are safe for your setup

### Performance by Database Size

| Size | Backup Time | Impact | Recommendation |
|------|--------------|---------|----------------|
| < 500MB | 1-5 min | Negligible | Hourly ✅ |
| 500MB - 2GB | 5-15 min | Minimal | Hourly ✅ |
| 2GB - 5GB | 15-30 min | Moderate | Every 6 hours ⚠️ |
| > 5GB | 30-60+ min | Significant | Every 12-24 hours ⚠️ |

For detailed performance analysis, see:
```bash
cat docs/DATABASE_BACKUP_PERFORMANCE.md
```

---

## 🔔 **Enable Notifications (Optional)**

By default, notifications and health checks are disabled. To enable them:

### Quick Start

```bash
# 1. Configure .env with notification details
nano .env
# Add: APRISE_URL="tgram://BOT_TOKEN/CHAT_ID"

# 2. Enable in database config
sudo nano /etc/borgmatic/config-databases.yaml
# Uncomment healthchecks and monitoring sections

# 3. Enable in files config
sudo nano /etc/borgmatic/config-files.yaml
# Uncomment healthchecks and monitoring sections
```

### Available Notification Services

**Apprise supports 50+ services:**
- Telegram, Slack, Discord
- Email, SMS, Push notifications
- Custom webhooks

Full list: https://github.com/caronc/apprise#supported-notifications

For complete setup guide, see:
```bash
cat docs/ENABLE_NOTIFICATIONS.md
```

---

## 🔄 **Migrating from Old Scripts**

### Step 1: Keep Old System Running

Don't disable your old backup scripts yet! Run both systems in parallel for a few days.

### Step 2: Install and Test

```bash
sudo bash setup.sh
```

### Step 3: Verify Backups

After 24-48 hours:

```bash
# Check if backups are running
systemctl list-timers borgmatic-*

# Check logs
journalctl -u borgmatic-databases -n 20

# List archives
sudo borgmatic list --config /etc/borgmatic/config-databases.yaml
```

### Step 4: Test Restore

**Test file restore:**
```bash
sudo borgmatic extract \
  --config /etc/borgmatic/config-files.yaml \
  --archive sites-2024-02-16_12-00 \
  --path /home/user/htdocs/index.php \
  --destination /tmp/test-restore
```

**Test database restore:**
```bash
sudo borgmatic extract \
  --config /etc/borgmatic/config-databases.yaml \
  --archive databases-2024-02-16_12-00 \
  --destination /tmp/test-restore

mysql -u root -p test_db < /tmp/test-restore/path/to/database.sql
```

### Step 5: Disable Old Scripts

Once confident the new system works:
```bash
# Disable cron jobs
sudo crontab -e
# Comment out old backup entries

# Stop old systemd services (if any)
sudo systemctl disable old-backup.service
sudo systemctl stop old-backup.service
```

For detailed migration guide, see:
```bash
cat MIGRATION_SUMMARY.md
```

---

## 🔧 **Troubleshooting**

### Common Issues

#### 1. "No htdocs directories found"

**Cause**: No CloudPanel users or incorrect path configuration.

**Solution**:
```bash
# Test discovery script manually
sudo /usr/local/bin/discover-htdocs.sh

# Check CloudPanel home directory
ls -la /home/

# Verify path configuration in .env
cat /etc/borgmatic/config-files.yaml | grep CLOUDPANEL
```

#### 2. "Permission denied" when accessing repository

**Cause**: SSH key issues or repository permissions.

**Solution**:
```bash
# Test SSH connection
ssh -i ~/.ssh/borgBackup -p 22 remoteUser@remote.host

# Verify repository exists
ssh -i ~/.ssh/borgBackup -p 22 remoteUser@remote.host "ls -la ./databases"

# Check SSH key permissions
chmod 600 ~/.ssh/borgBackup
```

#### 3. Database dump fails

**Cause**: MySQL credentials incorrect or database inaccessible.

**Solution**:
```bash
# Test MySQL connection
mysql -h localhost -u root -p

# Check borgmatic configuration
sudo borgmatic config validate --config /etc/borgmatic/config-databases.yaml

# Check database dump (manual)
mysqldump -u root -p --all-databases | head
```

#### 4. "Borg passphrase required" prompts

**Cause**: `BORG_PASSPHRASE` not set or not loaded.

**Solution**:
```bash
# Export passphrase
export BORG_PASSPHRASE="your_passphrase"

# Or set in .env and source it
source .env
sudo BORG_PASSPHRASE="$BORG_PASSPHRASE" borgmatic create ...
```

---

## 📚 **Additional Resources**

### Official Documentation

- [borgmatic Documentation](https://torsion.org/borgmatic/)
- [BorgBackup Documentation](https://borgbackup.readthedocs.io/)
- [Apprise Documentation](https://github.com/caronc/apprise)

### Configuration Reference

- [borgmatic Configuration Options](https://torsion.org/borgmatic/docs/reference/configuration/)
- [Database Dumps](https://torsion.org/borgmatic/docs/how-to/backup-your-databases/)
- [Retention Policies](https://torsion.org/borgmatic/docs/how-to/deal-with-very-large-backups/#consider-a-pruning-policy)

### Monitoring

- [Healthchecks.io](https://healthchecks.io/) - Free health check monitoring
- [Uptime Kuma](https://github.com/louislam/uptime-kuma) - Self-hosted monitoring

---

## 🤝 **Support**

### Getting Help

- **borgmatic IRC**: #borgmatic on Libera Chat
- **borgmatic Issues**: https://projects.torsion.org/borgmatic-collective/borgmatic/issues
- **GitHub Mirror**: https://github.com/borgmatic-collective/borgmatic

### Common Commands Cheat Sheet

```bash
# Installation
sudo pipx install borgmatic
pip install apprise

# Configuration
sudo borgmatic config validate --config /etc/borgmatic/config-databases.yaml
sudo borgmatic config generate

# Operations
sudo borgmatic create --config /etc/borgmatic/config-databases.yaml --verbosity 1 --stats
sudo borgmatic list --config /etc/borgmatic/config-databases.yaml
sudo borgmatic prune --config /etc/borgmatic/config-databases.yaml
sudo borgmatic check --config /etc/borgmatic/config-databases.yaml
sudo borgmatic info --config /etc/borgmatic/config-databases.yaml

# Systemd
systemctl status borgmatic-databases.timer
journalctl -u borgmatic-databases -f
systemctl restart borgmatic-databases.service
```

---

## 📜 **License**

This project is licensed under the MIT License.

---

## ⚠️ **Important Notes**

1. **Test restores regularly** - Backups are useless if you can't restore
2. **Monitor disk space** - Both local and remote
3. **Keep encryption passphrases safe** - Store them securely
4. **Test notification system** - Ensure alerts work before relying on them
5. **Review retention policies** - Adjust based on your needs
6. **Document your restore procedure** - Before you need it
7. **Keep old system until confident** - Don't switch overnight

---

## 🌟 **Special Features for CloudPanel**

### Dynamic Site Discovery

The `discover-htdocs.sh` hook script automatically discovers all CloudPanel sites by scanning `/home/*/htdocs` directories. This means:

- ✅ **No manual configuration** - New sites are automatically backed up
- ✅ **CloudPanel-native** - Works with standard CloudPanel structure
- ✅ **Smart exclusions** - Automatically excludes `node_modules`, `.git`, logs, etc.

### Database Performance Optimization

Designed specifically for CloudPanel's MySQL/MariaDB databases:
- **InnoDB-optimized** - Uses `--single-transaction` for zero locking
- **Consistent snapshots** - No downtime for your sites
- **Hourly retention** - Protects against data loss with minimal impact

### File Exclusions

Automatically excludes common unnecessary files:
- `node_modules/` - JavaScript dependencies
- `.git/` - Version control
- `logs/` and `log/` - Application logs
- `cache/`, `tmp/`, `temp/` - Temporary files
- `.env` files - May contain secrets
- `backup/` and `backups/` - Avoid infinite loops

---

### 🤖 **Happy Backing Up!** 🎉