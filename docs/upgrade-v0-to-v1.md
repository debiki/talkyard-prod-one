Upgrading from Talkyard v0 to v1
================================

**NOTICE**: This is a **draft**, not yet finished or tested.

---

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

If you use a language other than English: Log in to Takyard as admin,
go to:
and change to that language, if you haven't done this already.
— Talkyard v1 supports better full-text-search in all major languages,
So reindexing in correct lang.

Enable the API if you use the API.
<!-- Because activated `throwForbiddenIf(!enableApi)` test in prod builds --> 


Upgrade your Operating System to Debian 12 or 13
(Ubuntu 22 or 24 LTS should work too — they're based on Debian 12 and 13).

Upgrade Docker to >= ???. Install Docker Compose v2, if you haven't already:
<!-- ty.io: Docker Compose version v2.14.1   as of 260319 -->

    apt-get install docker-compose-plugin

(Talkyard v0 uses Docker Compose v1, but Talkyard v1 uses Docker Compose v2.)


### Phase 1: Backup and shut down v0

Make your Talkyard v0 server read-only:

```
cd /opt/talkyard   # this is v0

sudo docker-compose exec rdb psql talkyard talkyard -c \
      'update system_settings_t set maintenance_until_unix_secs_c = 1;'
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

Open a web browser and check that your Talkyard site is inaccessible.


### Phase 2: Install v1


Install Talkyard v1, as per the installation instructions in ../README.md,
until step 7 "Open a web browser".

But instead of going to `https://talkyard.your website.com`,
open `http://localhost`, and 

Pick a new password when configuring Postgres (to rotate passwords).

#### Verification

Let's see if the v1 installation works. If you're doing the upgrade in a separate VM
(e.g. from a machine image), find the IP of this VM, and add it to your laptop's /etc/hosts:

```
11.22.33.44  your-forum.example.com
```

You should see an error page — this new v1 installation doesn't know about your
old server and hostname:

```
404 Not Found
There is no site with hostname '....' [TyE404HOSTNAME]
```

### Phase 2: Copy configuration from v0 to v1


====


Then, look at the changes you've made to the app server config file,
in version v0:

```
cd /opt/talkyard   # old version, *not* v1
git status
git log --oneline --graph --all -n33
git diff -- conf/play-framework.conf
```

Either copy the whole file to: `/opt/talkyard-v1/conf/app/play-framework.conf` (note: `app/` sub dir).
Or copy only the changes you see in `git diff`.

If you copy the whole file, you need to rename a few config values:




Look at changes you've made to the Nginx config file:

```
git diff -- conf/sites-enabled-manual/
```

Either copy the whole file to: `conf/web/sites-enabled` (note: `web/` sub dir),
or edit the v1 config file and add the changes from v0 (if any).




If you're upgrading to v1 on *the same* server,
Copy configuration files from your v0 installation to v1 — with one change:

```
# Go to the Talkyard v1 installation dir
cd /opt/talkyard-v1

# Back up default config
mv conf conf-v1.orig

# Copy config from v0 to v1:
cp -a /opt/talkyard/conf  ./

# Move play-framework.conf to 'app/' sub dir: (for consistency with other containers)
mkdir conf/app
mv conf/play-framework.conf conf/app/play-framework.conf
```

If you're upgrading to v1 on *another* server,
and you're using a backup located at BACKP_DIR,
then, copy configuration files from your v0 installation to v1 — with one change:

```
cd /opt/talkyard-v1/
mkdir -p conf/app conf/web
cp -a conf-v0/play-framework.conf  conf/app/
cp -a conf-v0/sites-enabled-manual conf/web/sites-enabled 
cp -a conf-v0/maint-msg.html       conf/web/
```

#### Edit config files

Some config values have been renamed, others are no longer in use.

##### Application server

In `conf/app/play-framework.conf`:

Have you set `talkyard.uploads.localhostDir` to something special?
Talk with the Talkyard support team in the forum.

Rename `silhouette` to `talkyard.authn`, that is, from:

```
# Authentication
# ---------------------

silhouette {
```

to:

```
# Authentication
# ---------------------

talkyard.authn {
```

Remove: `play.application.loader = ed.server.EdAppLoader` if specified (no longer needed).
<!-- `play.application.loader = talkyard.server.TyAppLoader` -->

Comment out or remove: `talkyard.postgresql.password`. In v1, we use Docker secrets instead.


##### Nginx

If you've configured any environment varialbes like `ED_NGX_LIMIT_...`,
these have been renamed to `TY_NGX_LIMIT_...`.

Delete `TY_NGX_ACCESS_LOG_PATH` and `TY_NGX_ERROR_LOG_PATH` — no longer in use.
(Instead, logging to stdout and stderr.)

If you've configured HTTPS via LetsEncrypt and Certbot, then, this should work: Edit

```
conf/web/sites-enabled/talkyard-servers.conf
```

and _remove_ your HTTPS config. Talkyard will ask LetsEncrypt to generate new HTTPS certificates
as needed (thanks to `lua-resty-acme`, an Nginx/OpenResty module).
If you've configured a _wildcard_ certificate, contact the Talkyard developers.

Also remove any `server_names_hash_bucket_size 64` config value.
This is now included in a Talkyard built-in Nginx config file instead.

Oops!

```
/etc/nginx/https-cert-self-signed-fallback.pem;  —>  .../generated/...  ?
```

##### PostgreSQL

Copy the PostgreSQL 
Most likely you don't need to do anything. However, if (very unlikely) you've edited
your Talkyrad v0 Postgres config file (at `/opt/talkyard/conf/rdb/postgresql.conf` ?)
and you want to keep the changes,
you need to copy the config file to `/opt/talkyard-v1/conf/rdb/postgresql.conf`,
edit it so it'll work with Pg 18, and mount it in docker-compose.yml.


##### Docker

See if your new Docker memory settings are the same as the old.

`git diff /opt/talkyard/docker-compose.override.yml /opt/talkyard-v1/docker-compose.override.yml`
— copy any settings to v1 as needed, but without the `version: ...` line.
(Run `free -m` to see how much memory you have.)



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

Also, update the Talkyard user's password to match your database password,
and grant 'create' (needed for database migrations):

```
cd /opt/talkyard-v1/      # note: v1
sudo cat secrets/postgres_password.txt   # copy the password

docker compose exec rdb psql postgres postgres

alter user talkyard password 'the-password-from-above';

\c talkyard
grant create on schema public to talkyard;
```

(This in effects rotates the password, wich is good.)


#### Copy uploaded files

Copy uploaded files from v0 (located at `/opt/talkyard/data/uploads`)
into the v1 named volume, using a temporary 'app' container. This container
which automatically mounts the volume, as specified in docker-compose.yml.


```
# In /opt/talkyard-v1:

docker compose run --rm --user 1000:1000  \
    -v /opt/talkyard/data/uploads:/uploads-v0:ro  \
    -v pub-files:/var/talkyard/v1/pub-files  \
    backup \
    rsync -rlpt --no-owner --no-group  \
        /uploads-v0/public/  \
        /var/talkyard/v1/pub-files/uploads/
```

(Details: 1) We're user 1000 in the _app_ container, so, copying as user 1000 here
too. 2) Using `rsync -rlpt` not `rsync -a` since we don't want to copy file ownership
(we want the files to become owned by user 1000 instead `[appuser_id_1000]`).
3) Read-write mounting `pub-files` — it's just read-_only_ mounted in
`docker-compose.yml`. 4) Using the _backup_ image — it has rsync installed.)


#### Reindex everything

Talkyard v1 uses a different full-text-search engine configuration
(tech details: different ElasticSearch mappings).

We need to reindex all posts. To do that, delete the search engine data,
so Talkyard will notice it's missing, and recreate it — then everything gets
reindexed. (This happens in the background and typically takes some minutes
or hours.)

```
docker compose up -d search
docker compose exec search curl -XDELETE 'http://localhost:9200/posts_es9_v1/'
```


#### Clear the cache

Since we started the server briefly, before importing the old databse,
there might be some cruft in the Redis cache. Let's empty the cache.

```
# In /opt/talkyard-v1:
docker compose exec cache redis-cli FLUSHDB
```


#### Does it work?

Start Talkyard v1 with your data restored:

```
# In /opt/talkyard-v1:

docker compose down  # so everything restarts and picks up settings you copied from v0

docker compose up -d
docker compose logs -f
```

Open a web browser and see if you can access your Talkyard site again.


### Phase 4: Last steps

#### Make the site read-write

Disable Maintenance Mode:

```
cd /opt/talkyard
sudo docker compose exec rdb psql talkyard talkyard -c \
      'update system_settings_t set maintenance_until_unix_secs_c = null;'
```

#### Disabled old backup scripts

If you're upgrading to v1 on the same server as you've been running v0, then,
you would want to disable the old backup scripts, so you'll backup only v1,
but not v0.

If so, edit the cron jobs file, and remove all `/opt/talkyard` lines — but not
the new `/opt/talkyard-v1`  lines!

```
crontab -e   # as root
```

You might see sth like:

```
# Edit this file to introduce tasks to be run by cron.
# 
# Each task to run has to be defined through a single line
# indicating with different fields when the task will be run
# and what command to run for the task
# For more information see the manual pages of crontab(5) and cron(8)
# ...
# m h  dom mon dow   command
10 0 * * * cd /opt/talkyard && ./scripts/delete-old-logs.sh >> talkyard-maint.log 2>&1
10 2 * * * cd /opt/talkyard && ./scripts/backup.sh daily >> talkyard-maint.log 2>&1
10 3 * * * cd /opt/talkyard && ./scripts/delete-old-backups.sh >> talkyard-maint.log 2>&1
51 0 * * * cd /opt/talkyard && ./scripts/renew-https-certs.sh >> talkyard-maint.log 2>&1
10 2 * * * cd /opt/talkyard-v1 && ./scripts/backup.sh daily >> talkyard-maint.log 2>&1
10 3 * * * cd /opt/talkyard-v1 && ./scripts/delete-old-backups.sh >> talkyard-maint.log 2>&1
10 4 * * * cd /opt/talkyard-v1 && ./scripts/upgrade-if-needed.sh >> talkyard-maint.log 2>&1
```

Delete the 4 lines starting with `... * * * cd /opt/talkyard && ...`.
(But not the 3 lines starting with `... * * * cd /opt/talkyard-v1 && ...`.)


#### Reconfigure backups

Reconfigure the off-site backup script so it backups `/var/opt/backups/`
(instead of `/opt/talkyard-backups/`) — see the end of ../README.md.

Wait a month or two. All fine? You can delete old v0.


