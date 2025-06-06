# Scripts Directory Overview

This directory contains various scripts for automating tasks, maintenance, and operations related to the Bitrix infrastructure.

## Python Environment Setup

For Python scripts in this directory, it's recommended to use a virtual environment:

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install required packages
pip3 install -r requirements.txt
```

## Scripts and Files

Below is a list of scripts and relevant files found in this directory:

*   **`alter-robots-txt.sh`**
    *   **Type:** Shell script (`.sh`)
    *   **Purpose:** Updates robots.txt files for regional subdomains, blocking specific sections based on region.
    *   **Notes:** May take arguments to specify the environment (e.g., dev/prod).

*   **`check-404.sh`**
    *   **Type:** Shell script (`.sh`)
    *   **Purpose:** Analyzes nginx logs to find 404 errors from search engine bots for redirect troubleshooting.
    *   **Notes:** Might use `urls.txt` or a similar file as input.

*   **`compare-backups.sh`**
    *   **Type:** Shell script (`.sh`)
    *   **Purpose:** Interactive tool to compare two backups from S3, showing differences between selected dates.

*   **`disaster-recovery.sh`**
    *   **Type:** Shell script (`.sh`)
    *   **Purpose:** Automates disaster recovery process by setting up a fresh Ubuntu server with Docker, restoring files from S3 backup, and recovering MySQL database.
    *   **Notes:** Critical script that orchestrates multiple recovery steps.

*   **`file-backup.sh`**
    *   **Type:** Shell script (`.sh`)
    *   **Purpose:** Performs incremental file backups to S3 using duplicity. Excludes cache, logs, and development directories. Full backup every 60 days.

*   **`find-image-type-mismatch.sh`**
    *   **Type:** Shell script (`.sh`)
    *   **Purpose:** Detects images where file extension doesn't match actual MIME type.

*   **`fix-rights.sh`**
    *   **Type:** Shell script (`.sh`)
    *   **Purpose:** Sets proper file ownership for containers (UID/GID 1000 for PHP/Nginx, 1001 for MySQL). Must be run after file operations.
    *   **Notes:** Critical for ensuring the application runs correctly after deployment or file changes.

*   **`mysql-dump.sh`**
    *   **Type:** Shell script (`.sh`)
    *   **Purpose:** Creates compressed MySQL dump and uploads to S3. Excludes user sessions table to reduce backup size.
    *   **Notes:** May require database credentials, possibly from environment variables or a configuration file.

*   **`optimise-images.sh`**
    *   **Type:** Shell script (`.sh`)
    *   **Purpose:** Optimizes PNG, JPEG, WebP, and GIF images using various tools. Marks processed files to avoid reprocessing.

*   **`renew-dev.sh`**
    *   **Type:** Shell script (`.sh`)
    *   **Purpose:** Recreates dev site from production or from an existing backup.
    *   **Options:** 
        *   `--date` - Restore from an existing backup file instead of creating a new dump from production. When used, the script will list available backup dates and prompt for selection.

*   **`requirements.txt`**
    *   **Type:** Data file (Python dependencies)
    *   **Purpose:** Lists Python package dependencies required by Python scripts in this directory (e.g., `urls.py`).
    *   **Notes:** Used with `pip install -r requirements.txt`.

*   **`setup.py`**
    *   **Type:** Python packaging script (`.py`)
    *   **Purpose:** Standard Python project setup script, likely used for packaging any Python utilities or scripts in this directory if they were to be distributed or installed as a package.

*   **`update-dns-token.sh`**
    *   **Type:** Shell script (`.sh`)
    *   **Purpose:** Updates Yandex Cloud DNS authentication token for automatic certificate renewal.
    *   **Notes:** Requires API credentials, probably sourced from environment variables or a secure configuration file.

*   **`urls.py`**
    *   **Type:** Python script (`.py`)
    *   **Purpose:** Python utility for checking URLs, finding redirects, broken links, and extracting page titles. Supports updating redirect maps.
    *   **Notes:** May use `requirements.txt` for its dependencies.

