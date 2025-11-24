

Talkyrad v1 is a major-major new version of Talkyard, that is, a new epoch.
Previous versions have been v0.YYYY.NNN (e.g. v0.2025.001), newer versions will
be v1.YYYY.NNN (e.g. v1.2025.001).

To upgrade, you'll install Talkyrad v1 side-by-side with v0, take a backup of v0,
shut down v0 (but don't uninstall it). Then, import the backup to v1 and start v1.
— Details further down below.

Why upgrade?
-------------------------

Talkyard v1.2025.001 doesn't add any new features — it only upgrades all components
to more recent versions (upgrades to PostgreSQL 18, ElasticSearch 9, Redis 8,
Debian 12 or 13).
This is good to do, so you'll be using supported versions of the software.

Talkyard >= v1.2025.002 will add new features and bug fixes though (only the first
version, 001, is a upgrade-all-components but-no-new-features release).

Talkyard v0 will stop getting new features, only bug fixes.

There's also changes to the installation and maintenance scripts,
e.g. optionally encrypted backups.
And we'll start using Docker named volumes by default, instead of bind mounts.


How to upgrade
-------------------------

### Preparations

Upgrade your Operating System to Debian 12 or 13
(Ubuntu 22 or 24 LTS should work too — they're based on Debian 12 and 13).

Upgrade Docker to >= ???. Install the Compose plugin, if you haven't already:



### Backup and shut down

Make your Talkyard v0 server read-only:

```
cd /opt/talkyard
... TBD
```

Backup your existing Talkyard installation, let's name the backup 'beforeV1Upgrade':

```
cd /opt/talkyard
./scripts/backup.sh beforeV1Upgrade
```

Then, shut down Talkyrad v0 — but don't delete anything! Just leave it as-is:
(Note: This uses Docker-Compose v1.)

```
# in /opt/talkyard:
docker-compose down   # (using Docker-Compose v1)
```


### Install v1. Copy config


Install Talkyard v1 (the new epoch), as per the installation instructions in ../README.md .

Copy configuration files from your v0 installation to v1 — with a small change:

```
# Copy config from v0 to v1:
cp -a /opt/talkyard/conf  /opt/talkyard-v1/conf

# Move play-framework.conf to a new 'app/' sub dir: (for consistency with other containers)
mkdir /opt/talkyard/conf/app
mv /opt/talkyard/conf/play-framework.conf /opt/talkyard/conf/app/play-framework.conf
```

Edit the config files:

```
... some conf vals renamed ...

SILHOUETTE?
```


But don't copy  `/opt/talkyard/data/` (just leave it as-is).
In Talkyard v1, we use Docker named volumes only, instead — no `data/` directory needed.


### Restore database

Restore the database backup into Talkyrad v1: (and replace `...  beforeV1Upgrade ...sql.g`
with the backup file name.)

```
cd /opt/talkyard-v1/
docker compose up -d rdb   # (this is Docker Compose v2)

# NOTE: Overwrites any existing database (!).
zcat /opt/talkyard-backups/archives/...  beforeV1Upgrade ...sql.gz \
    | docker exec -i $(docker compose ps -q rdb) psql postgres postgres \
    | tee -a talkyard-maint.log
```


### Copy uploaded files


<!--
docker compose run --rm  \
    -v /opt/talkyard-backups/uploads:/old-uploads:ro  \
    -v talkyard-v1-pub-files:/pub-files  \
    busybox

# Source - https://stackoverflow.com/a
# Posted by Aleksey Rembish, modified by community. See post 'Timeline' for change history
# Retrieved 2025-11-24, License - CC BY-SA 3.0

docker run --rm \ 
  --volume [DOCKER_COMPOSE_PREFIX]_[VOLUME_NAME]:/[TEMPORARY_DIRECTORY_TO_STORE_VOLUME_DATA] \
  --volume $(pwd):/[TEMPORARY_DIRECTORY_TO_STORE_BACKUP_FILE] \
  ubuntu \
  tar cvf /[TEMPORARY_DIRECTORY_TO_STORE_BACKUP_FILE]/[BACKUP_FILENAME].tar /[TEMPORARY_DIRECTORY_TO_STORE_VOLUME_DATA]

-->


### Configure backups

Reconfigure the off-site backup script so it backups `/var/opt/backups/`
(instead of `/opt/talkyard-backups/`).

Wait a month or two. All fine? You can delete old v0.


