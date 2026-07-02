
How to restore a Talkyard backup
=============================================

(TODO: Add instructions for decrypting encrypted backups.)

These instructions restore a Talkyard v1 backup onto a new server.
(But to upgrade from v0 to v1, see ./upgrade-v0-to-v1.md.)


### Install Talkyard on the new server

<!-- [dupl_docs__restore_install] -->

Install Talkyard on the server where you want to restore the backup.
Follow the instructions in
https://github.com/debiki/talkyard-prod-one/, including:

- Edit `play-framework.conf` — edit the `play.http.secret.key`, but you can
  leave everything else as-is (e.g. keep hostname `localhost`).
- Type a temp password in `secrets/postgres_password.txt`, we'll copy the old later.
- Start Talkyard once (that is, run `upgrade-if-needed.sh`), so we can check that it works.
- Schedule backups (so you won't forget this later).

But stop before step 7 "Open a web browser; go to https://talkyard.your website.com".

Now, check if the new server works:

```
# Everything started?
# This should reply:  "pong pong, from Play and Postgres. Found system user: true"
#
curl http://localhost/-/ping-db

# Check the logs for errors. There should be exactly one error log message,
# namely this:  "I won't send emails, because:  No talkyard.smtp.host configured"
#
docker compose logs | grep ERR | grep -v 'ADD CONSTRAINT .* DEFERRABLE'
```

If it works, stop everything:

```
docker compose down
```

Next, we'll copy config files from the backup:


### Restore config files

On the new server, as root, run the commands below:

Replace `BACKUP_ARCHIVES_DIR` and `DB_BACKUP_FILE` etc below, with
the actual paths and filenames.

```
# As root:
cd /opt/talkyard-v1

echo "$(date -I): Restoring backup ..." >> talkyard-maint.log


# Restore config files
# ------------------------------

mkdir def-conf
mv .env docker-compose.* conf secrets def-conf/

mkdir old-conf
tar xf /BACKUP_ARCHIVES_DIR/CONFIG_BACKUP_FILE.tar.gz -C old-conf

mv old-conf/.env                        ./
mv old-conf/docker-compose.*            ./
mv old-conf/conf                        ./conf
mv old-conf/secrets                     ./secrets


# Restore the database, PostgreSQL
# ------------------------------

# (We're root, so we can connect as the Postgres superuser, postgres,
# even though passwords do not yet match.)

# First, start PostgreSQL.
docker compose up -d rdb

# NOTICE: Overwrites any existing database (!).
zcat /BACKUP_ARCHIVES_DIR/DB_BACKUP_FILE.sql.gz \
    | docker exec -i $(docker compose ps -q rdb) psql postgres postgres \
    | tee -a talkyard-maint.log


# Restore Redis?
# ------------------------------

# Not totally needed, it's a cache. (Maybe write something about Redis later.)
# 
# (HTTPS certs are stored in Redis, but they'll be regenerated.)


# Restore uploaded files
# ------------------------------

docker compose run --rm --user 1000:1000  \
    -v /BACKUP_ARCHIVES_DIR/UPLOADS_BACKUP_DIR.d:/backup:ro  \
    -v pub-files:/pub-files  \
    backup  \
    rsync -rlpt --no-owner --no-group  /backup/  /pub-files/uploads/
```

<!-- [dupl_docs__restore_rsync] -->

(Details: 1) We're user 1000 in the _app_ container, so, copying as user 1000 here
too. 2) Using `rsync -rlpt` not `rsync -a` since we don't want to copy file ownership
— we want the files to become owned by user 1000 instead `[appuser_id_1000]`.
3) `pub-files` is mounted in `docker-compose.yml`, but read-only. Therefore we
mount it read-write here. 4) Using the _backup_ image — it has rsync installed.)

#### Memory

Next, configure memory: Run `free -m` to find out how many megabytes
of memory your machine has. Look at docker-compose.override.yml to see how
much memory Talkyard has been configured to use — and optionally,
replace that file with another more suitable one from `./mem/*`,
e.g.: `cp mem/4g.yml docker-compose.override.yml`.
Note: This overwrites any other config in the old override file.


### Reindex everything

Elasticsearch is not backed up — not really needed, since reindexing
everything is pretty quick. Do this:

<!-- [dupl_docs__restore_reindex] -->

```
docker compose up -d search  # start ElasticSearch

# Repeat until you see "acknowledged":true" instead of "Connection refused"
# — it can take a minute for ElasticSearch to start.
docker compose exec search curl -XDELETE 'http://localhost:9200/posts_es9_v1/'
```

Now, Talkyard will reindex everything, once started.


### Clear the cache

Since we started the server briefly, before restoring the database backup,
there might be some cruft in the Redis cache. Let's empty the cache:

<!-- [dupl_docs__restore_flush_redis] -->

```
docker compose up -d cache                    # start Redis
docker compose exec cache redis-cli FLUSHDB   # clear cache
```


### Start Talkyard

Now, time to start everything:

```
docker compose up -d
docker compose logs -f --tail 999
```


### DNS? CDN?

If you restored to a different server, update your DNS records if necessary.

If you use a CDN (check `talkyard.cdn.origin=...` in `conf/app/play-framework.conf`
if you're unsure),
it should just keep working, if you update your DNS so your forum hostname
points to the restored server.
(The CDN secret key would have been restored together with the config files above.)


### Does it work?

Open a web browser and see if you can access your Talkyard site again.
Do pages load correctly? Are uploaded files (such as images) there?


### Off-site backups

If you restored to a new server: Follow the steps in ./copy-backups-elsewhere.md
to make off-site backups work again.

