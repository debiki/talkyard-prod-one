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

log_message "Backing up, tag: '$1'"

when="`date '+%FT%H%MZ' --utc`"
backup_archives_dir=/opt/talkyard-backup/archives
backup_uploads_sync_dir=/opt/talkyard-backup/uploads-sync
uploads_dir=/opt/talkyard/data/uploads

mkdir -p $backup_archives_dir
mkdir -p $backup_uploads_sync_dir

random_value=$( cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 20 )
log_message "Generated random test-that-backups-work value: '$random_value'"


# Backup Postgres
# -------------------

# Insert a backup test timestamp, so we somewhere else can check that the contents of the backup is recent.
/usr/local/bin/docker-compose exec rdb psql talkyard talkyard -c \
    "insert into backup_test_log3 (logged_at, logged_by, backup_of_what, random_value) values (now_utc(), '`hostname`', 'rdb', '$random_value');"

postgres_backup_path=$backup_archives_dir/`hostname`-$when-$1-postgres.sql.gz
log_message "Backing up Postgres..."
# (cron's path apparently doesn't include /sur/local/bin/)
# Specify -T so Docker won't create a tty, because that results in a Docker Compose
# stack trace and error exit code.
# Specify --clean to include commands to drop databases, roles, tablespaces before recreating them.
/usr/local/bin/docker-compose exec -T rdb pg_dumpall --username=postgres --clean --if-exists | gzip > $postgres_backup_path
log_message "Backed up Postgres to: $postgres_backup_path"


# Backup Redis
# -------------------
# """Redis is very data backup friendly since you can copy RDB files while the
# database is running: the RDB is never modified once produced, and while it gets
# produced it uses a temporary name and is renamed into its final destination
# atomically using rename(2) only when the new snapshot is complete."""
# See http://redis.io/topics/persistence

if [ -f data/cache/dump.rdb ]; then
  redis_backup_path=$backup_archives_dir/`hostname`-$when-$1-redis.rdb.gz
  log_message "Backing up Redis..."
  gzip --to-stdout data/cache/dump.rdb > $redis_backup_path
  log_message "Backed up Redis to: $redis_backup_path"
else
  log_message "No Redis dump.rdb to backup."
fi


# Backup ElasticSearch?
# -------------------
# ... later ... Not important. Can just rebuild the search index.


# Backup uploads
# -------------------

# Insert a backup test timestamp, so we can check that the backup archive contents is fresh.
# Do this as files with the timestamp in the file name — because then they can be checked for
# by just listing (but not extracting) the contents of the archive.
# This creates a file like:  2017-04-21T0425--server-hostname--NxWsTsQvVnp2y0YvN8sb
backup_test_dir=$uploads_dir/backup-test
mkdir -p $backup_test_dir
find $backup_test_dir -type f -mtime +31 -delete
touch $backup_test_dir/$(date --utc +%FT%H%M)--$(hostname)--$random_value

# Don't want to archive all uploads every day — then we might soon run out of disk (if there're
# many uploads — they can be huge). Instead, create archives every month only, which contains
# all files uploaded in between. So:
# Every new month, start growing a new uploads-backup-archive
# with a name matching  -uploads-since-<date>.tar.gz where <date> is the start of the month.
# Delete all old backups with the same "since-<date>" because the most recent one contains
# all files in those archives anyway.

start_date=`date +%Y-%m-01`
uploads_start_date_tgz="uploads-start-$start_date.tar.gz"
uploads_backup_filename=`hostname`-$when-$1-$uploads_start_date_tgz
other_archives_same_start_date=$( find $backup_archives_dir -type f -name '*-uploads-*' | egrep "`hostname`.+$uploads_start_date_tgz" )

/usr/local/bin/docker-compose exec rdb psql talkyard talkyard -c \
    "insert into backup_test_log3 (logged_at, logged_by, backup_of_what, random_value) values (now_utc(), '`hostname`', 'uploads', '$random_value');"

do_backup="tar -czf $backup_archives_dir/$uploads_backup_filename -C $backup_uploads_sync_dir ./"

if [ -z "$other_archives_same_start_date" ]; then
  # Then this is a new month and we're starting a new archive series. Ok to 'rsync --delete'.
  rsync -a --delete $uploads_dir/ $backup_uploads_sync_dir/
  echo "Synced uploads to: $backup_uploads_sync_dir/, and deleted uploads that have been deleted"
  $do_backup
  log_message "Backed up uploads to: $backup_archives_dir/$uploads_backup_filename"
else
  # Don't --delete, because the archive shall include all stuff uploaded during the month.
  rsync -a $uploads_dir/ $backup_uploads_sync_dir/
  echo "Synced uploads to: $backup_uploads_sync_dir/"
  $do_backup
  # Don't need to keep older backups from the same month — they're included in the backup archive we just created.
  echo "$other_archives_same_start_date" | xargs rm
  log_message "Backed up uploads to: $backup_archives_dir/$uploads_backup_filename"
  log_message "Deleted these old backups; their contents is included in the backup we just did: $other_archives_same_start_date"
fi


# vim: et ts=2 sw=2 tw=0 fo=r
