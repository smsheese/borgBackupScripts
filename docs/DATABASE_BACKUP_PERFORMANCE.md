# 📊 Database Backup Performance Guide

## Performance Impact of Hourly Backups

### Current Configuration
```yaml
mysql_databases:
    - name: all
      options: --skip-lock-tables --quick --single-transaction
```

### What This Means
- **Zero locking** for InnoDB tables (95%+ of modern databases)
- **Consistent snapshots** without downtime
- **Minimal performance impact** for most workloads

---

## 🔍 How to Check Your Table Types

```bash
# Check which storage engine your databases use
mysql -u root -p -e "
    SELECT table_schema, table_name, engine 
    FROM information_schema.tables 
    WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    GROUP BY engine;"
```

**Expected Output:**
```
+--------------+------------+--------+
| table_schema | table_name | engine |
+--------------+------------+--------+
| my_database | my_table   | InnoDB |
+--------------+------------+--------+
```

If you see **InnoDB**: No locking, minimal impact ✅
If you see **MyISAM**: Will lock during backup ⚠️

---

## 📈 Monitoring Backup Performance

### 1. Monitor Backup Duration
```bash
# Check how long backups take
journalctl -u borgmatic-databases -n 50 | grep "create command finished"
```

**Expected:**
- Small databases (< 1GB): 1-5 minutes
- Medium databases (1-5GB): 5-15 minutes
- Large databases (5-10GB): 15-30 minutes

### 2. Monitor Database Performance During Backup

**Install monitoring tools:**
```bash
sudo apt install -y sysstat htop
```

**Monitor during backup:**
```bash
# Start monitoring in one terminal
iostat -x 1

# In another terminal, trigger a manual backup
sudo borgmatic create --config /etc/borgmatic/config-databases.yaml --verbosity 1
```

**What to watch for:**
- CPU usage: Should not spike dramatically
- I/O wait: Should stay below 20-30%
- Query response times: Should remain normal

### 3. Monitor Slow Queries
```bash
# Enable slow query log temporarily
mysql -u root -p -e "
    SET GLOBAL slow_query_log = 'ON';
    SET GLOBAL long_query_time = 2;
    SET GLOBAL log_output = 'FILE';"

# Check during backup
tail -f /var/log/mysql/slow-query.log
```

---

## ⚙️ Optimization Options

### Option 1: Reduce Backup Frequency (If Performance is an Issue)

**Edit systemd timer:**
```bash
sudo nano /etc/systemd/system/borgmatic-databases.timer
```

**Change from:**
```ini
[Timer]
OnCalendar=hourly
```

**To (every 6 hours):**
```ini
[Timer]
OnCalendar=*:0/6:00
```

**Or (every 12 hours):**
```ini
[Timer]
OnCalendar=*:0/12:00
```

**Then reload:**
```bash
sudo systemctl daemon-reload
sudo systemctl restart borgmatic-databases.timer
```

### Option 2: Exclude Large/Seldom-Changed Databases

Edit `/etc/borgmatic/config-databases.yaml`:
```yaml
mysql_databases:
    - name: all  # Keep for most databases
      options: --skip-lock-tables --quick --single-transaction
    
    # Or specify specific databases instead of "all"
    # - name: production_db
    #   hostname: localhost
    #   username: root
    #   password: root
    #   options: --skip-lock-tables --quick --single-transaction
    # - name: another_db
    #   hostname: localhost
    #   username: root
    #   password: root
    #   options: --skip-lock-tables --quick --single-transaction
```

### Option 3: Adjust mysqldump Options

**For very large databases, add:**
```yaml
mysql_databases:
    - name: all
      options: --skip-lock-tables --quick --single-transaction --lock-tables=false --max-allowed-packet=512M
```

**Options explained:**
- `--lock-tables=false`: Extra safety to prevent any locking
- `--max-allowed-packet=512M`: Handle large rows/blob data
- `--compress`: Compress data during transfer (if bandwidth is issue)

### Option 4: Use Parallel Backups (Multiple Databases)

If you have many small databases:
```yaml
mysql_databases:
    - name: db1
      hostname: localhost
      username: root
      password: root
      options: --skip-lock-tables --quick --single-transaction
    - name: db2
      hostname: localhost
      username: root
      password: root
      options: --skip-lock-tables --quick --single-transaction
```

borgmatic can dump multiple databases in parallel if configured.

---

## 🧪 Performance Testing

### Test During Peak Hours

Run a backup during your busiest time:
```bash
# Run manual backup
sudo borgmatic create --config /etc/borgmatic/config-databases.yaml --verbosity 2 --stats

# Monitor system in another terminal
htop
```

**Check:**
- Does your website/app slow down?
- Do users experience lag?
- Are database queries timing out?

### Test Backup Size

```bash
# See backup sizes
sudo borgmatic info --config /etc/borgmatic/config-databases.yaml
```

**If backups are very large (> 5GB per backup):**
- Consider less frequent backups
- Consider excluding non-essential databases
- Consider incremental backup strategies

---

## 🚨 When to Reduce Frequency

Reduce backup frequency if:

1. **Backups take > 30 minutes**
   - Consider 6-hourly instead of hourly

2. **Server slows down during backups**
   - Check if it's I/O bound
   - Consider off-peak scheduling

3. **Database is mostly read-only**
   - Hourly may be overkill
   - Daily backups might suffice

4. **Storage space is limited**
   - Hourly backups use 7x more space than daily
   - Adjust retention policy

---

## 🎯 Recommended Settings by Database Size

### Small Databases (< 500MB)
- **Frequency**: Hourly ✅
- **Impact**: Negligible
- **Retention**: Keep hourly

### Medium Databases (500MB - 2GB)
- **Frequency**: Hourly ✅
- **Impact**: Minimal
- **Retention**: Keep hourly for 1-3 days

### Large Databases (2GB - 5GB)
- **Frequency**: Every 6 hours ⚠️
- **Impact**: Moderate during backup
- **Retention**: Keep daily only

### Very Large Databases (> 5GB)
- **Frequency**: Every 12-24 hours ⚠️
- **Impact**: Significant during backup
- **Retention**: Keep daily only
- **Consider**: Percona XtraBackup or LVM snapshots instead

---

## 🔧 Advanced: Off-Peak Scheduling

Schedule backups during low-traffic hours:

```bash
sudo nano /etc/systemd/system/borgmatic-databases.timer
```

**Example: 2 AM, 8 AM, 2 PM, 8 PM:**
```ini
[Timer]
OnCalendar=02:00,08:00,14:00,20:00
```

**Example: Every 3 hours:**
```ini
[Timer]
OnCalendar=*:0/3:00
```

**Example: Only overnight (3 AM daily):**
```ini
[Timer]
OnCalendar=03:00
```

---

## 📞 Signs You Need to Adjust

**Watch for these indicators:**

1. **Application logs show timeouts** during backup
2. **Database response time increases** significantly
3. **CPU/I/O usage spikes** during backup
4. **Users complain** about slowdown
5. **Backups consistently fail** due to timeouts

**If you see these:**
1. Reduce backup frequency
2. Check database engine type (MyISAM vs InnoDB)
3. Consider off-peak scheduling
4. Review backup exclusions

---

## 💡 Bottom Line

For **InnoDB databases** (most modern setups):
- ✅ Hourly backups with `--single-transaction` = **NO LOCKING**
- ✅ Minimal performance impact
- ✅ Recommended for production

For **MyISAM databases**:
- ⚠️ Will lock during backup
- ⚠️ Consider migrating to InnoDB
- ⚠️ Or reduce backup frequency

For **Very large databases** (> 5GB):
- ⚠️ Consider 6-12 hour intervals
- ⚠️ Or use specialized backup tools (Percona XtraBackup)

**Start with hourly, monitor for 24-48 hours, adjust if needed.**