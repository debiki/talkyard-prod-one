Upgrading from Talkyard v0 to v1
================================

Talkyrad v1 is a major new version of Talkyard — a new epoch.
Previous versions have been v0.YYYY.NNN,
newer versions will be v1.YYYY.NNN (e.g. v1.2025.001).

To upgrade, you'll install Talkyrad v1 side-by-side with v0, backup v0,
shut down v0, restore the backup to v1, and start v1.


Why upgrade?
-------------------------

- Talkyard v1 upgrades all components to more recent versions
  (upgrades to PostgreSQL 18, ElasticSearch 9 (or 8), Redis 8, Debian 12 or 13).
  This is good to do, so you'll be using supported versions of the software.

- Improvements to the maintenance scripts, e.g. optionally encrypted backups.

- We'll start using Docker named volumes, instead of bind mounts.

- We'll start using the Linux Filesystem Hierarch Standard, e.g.
  backups in `/var/opt/backups/talkyard/` instead of `/opt/talkyard-backups/`.

- Talkyard v0 will stop getting new features, only bug fixes.


How to upgrade
-------------------------

### Preparations

Upgrade your Operating System to Debian 12 or 13
(Ubuntu 22 or 24 LTS should work too — they're based on Debian 12 and 13).

Upgrade Docker to >= ???. Install Docker Compose v2, if you haven't already:

    apt-get install docker-compose-plugin

(Talkyard v0 uses Docker Compose v1, but Talkyard v1 uses Docker Compose v2.)


### Phase 1: Backup and shut down v0

Make your Talkyard v0 server read-only:

```
cd /opt/talkyard   # this is v0

docker-compose exec rdb psql ...
```

Take a backup, let's name it `beforeV1Upgrade`:

```
./scripts/backup.sh beforeV1Upgrade
```

Now, shut down Talkyrad v0 — but don't delete anything! Just leave it as-is:

```
docker-compose down   # (using Docker-Compose v1)
```

#### Verification

Open a web browser and check that you the Talkyard site is inaccessible.


### Phase 2: Install and configure v1


Install Talkyard v1, as per the installation instructions in ../README.md .

Copy configuration files from your v0 installation to v1 — with one change:

```
# Go to the Talkyard v1 installation dir
cd /opt/talkyard-v1

# Back up default config
mv conf conf.v1.default

# Copy config from v0 to v1:
cp -a /opt/talkyard/conf  ./

# Move play-framework.conf to 'app/' sub dir: (for consistency with other containers)
mkdir conf/app
mv conf/play-framework.conf conf/app/play-framework.conf
```

Edit the config files:

```
... TBD ...
```


#### Verification

Start the new Talkyard v1 site:

```
cd /opt/talkyard-v1
docker compose up -d
```

See if you can access it in a browser. It'll be empty, since you haven't restored the
database yet.


### Phase 3: Data migration

#### Restore database

Restore the database backup into Talkyrad v1: (and replace `...beforeV1Upgrade...sql.g`
with the backup file name.)

```
cd /opt/talkyard-v1/      # note: v1
docker compose up -d rdb  # (this is Docker Compose v2)

# NOTE: Overwrites any existing database (!).
zcat /opt/talkyard-backups/archives/...beforeV1Upgrade...sql.gz \
    | docker exec -i $(docker compose ps -q rdb) psql postgres postgres \
    | tee -a talkyard-maint.log
```

#### Copy uploaded files

Copy uploaded files from v0 (located at `/opt/talkyard/data/uploads`)
into the v1 named volume, using a temporary 'app' container. This container
which automatically mounts the volume, as specified in docker-compose.yml.

```
# In /opt/talkyard-v1:

docker compose run --rm  \
    -v /opt/talkyard/data/uploads:/uploads-v0:ro  \
    app \
        rsync -a  /uploads-v0/public/  /var/talkyard/v1/pub-files/uploads/
```


#### Does it work?

Start Talkyard v1 with your data restored:

```
# In /opt/talkyard-v1:

docker compose up -d
docker compose logs -f
```

Open a web browser and see if you can access your Talkyard site again.


### Phase 4: Last steps

#### Make the site read-write

```
docker compose exec rdb psql ...
```


#### Reconfigure backups

Reconfigure the off-site backup script so it backups `/var/opt/backups/`
(instead of `/opt/talkyard-backups/`) — see the end of ../README.md.

Wait a month or two. All fine? You can delete old v0.


