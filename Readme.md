# Bitrix infrastructure as a code [![Build Status](https://github.com/paskal/bitrix.infra/workflows/build/badge.svg)](https://github.com/paskal/bitrix.infra/actions/workflows/ci-build.yml) [![PHP Build Status](https://github.com/paskal/bitrix.infra/workflows/build-php/badge.svg)](https://github.com/paskal/bitrix.infra/actions/workflows/ci-build-php.yml) [![Pull Status](https://github.com/paskal/bitrix.infra/workflows/pull/badge.svg)](https://github.com/paskal/bitrix.infra/actions/workflows/ci-pull.yml)

This repository contains infrastructure code behind Bitrix-based [site](https://favor-group.ru) of my father's metal decking business operating in multiple cities.

It's a Bitrix website completely enclosed within docker-compose to be as portable and maintainable as possible, and a set of scripts around its maintenance like dev site redeploy or production site backup.

## Is it fast?

You bet! Here is a performance on Yandex.Cloud server with Intel Cascade Lake 8 vCPUs, 16Gb of RAM and 120Gb SSD 4000 read\write IOPS and 60Mb/s bandwidth.

<img width="1100" alt="image" src="https://user-images.githubusercontent.com/712534/172490266-88710b9f-3776-4c5b-9852-590181d1d204.png">

## How to make use of it

You couldn't use it as-is without alterations. However, I tried to make everything as generic as possible to make adoption for another project easy. To use it, read through [docker-compose.yml](docker-compose.yml)
and then read the rest of this Readme.

After you make adjustments to configuration and docker-compose.yml, run it as follows:

```bash
docker-compose up --build -d
```

[bitrixdock](https://github.com/bitrixdock/bitrixdock) (Russian) project was an inspiration for this one and had way better setup instructions. Please start with it if you don't know what to do with many files in that repo.

### File system permissions

All files touched by MySQL use UID/GID 1001, and PHP and Nginx use UID/GID 1000. Running `scripts/fix-rights.sh` script would set the permissions appropriately for all containers to run correctly.

It might be easier to switch everything to User and Group 1000 for consistency later.

### Relevant parts of Bitrix config

Documentation: sessions [1](https://training.bitrix24.com/support/training/course/?COURSE_ID=68&LESSON_ID=24868) [2](https://training.bitrix24.com/support/training/course/?COURSE_ID=68&LESSON_ID=24870) (ru [1](https://dev.1c-bitrix.ru/learning/course/index.php?COURSE_ID=43&LESSON_ID=14026&LESSON_PATH=3913.3435.4816.14028.14026), [2](https://dev.1c-bitrix.ru/learning/course/index.php?COURSE_ID=32&LESSON_ID=9421)), [cache](https://training.bitrix24.com/support/training/course/?COURSE_ID=68&CHAPTER_ID=05962&LESSON_PATH=5936.5959.5962) ([ru](https://dev.1c-bitrix.ru/learning/course/?COURSE_ID=43&LESSON_ID=2795))

<details><summary>bitrix/php_interface/dbconn.php</summary>

```php
define('BX_CRONTAB_SUPPORT', true);

define("BX_USE_MYSQLI", true);
define("DBPersistent", true);
define("DELAY_DB_CONNECT", true);
$DBType = "mysql";
$DBHost = "localhost";
$DBName = "<DBNAME>";
$DBLogin = "<DBUSER>";
$DBPassword = "<DBPASSWORD>";
define('BX_TEMPORARY_FILES_DIRECTORY', '/tmp');

define("BX_CACHE_TYPE", "memcache");
define("BX_CACHE_SID", $_SERVER["DOCUMENT_ROOT"]."#01");
define("BX_MEMCACHE_HOST", "memcached");
define("BX_MEMCACHE_PORT", "11211");
define('BX_SECURITY_SESSION_MEMCACHE_HOST', 'memcached');
define('BX_SECURITY_SESSION_MEMCACHE_PORT', 11211);
```

</details>

<details><summary>bitrix/.settings.php</summary>

```php
  'session' => array (
  'value' =>
  array (
    'mode' => 'separated',
    'lifetime' => 14400,
    'handlers' =>
    array (
      'kernel'  => 'encrypted_cookies',
      'general' =>
      array (
        'type' => 'memcache',
        'host' => 'memcached',
        'port' => '11211',
      ),
    ),
  ),
  'readonly' => true,
  ),
  'connections' =>
  array (
    'value' =>
    array (
      'default' =>
      array (
        'className' => '\\Bitrix\\Main\\DB\\MysqliConnection',
        'host' => 'localhost',
        'database' => '<DBNAME>',
        'login' => '<DBUSER>',
        'password' => '<DBPASSWORD>',
        'options' => 2.0,
      ),
    ),
    'readonly' => true,
  ),
```

</details>

<details><summary>bitrix/.settings_extra.php</summary>

```php
<?php
return array(
  'cache' => array(
    'value' => array(
      'type' => 'memcache',
      'memcache' => array(
        'host' => 'memcached',
        'port' => '11211',
      ),
      'sid' => $_SERVER["DOCUMENT_ROOT"]."#01"
    ),
  ),
);
?>
```

</details>

## What's inside?

### Core

- [Nginx](https://www.nginx.com/) [![Image Size](https://img.shields.io/docker/image-size/paskal/nginx)](https://hub.docker.com/r/paskal/nginx) with [brotli](https://github.com/google/ngx_brotli) proxying requests to php-fpm and serving static assets directly
- [php-fpm](https://www.php.net/manual/en/install.fpm.php) (7 [![Image Size 7](https://img.shields.io/docker/image-size/paskal/bitrix-php/7)](https://hub.docker.com/r/paskal/bitrix-php) 8 [![Image Size 8](https://img.shields.io/docker/image-size/paskal/bitrix-php/8)](https://hub.docker.com/r/paskal/bitrix-php) 8.1 [![Image Size 8.1](https://img.shields.io/docker/image-size/paskal/bitrix-php/8.1)](https://hub.docker.com/r/paskal/bitrix-php) 8.2 [![Image Size 8.2](https://img.shields.io/docker/image-size/paskal/bitrix-php/8.2)](https://hub.docker.com/r/paskal/bitrix-php)) for bitrix with msmtp for mail sending
- [Percona MySQL](https://www.percona.com/software/mysql-database/percona-server) [![Image Size](https://img.shields.io/docker/image-size/percona/percona-server/8.0)](https://hub.docker.com/r/percona/percona-server) because of it's monitoring capabilities
- [memcached](https://memcached.org/) [![Image Size](https://img.shields.io/docker/image-size/_/memcached/1-alpine)](https://hub.docker.com/r/_/memcached) for bitrix cache and user sessions

### Optional

- PHP cron container with same settings as PHP serving web requests
- [adminer](https://www.adminer.org/) [![Image Size](https://img.shields.io/docker/image-size/_/adminer)](https://hub.docker.com/r/_/adminer) as phpmyadmin alternative for work with MySQL
- [pure-ftpd](https://www.pureftpd.org/project/pure-ftpd/) [![Image Size](https://img.shields.io/docker/image-size/stilliard/pure-ftpd)](https://hub.docker.com/r/stilliard/pure-ftpd) for ftp access
- [DNSroboCert](https://github.com/adferrand/dnsrobocert) [![Image Size](https://img.shields.io/docker/image-size/adferrand/dnsrobocert)](https://hub.docker.com/r/adferrand/dnsrobocert) for Let's Encrypt HTTPS certificate generation
- [zabbix-agent2](https://www.zabbix.com/zabbix_agent) [![Image Size](https://img.shields.io/docker/image-size/paskal/zabbix-agent2)](https://hub.docker.com/r/paskal/zabbix-agent2) for monitoring

## File structure

### /config

- `cron/php-cron.cron` is a list of cron tasks to run in php-cron container, only `cron_events.php` is required for Bitrix and others are specific to this site,
  [must](https://manpages.ubuntu.com/manpages/jammy/man8/cron.8.html) be owned by root:root and have access rights 0644 - fixable by running `scripts/fix-rights.sh`

- `cron/host.cron` is a list of cron tasks to run on the host machine

- `mysql/my.cnf` is a MySQL configuration, applied on top of package-provided my.cnf

- `nginx` directory contains the build Dockerfile, as well as following (HTTPS) configuration:
    - bitrix proxy, separate for dev and prod
    - adminer proxy
    - HTTP to HTTPS redirects
    - stub status page listening on localhost for Zabbix monitoring

- `php-fpm` directory contains the build Dockerfile and php configuration, applied on top of package-provided one

### /logs

`mysql`, `nginx`, `php` logs. cron and msmtp logs will be written to the `php` directory.

### /scripts

Maintenance and utility scripts for the infrastructure.

#### Site Management

- `renew-dev.sh` - Recreates dev site from production or from an existing backup. Can be run with `--date` flag to restore from a specific backup date instead of creating a fresh dump from production.
- `disaster-recovery.sh` - Automates disaster recovery process by setting up a fresh Ubuntu server with Docker, restoring files from S3 backup, and recovering MySQL database.

#### Backup and Restore

- `file-backup.sh` - Performs incremental file backups to S3 using duplicity. Excludes cache, logs, and development directories. Full backup every 60 days.
- `mysql-dump.sh` - Creates compressed MySQL dump and uploads to S3. Excludes user sessions table to reduce backup size.
- `compare-backups.sh` - Interactive tool to compare two backups from S3, showing differences between selected dates.

#### Maintenance and Optimization

- `fix-rights.sh` - Sets proper file ownership for containers (UID/GID 1000 for PHP/Nginx, 1001 for MySQL). Must be run after file operations.
- `optimise-images.sh` - Optimizes PNG, JPEG, WebP, and GIF images using various tools. Marks processed files to avoid reprocessing.
- `find-image-type-mismatch.sh` - Detects images where file extension doesn't match actual MIME type.
- `alter-robots-txt.sh` - Updates robots.txt files for regional subdomains, blocking specific sections based on region.

#### Monitoring and Analysis

- `check-404.sh` - Analyzes nginx logs to find 404 errors from search engine bots for redirect troubleshooting.
- `urls.py` - Python utility for checking URLs, finding redirects, broken links, and extracting page titles. Supports updating redirect maps.

#### System Configuration

- `update-dns-token.sh` - Updates Yandex Cloud DNS authentication token for automatic certificate renewal.

### /web

Site files in directories `web/prod` and `web/dev`.

### /private

- `private/environment` is a directory with environment files for docker-compose

    - `private/environment/mysql.env` should contain the [following variables](https://hub.docker.com/r/percona/percona-server):

      ```bash
      MYSQL_ROOT_PASSWORD=mysql_root_password
      MYSQL_USER=bitrix_user
      MYSQL_PASSWORD=bitrix_mysql_password
      ```

    - `private/environment/ftp.env` should contain the [following variables](https://hub.docker.com/r/stilliard/pure-ftpd):

      ```bash
      FTP_USER_NAME=ftp_username
      FTP_USER_PASS=ftp_password
      ```

    - `private/environment/dnsrobocert.env` should contain Yandex Cloud DNS API key for [adferrand/dnsrobocert](https://hub.docker.com/r/adferrand/dnsrobocert):

      ```
      # Run `yc components update` once to get the key, and `update-dns-token.sh` script will renew it automatically afterwards
      AUTH_KEY=insert_key_there
      DNS_ZONE_ID=insert_zone_id_there
      ```

  - `private/environment/zabbix.env` should contain the [following variables](https://hub.docker.com/r/zabbix/zabbix-agent2):

    ```bash
    ZBX_HOSTNAME=myhostname
    ZBX_SERVER_HOST=zabbix.example.com
    ```

    MySQL setup if you want to use Zabbix for monitoring of the database:
    ```sql
    drop user if exists 'zbx_monitor'@'localhost';
    create user if not exists `zbx_monitor`@`localhost` identified by 'generate_random_password_here';
    grant process, replication client, show databases, show view on *.* to `zbx_monitor`@`localhost`;
    ```

- `private/letsencrypt` directory will be filled with certificates after certbot run (see instruction below)

- `private/mysql-data` directory will be filled with database data automatically after the start of mysql container

- `private/mysqld` directory will contain MySQL unix socket for connections without network

- `private/msmtprc` is a file with [msmtp configuration](https://wiki.archlinux.org/index.php/Msmtp)

## Routine operations

<details>
<summary>Disaster recovery</summary>

To start the recovery you should have a machine with the latest Ubuntu with static external IP with DDoS protection attached to it, created [in the Yandex.Cloud](https://console.cloud.yandex.ru/folders/b1gm2f812hg4h5s5jsgn/compute). It should be created with 100Gb of disk space, 12Gb of RAM and 8 cores.

SSH to the machine you want to set up as a new server and then execute the following, then follow the instructions of the script:

```shell
# that is preparation for backup restoration
sudo mkdir -p /web
sudo chown $USER:$(id -g -n) /web
sudo apt-get update >/dev/null
sudo apt-get -y install git >/dev/null
git clone https://github.com/paskal/bitrix.infra.git /web
cd /web
# backup restoration, it's safe to run it multiple times
sudo ./scripts/disaster-recovery.sh
```

</details>


<details>
<summary>Recovery of files</summary>

Presume you have a machine with problems, and you want to roll back the changes:

```shell
# restore to directory /web/prod2
# -t 2D means restore from the backup made 2 days
# last argument /web/web/prod2 is the directory to restore to, we're not restoring to the original dir
# so that you can rename it first and then rename this directory to prod
sudo HOME="/home/$(logname)" duplicity -t 2D \
    --no-encryption \
    --s3-endpoint-url https://storage.yandexcloud.net \
    --log-file /web/logs/duplicity.log \
    --archive-dir /root/.cache/duplicity \
    --file-to-restore web/prod  "boto3+s3://favor-group-backup/duplicity_web_favor-group" /web/web/prod2
```
</details>

<details>
<summary>Cleaning (mem)cache</summary>

There are two memcached instances in use, one for site cache and another for sessions. Here are the commands to clean them completely:

```shell
# to flush site cache
echo "flush_all" | docker exec -i memcached /usr/bin/nc 127.0.0.1 11211
# to flush all user sessions
echo "flush_all" | docker exec -i memcached-sessions /usr/bin/nc 127.0.0.1 11211
```

[Here](https://github.com/memcached/memcached/wiki/Commands) is the complete list of commands you can send to it.

</details>

<details>
<summary>Manual certificate renewal</summary>

DNS verification of a wildcard certificate is set up automatically through [CloudFlare](https://cloudflare.com/) DNS.

To renew the certificate manually, run the following command and follow the interactive prompt:

```shell
docker-compose run --rm --entrypoint "\
  certbot certonly \
    --email email@example.com \
    -d example.com -d *.example.com \
    --agree-tos \
    --manual \
    --preferred-challenges dns" certbot
```

To add required TXT entries, head to DNS entries page of your provider.

</details>
