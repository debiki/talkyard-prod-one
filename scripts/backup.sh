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
backup_dir=/opt/ed-backups
mkdir -p $backup_dir


# Backup Postgres
# -------------------

postgres_backup_path=$backup_dir/`hostname`-$1-$when-postgres.sql.gz
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
  redis_backup_path=$backup_dir/`hostname`-$1-$when-redis.rdb.gz
  log_message "Backing up Redis..."
  gzip --to-stdout data/cache/dump.rdb > $redis_backup_path
  log_message "Backed up Redis to: $redis_backup_path"
else
  log_message "No Redis dump.rdb to backup."
fi


# Backup ElasticSearch?
# -------------------
# ... later ...


# vim: et ts=2 sw=2 tw=0 fo=r
