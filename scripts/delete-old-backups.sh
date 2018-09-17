#!/bin/bash

function log_message {
  echo "`date --iso-8601=seconds --utc` delete-backups: $1"
}

log_message "Deleting old backups ..."

backup_archives_dir=/opt/talkyard-backups/archives
deleted_backups_log=./deleted-backups.tmp.log


# Delete old Postgres backups
# -------------------

# Delete all older than a year.
find $backup_archives_dir -type f -name '*-postgres.sql.gz' -mtime +366 -print -delete >> $deleted_backups_log

# Keep monthly backups, if older than 100 days.
find $backup_archives_dir -type f -name '*-postgres.sql.gz' -mtime +106 -regextype posix-extended -not -regex '.*[0-9]{4}-[0-9]{2}-01T.*' -print -delete >> $deleted_backups_log

# Keep 1/10 days backups, if older than 1 month. (From the 1st, 11th and 21th days each month, but not 31st.)
find $backup_archives_dir -type f -name '*-postgres.sql.gz' -mtime +32 -regextype posix-extended -not -regex '.*[0-9]{4}-[0-9]{2}-[012]1T.*' -print -delete >> $deleted_backups_log

# Keep 1/3 days backups, if older than 10 days.
find $backup_archives_dir -type f -name '*-postgres.sql.gz' -mtime +10 -regextype posix-extended -not -regex '.*[0-9]{4}-[0-9]{2}-[012][148]T.*' -print -delete >> $deleted_backups_log

# For the last 10 days, keep all backups.



# Delete old Redis backups
# -------------------

# Redis is a cache. No point in keeping backups for long.

find $backup_archives_dir -daystart -type f -name '*-redis.rdb.gz' -mtime +4 -print -delete >> $deleted_backups_log



# Delete old uploads backups
# -------------------

# We create archives only once per month, and each such archive includes all uploads that existed
# at the start of the month, + uploads done during that month.
# Let's keep such archives for 4 months = 4 archives (30.5 * 4 = 122 < 123).

find $backup_archives_dir -type f -name '*-uploads-start-*.tar.gz' -mtime +123 -print -delete >> $deleted_backups_log


log_message "Deleted these backups: `cat $deleted_backups_log`"
log_message "Done deleting backups."

rm $deleted_backups_log

