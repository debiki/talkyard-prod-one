
## How restore a Talkyard backup

If your server suddenly disappears, then, to restore a backup on
a new server, you can do as follows.

Start installing Talkyard on that new server, following the instructions in
https://github.com/debiki/talkyard-prod-one/blob/master/README.md
— but stop at step 6: "Edit config values".
Instead, we'll copy config files from the backup:

On new server, as root, run the commands below:

Replace `BACKUP_ARCHIVES_DIR` and `DB_BACKUP_FILE` etcetera below, with
the actual path and file names.

```
sudo -i # become root
cd /opt/talkyard


# Restore config files and HTTPS certs
# ------------------------------

# First, let's "backup" the new conf, in case you'd like to diff old vs default.
mkdir -p default-conf/data
mv conf docker-compose.* .env default-conf/

# Then restore the old config.
mkdir old-conf
mkdir data
tar xf /BACKUP_ARCHIVES_DIR/CONFIG_BACKUP_FILE.tar.gz -C old-conf
mv old-conf/.env                        ./
mv old-conf/docker-compose.*            ./
mv old-conf/conf                        ./conf
mv old-conf/data/certbot                data/certbot
mv old-conf/data/sites-enabled-auto-gen data/sites-enabled-auto-gen


# Restore the database, PostgreSQL
# ------------------------------

# First, start PostgreSQL.
docker-compose up -d rdb

# NOTE: Overwrites any existing database.
zcat /BACKUP_ARCHIVES_DIR/DB_BACKUP_FILE.sql.gz \
    | docker exec -i $(docker-compose ps -q rdb) psql postgres postgres \
    | tee -a talkyard-maint.log


# Restore Redis?
# ------------------------------

# Not needed, it's a cache. (Maybe write something about Redis later.)


# Restore uploaded files
# ------------------------------

rsync -a  /BACKUP_ARCHIVES_DIR/UPLOADS_BACKUP_DIR.d/  /opt/talkyard/data/uploads/
```

And, lastly, start everything:

```
docker-compose up -d
docker-compose logs -f --tail 999
```

Also, think about if you need to 1) update your DNS server with the IP address to
your new Talkyard server. Or maybe 2) change the hostname of the Talkyard server
— you'd then edit Nginx config in `conf/play-framework.conf`,
and `conf/sites-enabled-manual/` or `data/sites-enabled-auto-gen/`, plus
generate a LetsEncrypt cert
(see: `https://github.com/debiki/talkyard-prod-one/blob/master/docs/setup-https.md`).
