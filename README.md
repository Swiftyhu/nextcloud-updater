# Nextcloud Updater

A simple bash script to automate Nextcloud updates and maintenance tasks.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)

![screenshot](./doc/screenshot.png)

## Features

- Download and install specified Nextcloud versions
- Database maintenance (missing columns, indices, primary keys)
- InnoDB table optimization (ROW_FORMAT=DYNAMIC)
- Integrity checks for core and apps
- Automatic app updates
- Automatic cleanup of “extra files” that may remain after a Nextcloud update
- Trashbin and version cleanup

## Prerequisites

- Linux server with Nextcloud installed
- Root or sudo access
- Required packages: `wget`, `unzip`, `jq`, `mysql-client`, `php-cli`, `sudo`

## Installation

```bash
cd /var/www  # or wherever your nextcloud directory is located
wget https://raw.githubusercontent.com/Swiftyhu/nextcloud-updater/main/update.sh
chmod +x update.sh
```

**Important**: Place the script in the parent directory of your `nextcloud/` folder or define the `--nextcloud-dir` parameter.

## Usage

### Update to a specific version:
```bash
sudo ./update.sh 31.2.0
```

### Maintenance only (no version update):
```bash
sudo ./update.sh
```

### With custom configuration:
```bash
sudo ./update.sh 31.2.0 --web-user nginx --db-name my_nextcloud
```

### Show help:
```bash
./update.sh --help
```

## Configuration

You can configure the script in two ways:

### 1. Edit the configuration section (lines 33-38):
```bash
WEB_USER="www-data"       # Your web server user
WEB_GROUP="www-data"      # Your web server group
DB_NAME="nextcloud"       # Your database name
NEXTCLOUD_DIR="nextcloud" # Nextcloud directory name
DIR_PERMS="750"           # Directory permissions
FILE_PERMS="640"          # File permissions
```

### 2. Use command line options:
```bash
--web-user USER       # Web server user (default: www-data)
--web-group GROUP     # Web server group (default: www-data)
--db-name NAME        # Database name (default: nextcloud)
--nextcloud-dir DIR   # Nextcloud directory name (default: nextcloud)
```

**Example**: If you're using nginx with a different group and your database is named `nc_db`:
```bash
sudo ./update.sh 31.2.0 --web-user nginx --web-group www-data --db-name nc_db
```

## What it does

1. Downloads and extracts the specified Nextcloud version (if version given)
2. Sets proper file permissions (750 for directories, 640 for files)
3. Runs `occ upgrade`
4. Database maintenance tasks
5. Trashbin and version cleanup
6. Integrity checks for core and apps (removes extra files)
7. Updates all apps
8. Runs maintenance repair and system checks

## Warning

⚠️ **ALWAYS BACKUP YOUR DATA BEFORE RUNNING THIS SCRIPT**

This script makes significant changes to your Nextcloud installation. Make sure you have:
- Database backup
- Files backup
- Test in staging environment first

## License

GPL-3.0

## Disclaimer

Use at your own risk. This is a community tool, not an official Nextcloud product.