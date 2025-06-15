# Changelog

All notable changes to this project will be documented in this file.

## [0.1.6] - 2025-06-15
### Added
- Created `actions.sh` script for interactive backup/restore actions:
  - Run database/files backup now
  - Show list of database/files backups
  - Download full database/files backup into `download/` folder
  - Download specific database (.sql) or file/folder from backup into `download/` folder
- All downloads are placed in the `download/` folder (added to `.gitignore`).

### Fixed
- Cron schedule options in `setup.sh` now always display before prompt.
- Menu options in `setup.sh` show current files backup type and status summaries.

## [0.1.5] - 2025-06-14
### Added
- Interactive `.env` creation/copy with backup of previous `.env`.
- Option to set email notification credentials interactively.
- Enhanced main menu in `setup.sh` with status summaries and warnings for missing cron.

### Changed
- Improved cron install logic for major distros (Debian, Fedora, Arch, RHEL).
- Greyed out cron job options if cron is not available.

## [0.1.4] - 2025-06-13
### Added
- Option to select files backup type (specified/userdirs) in `setup.sh`.
- Improved `.env` checks and summaries in setup.

### Fixed
- Various bugfixes for permissions and backup directory checks.

## [0.1.3] - 2025-06-12
### Added
- SSH key generation and copy to remote server in setup.
- Borg repository initialization from setup script.

## [0.1.2] - 2025-06-11
### Added
- Database and files backup scripts using Borg.
- Notification support (email, Telegram) after backup.

## [0.1.1] - 2025-06-10
### Added
- Initial version of `setup.sh` for interactive environment setup.
- Example `.env` file and documentation.
