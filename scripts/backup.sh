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

when="`date '+%FT%H.%MZ' --utc`"
backup_archives_dir=/opt/ed-backup/archives
backup_uploads_sync_dir=/opt/ed-backup/uploads-sync
uploads_dir=/opt/ed/data/uploads
days_between_uploads_backup_archives=`sed -nr 's/^DAYS_BETWEEN_UPLOADS_BACKUP_ARCHIVES=([0-9]+).*/\1/p' .env`
if [ -z "$days_between_uploads_backup_archives" ]; then
  days_between_uploads_backup_archives=20
fi

mkdir -p $backup_archives_dir
mkdir -p $backup_uploads_sync_dir


# Backup Postgres
# -------------------

postgres_backup_path=$backup_archives_dir/`hostname`-$when-$1-postgres.sql.gz
log_message "Backing up Postgres..."
# (cron's path apparently doesn't include /sur/local/bin/)
# Specify -T so Docker won't create a tty, because that results in a Docker Compose
# stack trace and error exit code.
/usr/local/bin/docker-compose exec -T rdb pg_dumpall --username=postgres --clean --if-exists | gzip > $postgres_backup_path
#./dc exec -T rdb pg_dump --username=ed --clean --if-exists --create ed | gzip > $postgres_backup_path
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

# Don't want to archive all uploads every day — then we might soon run out of disk (if there're
# many uploads — they can be huge). Instead, create archives every $days_between_uploads_backup_archives days
# only, which contains all files uploaded in between.
# So:
# Every $days_between_uploads_backup_archives days, start growing a new uploads-backup-archive
# with a name matching  -uploads-since-NNNN.tar.gz where NNNN is num-days-since-1970 when we
# started this backup series. Delete all old backups with the same "since-NNNN" because
# the most recent one contains all files anyway.

days_since_1970=$(($(date --utc --date "$1" +%s) / 3600 / 24))
since_days=$(( $days_since_1970 % $days_between_uploads_backup_archives * $days_between_uploads_backup_archives ))
uploads_since_days_tgz="-uploads-since-$since_days.tar.gz"
uploads_backup_filename=`hostname`-$when-$1$uploads_since_days_tgz
old_archives_same_since_days=$(find $backup_archives_dir -type f -name '*-uploads-*' | grep "`hostname`.+$uploads_since_days_tgz" | grep -v "$uploads_backup_filename")

do_backup='tar -czf $uploads_backup_filename $backup_uploads_sync_dir'

pushd .
cd $backup_archives_dir
if [ -z "$old_archives_same_since_days" ]; then
  # Then we're starting a new since-days period. Ok to 'rsync --delete'.
  rsync -a --delete $uploads_dir/ $backup_uploads_sync_dir/
  echo "Synced uploads to: $backup_uploads_sync_dir/, without including uploads that have been deleted"
  $do_backup
  log_message "Backed up uploads to: $backup_archives_dir/$uploads_backup_filename"
else
  # We shall include all stuff that existed at since-days + stuff uploaded later. So don't --delete.
  rsync -a $uploads_dir/ $backup_uploads_sync_dir/
  echo "Synced uploads to: $backup_uploads_sync_dir/"
  $do_backup
  # Don't need to keep these — they're included in the backup archive we just created.
  echo "$old_archives_same_since_days" | xargs rm
  log_message "Backed up uploads to: $backup_archives_dir/$uploads_backup_filename"
  log_message "(And deleted old backups that contains the same files: $old_archives_same_since_days )"
fi
popd


# vim: et ts=2 sw=2 tw=0 fo=r
