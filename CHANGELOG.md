# Changelog - borgBackupScripts

All notable changes to borgBackupScripts will be documented in this file.

## [2.0.5] - 2026-02-16

### CRITICAL FIXES
- **Fixed YAML structure errors** - Moved retention policy fields (`keep_hourly`, `keep_daily`, `keep_weekly`, `keep_monthly`, `keep_yearly`) to top-level keys (NOT nested under `retention:` section as per borgmatic requirements)
- **Fixed consistency section structure** - Ensured `checks:` is properly nested under `consistency:`
- **Added official borgmatic reference configuration** - Added `docs/reference.config.yaml` for future validation

### Impact
- ✅ Retention policies now work correctly (archives will be pruned)
- ✅ Consistency checks will run as configured
- ✅ Config validation now succeeds
- ✅ Storage growth is now controlled (old archives will be deleted)

### Files Changed
- `config-databases.yaml` - Corrected structure
- `config-files.yaml` - Corrected structure
- `docs/reference.config.yaml` - Added (new)

---

## [2.0.4] - 2026-02-16

### CRITICAL FIXES
- **Fixed borgmatic Jinja2 templating issue** - Removed `| default()` filters from `compression` field
- **Changed compression to static value** - Set `compression: lzma` (can be overridden via environment variable)

### Technical Details
- Borgmatic's Jinja2 parser has limitations: `{{ env "VAR" | default("value") }}` is NOT supported
- Compression field must be either: static value OR simple `{{ env "VAR" }}` without filters
- Users can still override compression via `BORG_COMPRESSION` environment variable

### Files Changed
- `config-databases.yaml` - Removed problematic templating
- `config-files.yaml` - Removed problematic templating

---

## [2.0.3] - 2026-02-16

### CRITICAL FIXES
- **Fixed borgmatic YAML parsing error** - Attempted to add default values to environment variables using `| default()` filters
- **Issue discovered**: Borgmatic doesn't support `| default()` filters, causing "unhashable key" errors

### Note
This version attempted a fix but introduced the issue resolved in v2.0.4.

---

## [2.0.2] - 2026-02-16

### CRITICAL FIXES
- **Fixed systemd timer configuration** - Corrected environment variable passing in systemd services
- **Fixed bash syntax errors** - Resolved shell script issues in setup.sh
- **Updated example.env** - Added missing variables and corrected format
- **Fixed discover-htdocs.sh** - Updated to use environment variables correctly

### Files Changed
- `setup.sh` - Fixed systemd service configuration
- `scripts/discover-htdocs.sh` - Environment variable sourcing
- `example.env` - Added missing variables
- `scripts/check-db-engine.sh` - Syntax corrections

---

## [2.0.1] - 2026-02-16

### MAJOR RELEASE - Complete Migration to Borgmatic

#### Overview
Complete rewrite from custom bash scripts to borgmatic-based backup solution. Provides:
- **Native database dumping** via borgmatic hooks (no custom scripts)
- **Proper systemd integration** with automatic scheduling
- **Centralized configuration** via YAML files
- **Built-in retention policies** with fine-grained control
- **Consistency checks** for data integrity verification
- **Better error handling** and logging
- **Notification support** via Apprise, Healthchecks, and more

#### New Features

**Database Backups (config-databases.yaml)**
- Native MySQL/MariaDB dumps via borgmatic `mysql_databases` hook
- Automatic streaming to Borg repository
- No temporary files on disk
- Support for individual databases or "all" databases
- Configurable mysqldump options
- Aggressive retention: 7 days hourly, 30 daily, 15 weekly, 36 monthly, 10 yearly

**File Backups (config-files.yaml)**
- Dynamic discovery of CloudPanel user directories via `discover-htdocs.sh`
- Smart exclusion patterns (node_modules, .git, cache, logs, etc.)
- Conservative retention: 7 daily, 12 weekly, 12 monthly, 10 yearly
- Support for custom per-site configurations

**Systemd Integration**
- `borgmatic-databases.timer` - Hourly database backups
- `borgmatic-files.timer` - Every 6 hours file backups
- Proper timezone configuration
- Automatic retry on failure
- Journal logging

**Setup Script**
- Automated installation of borgmatic and dependencies
- Repository creation on remote server
- SSH key generation and distribution
- Systemd timer installation with timezone support
- Test backup execution
- Comprehensive validation

**Environment Variables**
- Centralized configuration via `.env` file
- All sensitive data externalized
- Example file with all options documented

#### Breaking Changes from v1.x

**Removed Scripts** (replaced by borgmatic):
- `database_backup.sh` - Use `config-databases.yaml` instead
- `files_backup.sh` - Use `config-files.yaml` instead
- `files_userDirs_backup.sh` - Use `config-files.yaml` instead
- `notifications.sh` - Use borgmatic monitoring hooks instead

**Configuration Changes**:
- Old: Separate bash scripts with inline configuration
- New: YAML configuration files (config-databases.yaml, config-files.yaml)

**Installation Changes**:
- Old: Manual script setup and cron jobs
- New: Automated `setup.sh` with systemd timers

#### New Files
- `config-databases.yaml` - Database backup configuration
- `config-files.yaml` - File backup configuration
- `scripts/discover-htdocs.sh` - Dynamic CloudPanel site discovery
- `scripts/check-db-engine.sh` - Database engine detection
- `setup.sh` - Automated installation and setup
- `example.env` - Environment variable template
- `MIGRATION_SUMMARY.md` - Migration guide from v1.x

#### Documentation
- Complete README rewrite
- Migration guide for existing users
- Database backup performance guide
- Notification setup guide

---

## [1.x] - Previous Versions

### Features
- Custom bash scripts for database and file backups
- Manual cron job configuration
- Basic notification support
- CloudPanel support with per-site backups

### Limitations
- No native retention policies
- Manual error handling
- Difficult to configure
- Limited monitoring options