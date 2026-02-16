# 📋 Migration Summary

## What Was Created

This directory contains a complete borgmatic-based backup system to replace your custom bash scripts.

---

## 📁 File Structure

```
borgmatic-migration/
├── example.env                  # Environment variables template
├── setup.sh                     # Automated installation script
├── config-databases.yaml         # Database backup configuration
├── config-files.yaml            # Files backup configuration
├── scripts/
│   └── discover-htdocs.sh       # CloudPanel site discovery script
├── docs/
├── README.md                    # Comprehensive documentation
├── .gitignore                   # Git ignore rules
└── MIGRATION_SUMMARY.md         # This file
```

---

## 🔄 What Replaces What

| Old Component | New Component | Location |
|---------------|---------------|----------|
| `database_backup.sh` | borgmatic native `mysql_databases` | `config-databases.yaml` |
| `files_userDirs_backup.sh` | borgmatic + discovery hook | `config-files.yaml` + `scripts/discover-htdocs.sh` |
| `notifications.sh` | borgmatic Apprise integration | Configured in YAML files |
| `cron jobs` | Systemd timers | Created by `setup.sh` |
| `.env` | `.env` (same format) | `example.env` → `.env` |

---

## 🚀 Quick Start

### 1. Configure Environment

```bash
cd borgmatic-migration
cp example.env .env
nano .env  # Edit with your values
```

**Required settings:**
- `DB_USER`, `DB_PASS`, `DB_HOST` (MySQL credentials)
- `BORG_REMOTE_USER`, `BORG_REMOTE_HOST` (Backup server)
- `BORG_PASSPHRASE` (Repository encryption key)
- `SSH_PRIVATE_KEY` (Path to your SSH key)

### 2. Run Setup

```bash
sudo bash setup.sh
```

The script will:
- Install borgmatic and Apprise
- Copy configurations to `/etc/borgmatic/`
- Install discovery script to `/usr/local/bin/`
- Create Borg repositories
- Set up systemd timers
- Run test backups

### 3. Verify

```bash
# Check timer status
systemctl list-timers borgmatic-*

# View logs
journalctl -u borgmatic-databases -n 20
journalctl -u borgmatic-files -n 20

# List archives
sudo borgmatic list --config /etc/borgmatic/config-databases.yaml
sudo borgmatic list --config /etc/borgmatic/config-files.yaml
```

---

## 📊 Configuration Differences

### Database Retention (config-databases.yaml)
```yaml
retention:
    keep_hourly: 168    # 7 days (same as old: BORG_KEEP_DB)
    keep_daily: 30      # 30 days (same as old)
    keep_weekly: 15     # 15 weeks (same as old)
    keep_monthly: 36    # 36 months (same as old)
    keep_yearly: 10     # 10 years (same as old)
```

### Files Retention (config-files.yaml)
```yaml
retention:
    keep_daily: 7       # 7 days (same as old: BORG_KEEP_FILES)
    keep_weekly: 12     # 12 weeks (same as old)
    keep_monthly: 12    # 12 months (same as old)
    keep_yearly: 10     # 10 years (same as old)
```

### Schedules
- **Databases**: Every hour (was: cron hourly)
- **Files**: Every 6 hours (was: cron every 6 hours)

---

## ✨ Key Improvements

### 1. Automatic Database Dumps
**Old**: Custom bash loop with mysqldump
```bash
for DB in $(mysql ... | grep -v -E "$DB_EXCLUDE"); do
    mysqldump ... "$DB" > "$BACKUP_DIR/$DB.sql"
done
```

**New**: Native borgmatic support
```yaml
mysql_databases:
    - name: all
      hostname: localhost
      username: root
      password: root
```

### 2. Dynamic Directory Discovery
**Old**: Script loops through `/home/*/htdocs`
**New**: Hook script generates include file before backup
```bash
# In before_backup hook:
- /usr/local/bin/discover-htdocs.sh
```

### 3. Notifications
**Old**: Custom Telegram bot with curl
**New**: Apprise (50+ services supported)
```yaml
monitoring:
    - apprise: "tgram://BOT_TOKEN/CHAT_ID"
```

### 4. Built-in Checks
**Old**: None
**New**: Automatic repository and archive validation
```yaml
consistency:
    checks:
        - name: repository
        - name: archives
          frequency: 2 weeks
```

### 5. Health Checks
**Old**: None
**New**: Optional healthchecks.io integration
```yaml
healthchecks:
    ping_url: https://hc-ping.com/your-uuid
```

---

## 🔧 Migration Steps

### Phase 1: Setup (Do Now)
1. Configure `.env` file
2. Run `sudo bash setup.sh`
3. Verify test backups succeed

### Phase 2: Parallel Run (24-48 Hours)
1. Keep old scripts running
2. Monitor new system logs
3. Verify both systems create archives

### Phase 3: Testing (After 48 Hours)
1. Test file restore
2. Test database restore
3. Verify notifications work

### Phase 4: Cutover (After 1 Week)
1. Disable old cron jobs
2. Verify new system continues working
3. Remove old scripts (optional)

### Phase 5: Cleanup (After 1 Month)
1. Delete old Borg repositories
2. Remove old backup scripts
3. Update documentation

---

## 📝 Important Notes

### Environment Variables
The new `.env` is compatible with your old one, but adds:
- `APRISE_URL` - For notifications (replaces separate Telegram config)
- `HEALTHCHECKS_PING_URL` - For health checks (optional)
- `CLOUDPANEL_*` - For path configuration (has defaults)

### Repository Paths
Same as your old setup:
- Databases: `BORG_REMOTE_PATH_DB` (default: `./databases`)
- Files: `BORG_REMOTE_PATH_FILES` (default: `./files`)

### SSH Configuration
Uses same SSH key path: `SSH_PRIVATE_KEY` (default: `~/.ssh/borgBackup`)

### Compression
Same compression type: `BORG_COMPRESSION` (default: `lzma`)

---

## 🎯 Next Steps

1. **Read the README**: `cat README.md`
2. **Configure .env**: Edit with your actual values
3. **Run setup**: `sudo bash setup.sh`
4. **Monitor**: Check logs for 24-48 hours
5. **Test restores**: Verify you can restore data
6. **Cutover**: Disable old scripts when confident

---

## 🆘 Troubleshooting

### Setup Fails
```bash
# Check prerequisites
borg --version
pipx --version

# Run with debug
sudo bash -x setup.sh
```

### No Backups Created
```bash
# Check timer status
systemctl status borgmatic-databases.timer
systemctl status borgmatic-files.timer

# Check logs
journalctl -u borgmatic-databases -n 50
journalctl -u borgmatic-files -n 50
```

### Discovery Script Fails
```bash
# Test manually
sudo /usr/local/bin/discover-htdocs.sh

# Check CloudPanel paths
ls -la /home/
```

### Database Dump Fails
```bash
# Test MySQL connection
mysql -h localhost -u root -p

# Check borgmatic config
sudo borgmatic config validate --config /etc/borgmatic/config-databases.yaml
```

---

## 📚 Resources

- **Full Documentation**: `README.md`
- **borgmatic Docs**: https://torsion.org/borgmatic/
- **borgbackup Docs**: https://borgbackup.readthedocs.io/
- **Apprise Docs**: https://github.com/caronc/apprise

---

## ✅ Checklist

Before running setup:
- [ ] BorgBackup installed
- [ ] SSH key exists for backup server
- [ ] MySQL credentials known
- [ ] Backup server details known
- [ ] Strong encryption passphrase chosen

After running setup:
- [ ] `setup.sh` completed without errors
- [ ] Test backups successful
- [ ] Systemd timers active
- [ ] Logs show no errors
- [ ] Archives created successfully

Before cutover:
- [ ] Parallel running for 48+ hours
- [ ] File restore tested
- [ ] Database restore tested
- [ ] Notifications working
- [ ] Health checks configured (optional)

After cutover:
- [ ] Old scripts disabled
- [ ] New system stable for 1 week
- [ ] Old repositories deleted (after 1 month)