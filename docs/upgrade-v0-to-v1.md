Upgrading from Talkyard v0 to v1
================================

**NOTICE**: This is a **draft**, not yet finished or tested.

---

Talkyrad v1 is a major new version of Talkyard — a new epoch.
Previous versions have been v0.YYYY.NNN,
newer versions will be v1.YYYY.NNN (e.g. v1.2026.001).

To upgrade, you'll install Talkyrad v1 side-by-side with v0, backup v0,
shut down v0, restore the backup to v1, and start v1.


Why upgrade?
-------------------------

- Talkyard v1 upgrades all components to more recent versions
  (upgrades to PostgreSQL 18, ElasticSearch 9, Redis 8, Debian 12 or 13).
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

Enable the API, at: `/-/admin/settings/features`, if you use the API.
<!-- Because activated `throwForbiddenIf(!enableApi)` test in prod builds --> 


Upgrade your Operating System to Debian 12 or 13
(Ubuntu 22 or 24 LTS should work too — they're based on Debian 12 and 13).

Upgrade Docker Compose to >= v2.14.1, or install it, if you haven't already:
<!-- ty.io: Docker Compose version v2.14.1   as of 260319. Maybe some
older versions work, no time to find out. -->

    docker compose version  # check version
    apt-get install docker-compose-plugin  # install, if missing

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
including:

- Edit `play-framework.conf` — edit the `play.http.secret.key`, but you can
  leave everything else as-is (e.g. keep hostname `localhost`).
- Pick a new password when configuring Postgres (to rotate passwords).
- Start Talkyard (that is, run `upgrade-if-needed.sh`).
- Schedule backups.

But stop before step 7 "Open a web browser; go to https://talkyard.your website.com".

Instead, do this:

```
# Everything started?
# This should reply:  "pong pong, from Play and Postgres. Found system user: true"
#
curl http://localhost/-/ping-db

# Check for any errors. There should be exactly one error log message,
# namely this:  "I won't send emails, because:  No talkyard.smtp.host configured"
#
docker compose logs | grep ERR | grep -v 'ADD CONSTRAINT .* DEFERRABLE'
```

#### Point hostname to any new VM IP

If you're upgrading to v1 in the *same* VM, then skip this.

But if you're doing the upgrade in a separate VM,
e.g. created from a machine image. Then, find the IP of the VM (where you just
installed Talkyard v1), and add it to your laptop's /etc/hosts:

```
11.22.33.44  your-forum.example.com
```

Thereafter, open `http://your-forum.example.com` in a browser (on your laptop).

You should see an error page — this new v1 installation doesn't know about your
old server and hostname:

```
404 Not Found
There is no site with hostname '....' [TyE404HOSTNAME]
```

---

Now we've installed Talkyard v1. Next, we'll import your forum to the v1 server.


### Phase 2: Copy configuration from v0 to v1


<!-- Most people won't do that?
If you're migrating to a new server at the same time, then,
copy the backup to the new server for example using `scp`.
Here you should see the `beforeV1Upgrade` backup files:

```
ls -halt /opt/talkyard-backups/archives/ | head -n22
```
-->

Look at changes you've made in v0, to refresh your mind:

```
cd /opt/talkyard   # old version v0
git status
git log --oneline --graph --all -n22

# Changes you've made to the application server config.
git diff -- conf/play-framework.conf

# Changes in the Nginx confg.
git diff -- conf/sites-enabled-manual/
```

#### App server (Play Framework)

Copy the app server config file to v1: (note: new `app/` sub dir)

```
cp -a  /opt/talkyard/conf/play-framework.conf  /opt/talkyard-v1/conf/app/
```

Edit it — some things have changed in v1:

```
vi /opt/talkyard-v1/conf/app/play-framework.conf
```

- Remove `talkyard.postgresql.password=...`. In v1, we use a secrets file instead.
- If you use a CDN: rename `talkyard.cdnOrigin` to `talkyard.cdn.origin`.
- Remove: `play.application.loader = ...` if specified (no longer needed).
- Rename `silhouette { ... }` to `talkyard.authn { ... }` (for social login).
- Remove `talkyard.uploads.localhostDir`, or, if you have set it to something special
  (e.g. a dedicaed disc), talk with the Talkyard support team in the forum.

<!--
Go to the old Talkyard v0 dir. Look at the changes you've made to the app server config file.

Probably you can ignore the `.env` file — do _not_ copy version numbers, and you've
picked a new database password already (when installing v1).

But do copy changes you've made in `play-framework.conf` to
`conf/app/play-framework.conf` in v1.
-->

<!--

And any Nginx configuration changes in `talkyard-servers.conf` to
`conf/web/sites-enabled/talkyard-servers.conf` in v1.



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

-->


#### Web server (Nginx)

Edit `/opt/talkyard-v1/conf/web/sites-enabled/talkyard-servers.conf`
and enable HTTPS, and redirect from HTTP to HTTPS. (See instructions at top of file.)

That's probably all you need to do
— Talkyard will auto generate a HTTPS cert, using LetsEncrypt,
so you shouldn't need to copy any HTTPS certificates.

However, if you've configured a wildcard cert (`*.example.com`), contact the
Talkyard support people at the forum.

<!--
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


Probably all you need to do, is to edit the new  talkyard-servers.conf
and redirect from http to https:

```
root@hostname:/opt/talkyard-v1/conf/web/sites-enabled# git diff -- . 
diff --git a/conf/web/sites-enabled/talkyard-servers.conf b/conf/web/sites-enabled/talkyard-servers.conf
index 16b03a5..113dd20 100644
--- a/conf/web/sites-enabled/talkyard-servers.conf
+++ b/conf/web/sites-enabled/talkyard-servers.conf
@@ -41,15 +41,15 @@ server {
 
   ## To redirect to HTTPS, comment out these two includes, and comment in
   ## "location / { return 302 ... }" below.
-  include /etc/nginx/server-limits.conf;
-  include /etc/nginx/server-locations.conf;
+  #include /etc/nginx/server-limits.conf;
+  #include /etc/nginx/server-locations.conf;
 
   ## Redirect from HTTP to HTTPS.
   ## Use temp redirects (302) not permanent (301) in case you'll want to allow
   ## http in the future, for some reason.
-  #location / {
-  #  return 302 https://$http_host$request_uri;
-  #}
+  location / {
+    return 302 https://$http_host$request_uri;
+  }
 }
```
-->


##### Database config (PostgreSQL)

Most likely you don't need to do anything — Talkyard v1 has built-in Postgres
settings that should just work.

Still, if you've made any changes to the v0 Postgres config,
maybe you'd like to run a `diff` and see what's changed. Talk with the
Talkyard developers in the forum.

<!-- `/opt/talkyard/conf/rdb/postgresql.conf` ? 
you need to copy the config file to `/opt/talkyard-v1/conf/rdb/postgresql.conf`,
edit it so it'll work with Pg 18, and mount it in docker-compose.yml.
-->


##### Docker

In `docker-compose.override.yml`:

Just have a look at how your new Docker memory settings differs from the old:

`git diff /opt/talkyard/docker-compose.override.yml /opt/talkyard-v1/docker-compose.override.yml`

The new v1 settings are probably better.

In `docker-compose.yml`, look especially at the `web` container.

If you use a CDN, copy the CDN_PULL_KEY from the old
`/opt/talkyard/docker-compose.yml` to your new,
`/opt/talkyard-v1/docker-compose.yml`.

If you've configured any Nginx environment varialbes like `ED_NGX_LIMIT_...`,
these have been renamed to `TY_NGX_LIMIT_...`.  (That is, `TY_...`.)

Rename and copy any `ED_NGX...` and `TY_NGX_...` to the v1 config.
<!-- `TY_NGX_LIMIT_REQ_BODY_SIZE` has often been configured. -->

However, delete `TY_NGX_ACCESS_LOG_PATH`, `TY_LOG_TO_STDOUT_STDERR` and
`TY_NGX_ERROR_LOG_PATH` — no longer in use.
(Instead, we always log to stdout and stderr.)



#### Verification

Start the new Talkyard v1 site:

```
cd /opt/talkyard-v1
docker compose down    # stop, was using the old settings
docker compose up -d   # does it start with the new settings?

docker compose logs | grep ERR | grep -v 'ADD CONSTRAINT .* DEFERRABLE'
```

See if you can access it in a browser. It'll be empty, since you haven't restored the
database yet.

- If you're upgrading directly on the same server, you can just access the site
  as usual, from a browser your laptop.

- If you're upgrading in another VM or server (e.g. created from a machine image),
  you can:

  - Edit `/etc/hosts` and point your forum address
    to the IP of the new VM (as mentioned above). Or,

  - Or open an SSH tunnel: `ssh .... -N -L 8080:127.0.0.1:80` but this uses
    port 8080 so the web page would be broken (js and css not found).

If you've edited your `/etc/hosts` file on your laptop,  `http://localhost` (maybe you're just testing), you can 

### Phase 3: Data migration

#### Restore database

Restore the database backup into Talkyrad v1: (and replace `...beforeV1Upgrade...sql.g`
with the backup file name.)

```
cd /opt/talkyard-v1/      # note: v1
docker compose down       # avoid error messages when overwriting db. (This is Compose v2 btw)
docker compose up -d rdb  # start the database only

# NOTE: Overwrites any existing database (!).
zcat /opt/talkyard-backups/archives/...beforeV1Upgrade...sql.gz \
    | docker exec -i $(docker compose ps -q rdb) psql postgres postgres \
    | tee -a talkyard-maint.log
```

Afterwards, update the Talkyard user's password to match your database password,
and grant `create` (needed for database migrations):

```
# In /opt/talkyard-v1/:

# Copy your new PostgreSQL password.
NEW_PW="$(tr -d '\n\r' < secrets/postgres_password.txt)"

# Update password and grant permission.
docker compose exec -T rdb  psql postgres postgres -v new_pw="$NEW_PW"  <<'EOF'
alter user talkyard password :'new_pw';
\c talkyard
grant create on schema public to talkyard;
EOF
```

(This in effects rotates the password, wich is good.)


#### Copy uploaded files

Copy uploaded files from v0 (located at `/opt/talkyard/data/uploads`)
into a Talkyard v1 named volume:


```
# In /opt/talkyard-v1/:

docker compose run --rm --user 1000:1000  \
    -v /opt/talkyard/data/uploads:/uploads-v0:ro  \
    -v pub-files:/pub-files-v1  \
    backup  \
    rsync -rlpt --no-owner --no-group  /uploads-v0/public/  /pub-files-v1/uploads/
```

(Details: 1) We're user 1000 in the _app_ container, so, copying as user 1000 here
too. 2) Using `rsync -rlpt` not `rsync -a` since we don't want to copy file ownership
— we want the files to become owned by user 1000 instead `[appuser_id_1000]`.
3) `pub-files` is mounted in `docker-compose.yml`, but read-only. Therefore we
mount it read-write here. 4) Using the _backup_ image — it has rsync installed.)


#### Reindex everything

Talkyard v1 uses a different full-text-search engine configuration
(tech details: different ElasticSearch mappings).

We need to reindex all posts. To do that, delete the search engine data,
so Talkyard will notice it's missing, and recreate it — then everything gets
reindexed. (This happens in the background and typically takes some minutes
or hours.)

```
docker compose up -d search

# Repeat until you see "acknowledged":true" instead of "Connection refused"
# — it can take a minute for ElasticSearch to start.
docker compose exec search curl -XDELETE 'http://localhost:9200/posts_es9_v1/'
```


#### Clear the cache

Since we started the server briefly, before importing the old databse,
there might be some cruft in the Redis cache. Let's empty the cache.

```
# In /opt/talkyard-v1:
docker compose up -d cache                    # start Redis
docker compose exec cache redis-cli FLUSHDB   # clear cache
```


#### Does it work?

Start Talkyard v1 with your data restored:

```
# In /opt/talkyard-v1:

docker compose down      # stop everyhting. So restarts & picks up edited settings

docker compose up -d     # start (recreates containers)
docker compose ps        # status Up or Starting?
docker compose logs -f   # look at logs
```

Open a web browser and see if you can access your Talkyard site again.


### Phase 4: Last steps

#### Make the site read-write

Disable Maintenance Mode:

```
cd /opt/talkyard-v1  # note: v1
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


