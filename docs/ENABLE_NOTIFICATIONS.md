# 🔔 Enable Notifications and Health Checks

By default, notifications and health checks are disabled in the borgmatic configurations. This allows the setup script to validate configurations successfully.

To enable notifications and health checks, follow these steps:

---

## 1. Enable Apprise Notifications

### Step 1: Configure APRISE_URL in .env

Edit your `.env` file:
```bash
nano ~/borgmatic-migration/.env
```

Add your Apprise URL:
```bash
# Telegram
APRISE_URL="tgram://BOT_TOKEN/CHAT_ID"

# Email
APRISE_URL="mailto://user:pass@smtp.example.com?from=backup@example.com&to=admin@example.com"

# Multiple services (comma-separated)
APRISE_URL="tgram://BOT_TOKEN/CHAT_ID,mailto://..."
```

### Step 2: Uncomment Monitoring in Configurations

**For database backups:**
```bash
sudo nano /etc/borgmatic/config-databases.yaml
```

Find and uncomment:
```yaml
# Apprise for notifications (Telegram, email, etc.)
# Uncomment and configure APRISE_URL in .env to enable
monitoring:
    - apprise: {{ env "APRISE_URL" }}
```

**For file backups:**
```bash
sudo nano /etc/borgmatic/config-files.yaml
```

Find and uncomment:
```yaml
# Apprise for notifications (Telegram, email, etc.)
# Uncomment and configure APRISE_URL in .env to enable
monitoring:
    - apprise: {{ env "APRISE_URL" }}
```

### Step 3: Test Notification

```bash
# Test Apprise directly
apprise -t "Test Message" -b "This is a test notification" "$APRISE_URL"

# Or test via borgmatic dry-run
sudo borgmatic create --config /etc/borgmatic/config-databases.yaml --dry-run
```

---

## 2. Enable Health Checks

### Step 1: Get Health Check URL

1. Go to https://healthchecks.io/
2. Sign up (free for basic use)
3. Create a new check (e.g., "Database Backup")
4. Copy the ping URL

### Step 2: Configure HEALTHCHECKS_PING_URL in .env

```bash
nano ~/borgmatic-migration/.env
```

Add:
```bash
HEALTHCHECKS_PING_URL="https://hc-ping.com/your-uuid"
```

### Step 3: Uncomment Health Checks in Configurations

**For database backups:**
```bash
sudo nano /etc/borgmatic/config-databases.yaml
```

Find and uncomment:
```yaml
# Health checks (optional)
# Uncomment and configure if using healthchecks.io
healthchecks:
    ping_url: {{ env "HEALTHCHECKS_PING_URL" }}
```

**For file backups:**
```bash
sudo nano /etc/borgmatic/config-files.yaml
```

Find and uncomment:
```yaml
# Health checks (optional)
# Uncomment and configure if using healthchecks.io
healthchecks:
    ping_url: {{ env "HEALTHCHECKS_PING_URL" }}
```

### Step 4: Test Health Check

```bash
# Manually ping the URL
curl "$HEALTHCHECKS_PING_URL"

# Or trigger a backup to test
sudo borgmatic create --config /etc/borgmatic/config-databases.yaml
```

---

## 3. Available Apprise Services

Apprise supports 50+ notification services. Popular options:

### Telegram
```bash
APRISE_URL="tgram://BOT_TOKEN/CHAT_ID"
```

### Email
```bash
APRISE_URL="mailto://user:pass@smtp.example.com?from=backup@example.com&to=admin@example.com"
```

### Slack
```bash
APRISE_URL="slack://TokenA/TokenB/TokenC"
```

### Discord
```bash
APRISE_URL="discord://WebhookID/WebhookToken"
```

### Pushover
```bash
APRISE_URL="pover://user@key"
```

### Multiple Services
```bash
APRISE_URL="tgram://BOT_TOKEN/CHAT_ID,mailto://user:pass@smtp.example.com?from=backup@example.com&to=admin@example.com"
```

For complete list: https://github.com/caronc/apprise#supported-notifications

---

## 4. Self-Hosted Health Checks

If you prefer self-hosted monitoring:

### Uptime Kuma
```bash
# Install via Docker
docker run -d --restart=always -p 3001:3001 -v uptime-kuma:/app/data louislam/uptime-kuma:1

# Configure push URL in .env
HEALTHCHECKS_PING_URL="https://your-kuma-instance.com/api/push/ID?status=up&msg=OK&ping="
```

### Other Options
- **Prometheus Alertmanager**: https://prometheus.io/docs/alerting/latest/alertmanager/
- **Grafana Loki**: https://grafana.com/oss/loki/
- **Netdata**: https://www.netdata.cloud/

---

## 5. Notification Events

borgmatic will send notifications for:

- **Backup started**: `before_backup` hook
- **Backup completed successfully**: `after_backup` hook
- **Backup failed**: `on_error` hook
- **Repository check failed**: Automatic
- **Health check timeout**: Via healthchecks.io

---

## 6. Troubleshooting

### Apprise Not Working

**Test Apprise directly:**
```bash
apprise -t "Test" -b "Message" "tgram://BOT_TOKEN/CHAT_ID"
```

**Common issues:**
- Wrong bot token or chat ID
- Bot not started or not added to group
- Network/firewall blocking connections

### Health Check Not Pinging

**Test URL directly:**
```bash
curl -v "$HEALTHCHECKS_PING_URL"
```

**Common issues:**
- Wrong UUID
- Network blocking
- Health checks.io service down

### No Notifications Received

**Check logs:**
```bash
# borgmatic logs
journalctl -u borgmatic-databases -n 50

# Check for apprise errors
grep -i apprise /var/log/borgmatic-databases.log
```

---

## 7. Best Practices

1. **Test notifications before relying on them**
2. **Use multiple notification channels** (email + instant messaging)
3. **Monitor the monitors** - check that your monitoring service is working
4. **Don't use notifications for informational messages only** - use them for failures
5. **Keep notification credentials secure** - don't commit to git

---

## 8. Quick Reference

### Enable Everything
```bash
# 1. Configure .env
nano ~/borgmatic-migration/.env
# Add APRISE_URL and HEALTHCHECKS_PING_URL

# 2. Enable in database config
sudo nano /etc/borgmatic/config-databases.yaml
# Uncomment healthchecks and monitoring sections

# 3. Enable in files config
sudo nano /etc/borgmatic/config-files.yaml
# Uncomment healthchecks and monitoring sections

# 4. Test
apprise -t "Test" -b "Test" "$APRISE_URL"
curl "$HEALTHCHECKS_PING_URL"

# 5. Trigger test backup
sudo borgmatic create --config /etc/borgmatic/config-databases.yaml --dry-run
```

### Disable Notifications
```bash
# Comment out in both configs
sudo nano /etc/borgmatic/config-databases.yaml
sudo nano /etc/borgmatic/config-files.yaml
# Add # before monitoring and healthchecks sections