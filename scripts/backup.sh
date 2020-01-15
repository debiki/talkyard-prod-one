#!/bin/bash

function log_message {
  echo "`date --iso-8601=seconds --utc` backup-script: $1"
}

if [ $# -ne 1 ]; then
  echo "Usage: $0 dump-tag"
  echo "E.g.: $0 weekly"
  echo "or: $0 daily"
  echo "or: $0 v0.12.34-123def"
  exit 1
fi

when="`date '+%FT%H%MZ' --utc`"

log_message "Backing up,  when: '$when',  tag: '$1'"

# See the comment mentioning gzip and "soft lockup" below.
so_nice="nice -n19"

backup_archives_dir=/opt/talkyard-backups/archives
backup_config_temp_dir=/opt/talkyard-backups/config-temp
uploads_dir=/opt/talkyard/data/uploads

mkdir -p $backup_archives_dir

random_value=$( cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 20 )
log_message "Generated random test-that-backups-work value: '$random_value'"


# Backup Postgres
# -------------------

# Insert a backup test timestamp, so we somewhere else can check that the contents of the backup is recent.
/usr/local/bin/docker-compose exec rdb psql talkyard talkyard -c \
    "insert into backup_test_log3 (logged_at, logged_by, backup_of_what, random_value) values (now_utc(), '`hostname`', 'rdb', '$random_value');"

postgres_backup_path=$backup_archives_dir/`hostname`-$when-$1-postgres.sql
postgres_backup_path_gz=$postgres_backup_path.gz
log_message "Backing up Postgres to: $postgres_backup_path_gz ..."

# Don't pipe to gzip — that can spike the CPU to 100%, making the kernel panic.
# It then logs:
#
#    watchdog: BUG: soft lockup - CPU#0 stuck for 22s!
#    Kernel panic - not syncing: softlockup: hung tasks
#    ... thread stacks ...
#    ...
#    Rebooting in 10 seconds..
#
# And then this script continues, until the server reboots 10 seconds later.
#
# (This happened with a Google Compute Engine VM, after some Ubuntu Server
# software upgrade 2020-01-09?. Machine type n1-standard-1: 1 vCPU,
# 3.75 GB memory.)
#
# Instead, run gzip as a separate step — then the CPU load in the above case
# (the GCE VM) stays okay low — compared to 100% + panic crash.
#
# Specify -T so Docker won't create a tty, because that results in a Docker Compose
# stack trace and error exit code.
#
# Specify --clean to include commands to drop databases, roles, tablespaces
# before recreating them.
#
# (cron's path apparently doesn't include /sur/local/bin/)
#
/usr/local/bin/docker-compose exec -T rdb pg_dumpall --username=postgres --clean --if-exists > $postgres_backup_path
$so_nice gzip $postgres_backup_path
log_message "Done backing up Postgres."

# If you need to backup really manually:
# /usr/local/bin/docker-compose exec -T rdb pg_dumpall --username=postgres --clean --if-exists \
#   | nice -n19 gzip \
#   > "/opt/talkyard-backups/archives/$(hostname)-$(date '+%FT%H%MZ' --utc)-cmdline-postgres.sql.gz"



# Backup config
# -------------------

config_backup_path="$backup_archives_dir/`hostname`-$when-$1-config.tar.gz"

log_message "Backing up config to: $config_backup_path ..."

rm -fr $backup_config_temp_dir
mkdir -p $backup_config_temp_dir/data

cp -a /opt/talkyard/.env $backup_config_temp_dir/
cp -a /opt/talkyard/docker-compose.* $backup_config_temp_dir/
cp -a /opt/talkyard/talkyard-maint.log $backup_config_temp_dir/
cp -a /opt/talkyard/conf $backup_config_temp_dir/
cp -a /opt/talkyard/data/certbot $backup_config_temp_dir/data/
cp -a /opt/talkyard/data/sites-enabled-auto-gen $backup_config_temp_dir/data/

$so_nice tar -czf $config_backup_path -C $backup_config_temp_dir ./

log_message "Done backing up config."


# Backup Redis
# -------------------
# """Redis is very data backup friendly since you can copy RDB files while the
# database is running: the RDB is never modified once produced, and while it gets
# produced it uses a temporary name and is renamed into its final destination
# atomically using rename(2) only when the new snapshot is complete."""
# See http://redis.io/topics/persistence

redis_backup_path=$backup_archives_dir/`hostname`-$when-$1-redis.rdb.gz

if [ -f data/cache/dump.rdb ]; then
  log_message "Backing up Redis to: $redis_backup_path ..."
  $so_nice gzip --to-stdout data/cache/dump.rdb > $redis_backup_path
  log_message "Done backing up Redis."
else
  log_message "No Redis dump.rdb to backup."
fi



# Backup ElasticSearch?
# -------------------
# ... later ... Not important. Can just rebuild the search index.



# Backup uploads
# -------------------

uploads_backup_d="$(hostname)-uploads-up-to-incl-$(date +%Y-%m).d"

log_message "Backing up uploads to: $backup_archives_dir/$uploads_backup_d ..."

# Insert a backup test timestamp, so we can check that the backup archive contents is fresh.
# Do this as files with the timestamp in the file name — because then they can be checked for
# by just listing (but not extracting) the contents of the archive.
# This creates a file like:  2017-04-21T0425--server-hostname--NxWsTsQvVnp2y0YvN8sb
backup_test_dir="$uploads_dir/backup-test"
mkdir -p $backup_test_dir
find $backup_test_dir -type f -mtime +31 -delete
touch $backup_test_dir/$(date --utc +%FT%H%M)--$(hostname)--$random_value

# Don't archive all uploads every day — then we might soon run out of disk
# (if there're many uploads — they can be huge). Instead, every new month,
# start growing a new uploads backup archive directory with a name matching:
#     -uploads-up-to-incl-<yyyy-mm>.d
# e.g.:
#     -uploads-up-to-incl-2020-01.d
# It'll include all files uploaded previous months that haven't been deleted,
# plus all files from the curent month — also if they get deleted later this
# same month (Jan 2020 in the example above).
# (But such deleted files won't appear in the *next* months' archives.)

$so_nice  /usr/bin/rsync -a  $uploads_dir/  $backup_archives_dir/$uploads_backup_d/

# Bump the mtime, so scripts/delete-old-backups.sh won't delete it too soon.
# (Otherwise rsync will have preserved the creation date of the uploads dir,
# which might be years ago.)
touch $backup_archives_dir/$uploads_backup_d

log_message "Done backing up uploads."

# Keep track of what we've backed up:
/usr/local/bin/docker-compose exec rdb psql talkyard talkyard -c \
    "insert into backup_test_log3 (logged_at, logged_by, backup_of_what, random_value) values (now_utc(), '`hostname`', 'uploads', '$random_value');"



# Help file about restoring backups
# -------------------

# Where's a better place to document how to restore backups, than in the
# backup directory itself? Because it should get rsynced to an off-site
# extra backup server — and then, when someone logs in at that other off-site
# server to restore the backups, hen will find the instructions on how to
# actually do that.

cp docs/how-restore-backup.md $backup_archives_dir/HOW-RESTORE-BACKUPS.md

# Touch the docs file so it'll be the first thing one sees, with 'ls -halt'.
touch $backup_archives_dir/HOW-RESTORE-BACKUPS.md



log_message "Done backing up."
echo



# You can test run this script via crontab. In Bash, type:
#
#     date -s '2020-02-01 02:09:57' ; tail -f talkyard-maint.log
#
# (The script runs 02:10 by default.)
#
# Also see:  scripts/tests/test-generate-backups.sh
#


# vim: et ts=2 sw=2 tw=0 fo=r
