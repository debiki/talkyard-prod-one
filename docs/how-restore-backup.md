
## How restore a Talkyard backup

If your server suddenly disappears, then, to restore a backup on
another server, you can do as follows.

Install Talkyard on a new server, following the instructions in
https://github.com/debiki/talkyard-prod-one/blob/master/README.md.

Login to the new server, and run the commands below.

Replace `BACKUP_ARCHIVES_DIR` and `DB_BACKUP_FILE` etcetera below, with
the actual path and file names.

```
sudo -i # become root
cd /opt/talkyard

# Stop the 'app' container, so the import won't fail because of
# active database connections.
docker-compose stop app


# Restore the database, PostgreSQL
# ------------------------------

# DANGER: Overwrites any existing database.
zcat /BACKUP_ARCHIVES_DIR/DB_BACKUP_FILE.sql.gz \
    | docker exec -i $(docker-compose ps -q rdb) psql postgres postgres \
    | tee -a talkyard-maint.log


# Restore Redis?
# ------------------------------

# Not needed, it's a cache. (Maybe write something about Redis later.)


# Restore uploaded files
# ------------------------------

rsync -a  /BACKUP_ARCHIVES_DIR/UPLOADS_BACKUP_DIR.d/  /opt/talkyard/data/uploads/


# Configuration and HTTPS certs:
# ------------------------------

mkdir -p default-conf/data
mv conf default-conf/
mv data/certbot default-conf/data/
mv data/sites-enabled-auto-gen default-conf/data/

mkdir old-conf
tar xf /BACKUP_ARCHIVES_DIR/CONFIG_BACKUP_FILE.tar.gz -C old-conf
mv old-conf/conf                        ./conf
mv old-conf/data/certbot                data/certbot
mv old-conf/data/sites-enabled-auto-gen data/sites-enabled-auto-gen

docker-compose start app
```

Think about if you need to 1) update your DNS server with the IP address of your
new Talkyard server. Or maybe 2) change the hostname of the Talkyard server
— you'd then edit Nginx config in `conf/play-framework.conf`,
and `conf/sites-enabled-manual/` or `data/sites-enabled-auto-gen/`, plus
generate a LetsEncrypt cert (todo: document how).
