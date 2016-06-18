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
# buggy, see: https://github.com/docker/compose/issues/3352
# and: http://stackoverflow.com/questions/36733777/error-on-docker-compose-when-i-use-by-pipe-with-sh-echo-docker-compose
# /usr/local/bin/docker-compose exec postgres pg_dumpall --username=postgres | gzip > $postgres_backup_path
/usr/bin/docker exec edp_postgres_1 pg_dumpall --username=postgres --clean --if-exists | gzip > $postgres_backup_path
echo "Backed up Postgres to: $postgres_backup_path"
set +x


# Backup Redis
# -------------------
# """Redis is very data backup friendly since you can copy RDB files while the
# database is running: the RDB is never modified once produced, and while it gets
# produced it uses a temporary name and is renamed into its final destination
# atomically using rename(2) only when the new snapshot is complete."""
# See http://redis.io/topics/persistence

redis_backup_path=$backup_dir/`hostname`-$1-$when-redis.rdb.gz
echo "Backing up Redis..."
gzip --to-stdout data/redis/dump.rdb > $redis_backup_path
echo "Backed up Redis to: $redis_backup_path"


echo

# vim: et ts=2 sw=2 tw=0 fo=r
