Upgrading from Talkyard v0 to v1
================================

Talkyrad v1 is a major new version of Talkyard — a new epoch.
Previous versions have been v0.YYYY.NNN,
newer versions will be v1.YYYY.NNN (e.g. v1.2026.001).

To upgrade, you'll install Talkyrad v1 side-by-side with v0, backup v0,
shut down v0, restore the backup to v1, and start v1.


Release notes: https://github.com/debiki/talkyard/releases/tag/tyse-v1.2026.002-5962b8ad5-dev

Of interest now when upgrading:

- v1 uses Docker Compose v2, which you invoke like so: `docker compose`,
  instead of `docker-compose`.

- v1 uses Docker named volumes, instead of bind mounts.

- v1 uses the Linux Filesystem Hierarch Standard, e.g.
  backups in `/var/opt/backups/talkyard/` instead of `/opt/talkyard-backups/`.

- Network segmentation: An internal backend network, and an egress proxy
  (stops Server Side Request Forgery).


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


### Disk space?

Talkyard v1 stores backups in `/var/opt/backups/talkyard` — check if there's
enough free space. (v0 instead stored backups in `/opt/talkyard-backups/`.)


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

<!-- [dupl_docs__restore_install] -->

Install Talkyard v1 in `/opt/talkyard-v1/`, as per the installation instructions
in `../README.md`, including:

- Edit `play-framework.conf` — edit the `play.http.secret.key`, but you can
  leave everything else as-is (e.g. keep hostname `localhost`).
- Pick a new password when configuring Postgres (to rotate passwords).
- Start Talkyard v1 (that is, run `upgrade-if-needed.sh`).
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


### Phase 3: Copy configuration from v0 to v1


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
  (e.g. a dedicaed disc), contact us (https://forum.talkyard.io/).

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

<!-- It's better if they follow the instrs in   ./risk-free-upgrades.md ?
#### Any CDN?

**If** you use a CDN (Content Delivery Network), *and* you're not only upgrading Talkyard,
but also migrating to a new server & IP address:<br/>
In `/opt/talkyard-v1/conf/app/play-framework.conf`,
disable the CDN by commenting out the: `talkyard.cdn.origin=...` line.
The CDN wounldn't work yet: it's still configured to access your old v0 server IP,
you haven't updated any DNS config yet?
-->

#### Web server (Nginx)

Edit `/opt/talkyard-v1/conf/web/sites-enabled/talkyard-servers.conf`
and enable HTTPS, and redirect from HTTP to HTTPS. (See instructions at top of file.)

That's probably all you need to do
— Talkyard will auto generate a HTTPS cert, using LetsEncrypt,
so you shouldn't need to copy any HTTPS certificates.

However, if you've configured a wildcard cert (`*.example.com`), contact the
Talkyard developers.

<!--  They don't need to do anything, so skip this:
Also remove any `server_names_hash_bucket_size 64` config value.
This is now included in a Talkyard built-in Nginx config file instead.
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

Have a look at how your new Docker memory settings differs from the old:

`git diff /opt/talkyard/docker-compose.override.yml /opt/talkyard-v1/docker-compose.override.yml`

The new v1 settings are probably better.

In `docker-compose.yml` (in `/opt/talkyard-v1/`), look especially at the `web` container.

If you use a CDN, copy the CDN_PULL_KEY from the old
`/opt/talkyard/docker-compose.yml` to your new,
`/opt/talkyard-v1/docker-compose.yml`.

If you've configured any Nginx environment varialbes like `ED_NGX_LIMIT_...`,
these have been renamed to `TY_NGX_LIMIT_...`.  (That is, `TY_...`.)

So, rename and copy any `ED_NGX...` and `TY_NGX_...` from the v0 to the v1 config.
<!-- `TY_NGX_LIMIT_REQ_BODY_SIZE` has often been configured. -->

However, skip `TY_NGX_ACCESS_LOG_PATH`, `TY_LOG_TO_STDOUT_STDERR` and
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

See if you can access it in a browser. The site will be empty, since you haven't
restored the database yet.

<!--
- If you're upgrading directly on the same server, you can just access the site
  as usual, from a browser your laptop.

- If you're upgrading in another VM or server (e.g. created from a machine image),
  you can:

  - Edit `/etc/hosts` and point your forum address
    to the IP of the new VM (as mentioned above). Or,

  - Or open an SSH tunnel: `ssh .... -N -L 8080:127.0.0.1:80` but this uses
    port 8080 so the web page would be broken (js and css not found).
-->

### Phase 4: Data migration

#### Restore database

Restore the database backup into Talkyard v1: (replace `...beforeV1Upgrade...sql.g`
with the backup file name.)

```
cd /opt/talkyard-v1/      # note: v1
docker compose down       # avoid error messages when overwriting db
docker compose up -d rdb  # start the database only

# NOTE: Overwrites any existing database (!).
# Restore your last v0 backup into the v1 database:
zcat /opt/talkyard-backups/archives/...beforeV1Upgrade...sql.gz \
    | docker exec -i $(docker compose ps -q rdb) psql postgres postgres \
    | tee -a talkyard-maint.log
```

Afterwards, update the database password
for the Postgres admin user (needed for the backup container)
and for the Talkyard user
— the password needs to match your new password in `secrets/postgres_password.txt`.
Also, grant `create`, needed for database migrations. As follows:

```
# In /opt/talkyard-v1/:

# Copy your new PostgreSQL password, removing any trailing newline.
NEW_PW="$(tr -d '\n\r' < secrets/postgres_password.txt)"

# Update passwords, grant permission.
docker compose exec -T rdb  psql postgres postgres -v new_pw="$NEW_PW"  <<'EOF'
alter user postgres password :'new_pw';
alter user talkyard password :'new_pw';
\c talkyard
grant create on schema public to talkyard;
EOF
```


#### Copy uploaded files

Copy uploaded files from v0 (located at `/opt/talkyard/data/uploads`)
into a Talkyard v1 Docker named volume:

```
# In /opt/talkyard-v1/:

docker compose run --rm --user 1000:1000  \
    -v /opt/talkyard/data/uploads:/uploads-v0:ro  \
    -v pub-files:/pub-files-v1  \
    backup  \
    rsync -rlpt --no-owner --no-group  /uploads-v0/public/  /pub-files-v1/uploads/
```

<!-- [dupl_docs__restore_rsync] -->

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

<!-- [dupl_docs__restore_reindex] -->

```
docker compose up -d search  # start ElasticSearch

# Repeat until you see "acknowledged":true" instead of "Connection refused"
# — it can take a minute for ElasticSearch to start.
docker compose exec search curl -XDELETE 'http://localhost:9200/posts_es9_v1/'
```


#### Clear the cache

Since we started the server briefly, before importing the old databse,
there might be some cruft in the Redis cache. Let's empty the cache:

<!-- [dupl_docs__restore_flush_redis] -->

```
docker compose up -d cache                    # start Redis
docker compose exec cache redis-cli FLUSHDB   # clear cache
```


#### Does it work?

Start Talkyard v1, now with your data restored:

```
# In /opt/talkyard-v1:

docker compose down      # stop everyhting. So restarts & picks up edited settings

docker compose up -d     # start (recreates containers)
docker compose ps        # status Up or Starting?
docker compose logs -f   # look at logs
```

Open a web browser and see if you can access your Talkyard site again.


### Phase 5: Last steps


#### Disable Maintenance Mode

This makes the forum read-write again, so people can post new topics and comments.

```
cd /opt/talkyard-v1  # note: v1
sudo docker compose exec rdb psql talkyard talkyard -c \
      'update system_settings_t set maintenance_until_unix_secs_c = null;'
```

Log in and post a test topic, see if works.


#### Disabled old backup scripts

No need to take any more backups of v0 — it's not in use.

Edit the cron jobs file, and remove all `/opt/talkyard` lines — but not
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


<!-- It's better if they follow the instrs in   ./risk-free-upgrades.md ?
#### Any CDN?

If you use a CDN (Content Delivery Network), *and* you're migrating to a new server,<br/>
now you can update your DNS config and enable the CDN again: `talkyard.cdn.origin`.

<! --
Ignore this, if you don't use a CDN (Content Delivery Network), or if you don't
know what it is.

##### New server

Maybe the CDN will just continue working, unless you need to update some IP addr
in the CDN config. But if you use a DNS hostname, this wouldn't be needed.

##### Same server

The CDN should just continue working.
-->


#### Reconfigure backups

Time to make off-site backups work with the new Talkyard v1 installation.

##### New server

If you installed v1 on a new server: Follow the steps in ./copy-backups-elsewhere.md.

##### Same server

If you installed v1 on the same server, and have already configured off-site
backups for Talkyard v0, do this:

```
sudo -i  # become root

# Install ACL (Access Control Lists), so we can use getfacl and setfacl.
apt install acl

# Let the backup user, remotebackup, access future backups.
# (In Talkyard v1, backups are otherwise accessible only by root.)
setfacl -R -d -m u:remotebackup:r-X /var/opt/backups/talkyard/v1/archives/

# Let remotebackup access already existing backups.
setfacl -R -m u:remotebackup:r-X /var/opt/backups/talkyard/v1/archives/

su remotebackup  # switch user

ls /var/opt/backups/talkyard/v1/archives/  # no permission error?

# If there's a Permission Denied error: Check if `remotebackup` has access to
# all parent directories:  namei -om /var/opt/backups/talkyard/v1/archives/
# and check the ACL list:  getfacl /var/opt/backups/talkyard/v1/archives/

# Backup the v0 SSH settings:
cp ~/.ssh/authorized_keys  .ssh/authorized_keys.old-ty-v0

# Update the backup directory path.
# Change from:  /opt/talkyard-backups/archives/
#          to:  /var/opt/backups/talkyard/v1/archives/
nano ~/.ssh/authorized_keys

# The Talkyard backups line should now look like:
# .../bin/rrsync -ro /var/opt/backups/talkyard/v1/archives/",no-agent-...

# save

exit  # switch back to root
```

SSH into your off-site backup server, rename the current backup
directory to `talkyard-backups-v0`, then `mkdir talkyard-backups`,
and run the cron job manually — it should "just work":
nothing has changed, from the backup server's point of view.

Make sure the Postgres backups `...-postgres.sql.gz` aren't really small
— then something is amiss, e.g. the wrong password.

<!--
Reconfigure the off-site backup script so it backups `/var/opt/backups/`
(instead of `/opt/talkyard-backups/`) — see the end of ../README.md.

Wait a month or two. All fine? You can delete old v0.
-->

#### Get an email, if backups stop working

If you want, in `./copy-backups-elsewhere.md`, scroll down to the
_Get an email, if backups stop working_
section at the end, and follow the instructions.

