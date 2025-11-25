

Talkyrad v1 is a major-major new version of Talkyard, that is, a new epoch.
Previous versions have been v0.YYYY.NNN (e.g. v0.2025.001), newer versions will
be v1.YYYY.NNN (e.g. v1.2025.001).

To upgrade, you'll install Talkyrad v1 side-by-side with v0, take a backup of v0,
shut down v0 (but don't uninstall it). Then, import the backup to v1 and start v1.

Why upgrade?
-------------------------

Talkyard v1.2025.001 upgrades all components
to more recent versions (upgrades to PostgreSQL 18, ElasticSearch 9, Redis 8,
Debian 12 or 13).
This is good to do, so you'll be using supported versions of the software.

There's also changes to the installation and maintenance scripts,
e.g. optionally encrypted backups.
And we'll start using Docker named volumes by default, instead of bind mounts.

Talkyard >= v1.2025.002 will add new features and bug fixes (only the first
version, 001, is a upgrade-all-components but-no-new-features release).

Talkyard v0 will stop getting new features, only bug fixes.


How to upgrade
-------------------------

### Preparations

Upgrade your Operating System to Debian 12 or 13
(Ubuntu 22 or 24 LTS should work too — they're based on Debian 12 and 13).

Upgrade Docker to >= ???. Install the Compose plugin, if you haven't already:

    apt-get install -y docker-compose-plugin


### Backup and shut down v0

Make your Talkyard v0 server read-only:

```
cd /opt/talkyard

docker-compose exec rdb psql ...
```

Take a backup, let's name it 'beforeV1Upgrade':

```
cd /opt/talkyard   # this is v0
./scripts/backup.sh beforeV1Upgrade
```

Now, shut down Talkyrad v0 — but don't delete anything! Just leave it as-is:

```
# in /opt/talkyard:
docker-compose down   # (using Docker-Compose v1)
```

Open a web browser and verify that you cannot access the Talkyard site.


### Install v1. Copy config from v0


Install Talkyard v1, as per the installation instructions in ../README.md .

Copy configuration files from your v0 installation to v1 — with a small change:

```
# Copy config from v0 to v1:
cp -a /opt/talkyard/conf  /opt/talkyard-v1/conf

# Move play-framework.conf to a new 'app/' sub dir: (for consistency with other containers)
cd /opt/talkyard-v1/
mkdir conf/app
mv conf/play-framework.conf conf/app/play-framework.conf
```

Edit the config files:

```
... some conf vals renamed ...

SILHOUETTE?
```


(We'll copy uploaded files from `/opt/talkyard/data/` to v1, below.)


### Does it work this far?

Start the new Talkyard v1 site:

```
cd /opt/talkyard-v1
docker compose up -d
```

See if you can access it in a browser. It'll be empty, since you haven't restored the
database yet.


### Restore database

Restore the database backup into Talkyrad v1: (and replace `...  beforeV1Upgrade ...sql.g`
with the backup file name.)

```
cd /opt/talkyard-v1/      # note: v1
docker compose up -d rdb  # (this is Docker Compose v2)

# NOTE: Overwrites any existing database (!).
zcat /opt/talkyard-backups/archives/...  beforeV1Upgrade ...sql.gz \
    | docker exec -i $(docker compose ps -q rdb) psql postgres postgres \
    | tee -a talkyard-maint.log
```


### Copy uploaded files

The old location of uploaded files is: `/opt/talkyard-backups/uploads`
but the new is inside a Docker named volume. We'll start the  'app'
container, which automatically mounts the volume (as specified in docker-compose.yml),
then we'll copy the uploads.

```
# In /opt/talkyard-v1:

docker compose run --rm  \
    -v /opt/talkyard/data/uploads:/uploads:ro  \
    app \
        cp -a /uploads/public /opt/talkyard-v1/pub-files/uploads
```


### Does it work?

Start Talkyard v1 with your data restored:

```
# In /opt/talkyard-v1:

docker compose up -d
docker compose logs -f
```

Open a web browser and see if you can access your Talkyard site again.


### Make the site read-write again

```
docker compose exec rdb psql ...
```


### Configure backups

Reconfigure the off-site backup script so it backups `/var/opt/backups/`
(instead of `/opt/talkyard-backups/`).

Wait a month or two. All fine? You can delete old v0.


