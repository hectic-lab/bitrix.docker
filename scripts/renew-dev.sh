#!/usr/bin/env sh
set -e -u

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run with sudo, 'sudo $0'"
  exit
fi

# This script recreates dev site from current prod one with deleting old dev in the process

# Parse command line arguments
USE_EXISTING_BACKUP=0
if [ $# -eq 1 ] && [ "$1" = "--date" ]; then
  USE_EXISTING_BACKUP=1
fi

# Domain names
DOMAIN=favor-group.ru
DEV_SUBDOMAIN=dev
DEV_DOMAIN="${DEV_SUBDOMAIN}.${DOMAIN}"

# MySQL variables
PROD_DB=$(echo ${DOMAIN} | tr '.' '_' | tr '-' '_')
# use production domain as-is as DB name and username, but replace dots and dashes with underscores
DEV_DB=$(echo ${DEV_DOMAIN} | tr '.' '_' | tr '-' '_')
DEV_USER=$(echo ${DEV_DOMAIN} | tr '.' '_' | tr '-' '_')
DEV_PASSWORD=$(tr -dc 'a-zA-Z0-9' </dev/urandom | fold -w 32 | head -n 1)

# File path variables
PROD_LOCATION="./web/prod"
DEV_LOCATION="./web/${DEV_SUBDOMAIN}"
BACKUP_LOCATION="./backup"

# Sanity checks before the run
[ -d "${PROD_LOCATION}" ] || (echo "${PROD_LOCATION} (prod location) directory is absent" && exit 45)

# If --date is provided, validate backup directory exists and select backup file
if [ ${USE_EXISTING_BACKUP} -eq 1 ]; then
  [ -d "${BACKUP_LOCATION}" ] || (echo "${BACKUP_LOCATION} (backup location) directory is absent" && exit 47)
  
  # List available backup directories
  echo "Available backup dates:"
  ls -1 ${BACKUP_LOCATION}/ | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' | sort -r | head -20
  
  # Ask user to select a date
  printf "Enter the backup date (YYYY-MM-DD): "
  read -r BACKUP_DATE
  
  # Check if directory exists
  if [ ! -d "${BACKUP_LOCATION}/${BACKUP_DATE}" ]; then
    echo "Error: Backup directory ${BACKUP_LOCATION}/${BACKUP_DATE} does not exist"
    exit 1
  fi
  
  # List files in selected directory
  echo "Available backup files for ${BACKUP_DATE}:"
  ls -1 "${BACKUP_LOCATION}/${BACKUP_DATE}/" | grep "mysqldump.sql.gz$" || (echo "No backup files found" && exit 1)
  
  # Ask user to select a file
  printf "Enter the backup filename: "
  read -r BACKUP_FILE
  
  # Full path to backup
  BACKUP_PATH="${BACKUP_LOCATION}/${BACKUP_DATE}/${BACKUP_FILE}"
  
  # Check if file exists
  if [ ! -f "${BACKUP_PATH}" ]; then
    echo "Error: Backup file ${BACKUP_PATH} does not exist"
    exit 1
  fi
  
  echo "Selected backup: ${BACKUP_PATH}"
fi

# read MYSQL_ROOT_PASSWORD
[ -f "./private/environment/mysql.env" ] || (echo "./private/environment/mysql.env file is absent, couldn't read MYSQL_ROOT_PASSWORD variable" && exit 46)
. ./private/environment/mysql.env

echo "Creating dev copy of the production site in $DEV_LOCATION for $DEV_DOMAIN"

# create temp file to store mysql login and password for the time of the script
# location for it should be the directory which is passed inside the container
mysql_config_file=$(
  echo 'mkstemp(template)' |
    m4 -D template="./private/mysql-data/deleteme_XXXXXX"
) || exit

mysql_binary_path="docker exec -u0 mysql /bin"
mysql_config_inside_container="/var/lib/mysql/${mysql_config_file##*/}"

# shellcheck disable=SC2028
echo "[client]\nuser = root\npassword = ${MYSQL_ROOT_PASSWORD}" >${mysql_config_file}

echo "Recreating DB base and user"
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "drop database if exists ${DEV_DB};"
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "drop user if exists '${DEV_USER}'@'localhost';"

# prepare new dev database and user
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "create database ${DEV_DB};"
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "create user '${DEV_USER}'@'localhost' identified by '${DEV_PASSWORD}';"
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "grant all on ${DEV_DB}.* to '${DEV_USER}'@'localhost';"
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "grant system_variables_admin on *.* to '${DEV_USER}'@'localhost';"
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e 'flush privileges;'

# create and load database dump
if [ ${USE_EXISTING_BACKUP} -eq 1 ]; then
  echo "Using existing backup: ${BACKUP_PATH}"
  # Decompress the backup to prod-dump.sql
  zcat "${BACKUP_PATH}" > prod-dump.sql
else
  # --no-tablespaces allows running not from root (not used currently)
  # --single-transaction will start a transaction before running
  # first --no-data run just dumps the schema for all tables,
  # second --ignore-table run ignores data from user sessions as we don't need to transfer it
  echo "Creating mysql dump"
  ${mysql_binary_path}/mysqldump --defaults-extra-file=${mysql_config_inside_container} --single-transaction --no-tablespaces --no-data ${PROD_DB} >prod-dump.sql
  ${mysql_binary_path}/mysqldump --defaults-extra-file=${mysql_config_inside_container} --single-transaction --no-tablespaces --ignore-table=${PROD_DB}.b_user_session ${PROD_DB} >>prod-dump.sql
fi
# shellcheck disable=SC2028
echo "[client]\nuser = ${DEV_USER}\npassword = ${DEV_PASSWORD}" >${mysql_config_file}
echo "Restoring mysql dump for dev"
cat prod-dump.sql | docker exec -u0 -i mysql /bin/mysql --defaults-extra-file=${mysql_config_inside_container} ${DEV_DB}

echo "Changing settings on dev site after DB restore"
# change aspro and main site URL to reflect dev site value
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "update b_iblock_element_property set VALUE = '${DEV_DOMAIN}' where VALUE = '${DOMAIN}';" ${DEV_DB}
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "update b_lang set SERVER_NAME = '${DEV_DOMAIN}' where SERVER_NAME = '${DOMAIN}';" ${DEV_DB}
# change security filter settings to use new domain
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "update b_option set VALUE = '${DEV_DOMAIN}' where VALUE = '${DOMAIN}';" ${DEV_DB}
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "update b_option set VALUE = '${DEV_DOMAIN}' where MODULE_ID = 'security' and NAME = 'restriction_hosts_hosts';" ${DEV_DB}
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "update b_option set VALUE = 'a:1:{s:4:\"host\";s:26:\"https://${DEV_DOMAIN}\";}' where MODULE_ID = 'security' AND name = 'restriction_hosts_action_options';" ${DEV_DB}
# switch CDN from prod to dev instance
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "update b_option set VALUE = 'dev.cdn-favor-group.ru' where MODULE_ID = 'skypark.cdn' and NAME = 'cdn_domains1';" ${DEV_DB}
# mark site as development one
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "update b_option set VALUE = 'Y' where MODULE_ID = 'main' and NAME = 'update_devsrv';" ${DEV_DB}
# disable external access to the site
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "update b_option set VALUE = 'Y' where MODULE_ID = 'main' and NAME = 'site_stopped';" ${DEV_DB}
# give admin access to users #6, #92, #1560, #1561
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "insert into b_user_access (user_id, provider_id, access_code) values ('6', 'group', 'G1'), ('92', 'group', 'G1'), ('1560', 'group', 'G1'), ('1561', 'group', 'G1');" ${DEV_DB}
${mysql_binary_path}/mysql --defaults-extra-file=${mysql_config_inside_container} -e "insert into b_user_group (user_id, group_id, date_active_from, date_active_to) values ('6', '1', NULL, NULL), ('92', '1', NULL, NULL);" ${DEV_DB}

echo "Copying files"
# install -d is the same as mkdir -p, but it allows setting owner user and group for created folder
install -d -o 1000 -g 1000 ${DEV_LOCATION}
# copy files
# --archive preserves file permissions and so on
# --delete deletes files from destination if they are not present in the source
# --no-inc-recursive calculates file size for progress bar at the beginning
# --exclude excludes cache folders from the sync
# / in the end of src location avoid creating additional directory level at destination
rsync --archive --no-inc-recursive --delete --exclude '/bitrix/backup' --exclude '**/cache/' --exclude '**/managed_cache/' --exclude '*.tmp*' --exclude '/upload/delight.webpconverter/' --exclude '/upload/resize_cache/' --info=progress2 ${PROD_LOCATION}/ ${DEV_LOCATION}

echo "Changing DB connection settings"
# change settings in files to reflect dev site DB user
sed -i "s/.*\$DBName.*/\$DBName = '${DEV_DB}';/" ${DEV_LOCATION}/bitrix/php_interface/dbconn.php
sed -i "s/.*\$DBLogin.*/\$DBLogin = '${DEV_USER}';/" ${DEV_LOCATION}/bitrix/php_interface/dbconn.php
sed -i "s/.*\$DBPassword.*/\$DBPassword = '${DEV_PASSWORD}';/" ${DEV_LOCATION}/bitrix/php_interface/dbconn.php
sed -i "s/.*'database' =>.*/'database' => '${DEV_DB}',/" ${DEV_LOCATION}/bitrix/.settings.php
sed -i "s/.*'login' =>.*/'login' => '${DEV_USER}',/" ${DEV_LOCATION}/bitrix/.settings.php
sed -i "s/.*'password' =>.*/'password' => '${DEV_PASSWORD}',/" ${DEV_LOCATION}/bitrix/.settings.php

echo "Cleaning up"

# remove mysql dump
rm -f prod-dump.sql

# clean up tmp files with credentials (even from other runs)
rm -f ./private/mysql-data/deleteme_*

echo "Dev renewal from production is complete, available at https://${DEV_DOMAIN}"

