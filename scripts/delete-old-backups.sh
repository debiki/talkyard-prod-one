#!/bin/bash

function log_message {
  echo "`date --iso-8601=seconds --utc` delete-backups: $1"
}

log_message "Deleting old backups ..."

backup_archives_dir=/opt/talkyard-backup/archives
deleted_backups_log=./deleted-backups.tmp.log


# Delete old Postgres backups
# -------------------

# Delete all older than a year.
find $backup_archives_dir -type f -name '*-postgres.sql.gz' -mtime +366 -print -delete >> $deleted_backups_log

# Keep monthly backups, if older than 2 months.
find $backup_archives_dir -type f -name '*-postgres.sql.gz' -mtime +62 -not -regex '.*\d\d\d\d-\d\d-01T' -print -delete >> $deleted_backups_log

# Keep 1/10 days backups, if older than 4 weeks. (From the 1st, 11th and 21th days each month, but not 31st.)
find $backup_archives_dir -type f -name '*-postgres.sql.gz' -mtime +28 -not -regex '.*\d\d\d\d-\d\d-[012]1T' -print -delete >> $deleted_backups_log

# Keep 1/3 days backups, if older than 1 week.
find $backup_archives_dir -type f -name '*-postgres.sql.gz' -mtime +7 -not -regex '.*\d\d\d\d-\d\d-[012][148]T' -print -delete >> $deleted_backups_log

# For the last 7 days, keep all backups.



# Delete old Redis backups
# -------------------

# Redis is a cache. No point in keeping backpus for long.

find $backup_archives_dir -daystart -type f -name '*-redis.rdb.gz' -mtime +4 -print -delete >> $deleted_backups_log



# Delete old uploads backpus
# -------------------

# We create archives only once per month, and each such archive includes all uploads that existed
# at the start of the month, + uploads done during that month.
# Let's keep this for half a year = 6 archives.

find $backup_archives_dir -type f -name '*-uploads-start-*.tar.gz' -mtime +190 -print -delete >> $deleted_backups_log

# Too complicated:
# find $backup_archives_dir -type f -name '*-uploads-start-*.tar.gz' -mtime +190 -delete
# find $backup_archives_dir -type f -name '*-uploads-start-*.tar.gz' -mtime +92 -not -regex '.*\d\d\d\d-\d[147]-\d\d' -delete


log_message "Deleted these backups: `cat $deleted_backups_log`"
log_message "Done deleting backups."

rm $deleted_backups_log

