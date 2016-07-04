#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 dump-tag"
  echo "E.g.: $0 weekly"
  echo "or: $0 daily"
  echo "or: $0 v0.12.34-123def"
  exit 1
fi

echo "`date '+%F %H:%M'` Backing up, tag: $1"

when="`date '+%FT%H.%M'`"
backup_dir=/opt/ed-backups
mkdir -p $backup_dir


# Backup Postgres
# -------------------

set -x
postgres_backup_path=$backup_dir/`hostname`-$1-$when-postgres.sql.gz
echo "Backing up Postgres..."
# (cron's path apparently doesn't include /sur/local/bin/)
# Specify -T so Docker won't create a tty, because that results in a Docker Compose
# stack trace and error exit code.
./dc exec -T rdb pg_dumpall --username=postgres --clean --if-exists | gzip > $postgres_backup_path
#./dc exec -T rdb pg_dump --username=ed --clean --if-exists --create ed | gzip > $postgres_backup_path
echo "Backed up Postgres to: $postgres_backup_path"
set +x


# Backup Redis
# -------------------
# """Redis is very data backup friendly since you can copy RDB files while the
# database is running: the RDB is never modified once produced, and while it gets
# produced it uses a temporary name and is renamed into its final destination
# atomically using rename(2) only when the new snapshot is complete."""
# See http://redis.io/topics/persistence

if [ -f data/redis/dump.rdb ]; then
  redis_backup_path=$backup_dir/`hostname`-$1-$when-redis.rdb.gz
  echo "Backing up Redis..."
  gzip --to-stdout data/redis/dump.rdb > $redis_backup_path
  echo "Backed up Redis to: $redis_backup_path"
else
  echo "No Redis dump.rdb to backup."
fi


# Backup ElasticSearch?
# -------------------
# ... later ...


echo

# vim: et ts=2 sw=2 tw=0 fo=r
