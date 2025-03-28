#!/bin/bash

function log_message {
  echo "`date --iso-8601=seconds --utc` delete-backups: $1"
}

echo
echo
log_message "Deleting old backups ..."

backup_archives_dir=/opt/talkyard-backups/archives
deleted_backups_log=./deleted-backups.tmp.log



# Delete old Postgres and config backups
# -------------------

function deleteSome {
  # Need 'eval' otherwise `find` thinks the single quotes "'" are parts of a file name.
  find_files="eval find $backup_archives_dir -name '$@' -type f"

  min_recent_bkps=8
  recent_days=10
  recent_bkps=$($find_files -not -mtime +$recent_days)
  num_recent_bkps=$(echo "$recent_bkps" | wc --lines)

  # If new backups don't work (i.e. there are too few recent backups) or we haven't yet
  # been backing up for a while, then, delete nothing.
  # (Don't want to login to the server and notice that new backups haven't appeared,
  # and all old ones have been auto deleted.)
  #
  if [ "$num_recent_bkps" -lt "$min_recent_bkps" ]; then
    log_message "There're only $num_recent_bkps recent backups of type '$@' less"
    log_message "than $recent_days days old. That's few — maybe something is amiss?"
    log_message "I won't delete any old backups of that type."
    log_message "I see only these recent backups:"
    echo "$recent_bkps"
    echo
  else
    # Delete all older than a year.
    $find_files -mtime +366 -print -delete >> $deleted_backups_log

    # Keep monthly backups, if older than 100 days.
    $find_files -mtime +106 -regextype posix-extended  \
        -not -regex '.*[0-9]{4}-[0-9]{2}-01T.*' -print -delete >> $deleted_backups_log

    # Keep 1/10 days backups, if older than 1 month. (From the 1st, 11th and 21th days each month, but not 31st.)
    $find_files -mtime +32 -regextype posix-extended  \
        -not -regex '.*[0-9]{4}-[0-9]{2}-[012]1T.*' -print -delete >> $deleted_backups_log

    # Keep 1/3 days backups, if older than 15 days.
    $find_files -mtime +15 -regextype posix-extended \
        -not -regex '.*[0-9]{4}-[0-9]{2}-[012][148]T.*' -print -delete >> $deleted_backups_log

    # For the last 15 days, keep all backups.
  fi
}

deleteSome "*-postgres.sql.gz"
deleteSome "*-config.tar.gz"



# Delete old Redis backups
# -------------------

# Redis is a cache. No point in keeping backups for long.

find $backup_archives_dir -daystart -type f -name '*-redis.rdb.gz' -mtime +4 -print -delete >> $deleted_backups_log



# Delete old uploads backups
# -------------------

# We create one archive directory for each month, and each such archive directory
# includes all uploads that existed at the start of the month, plus files uploaded
# during that month.
#
# Let's keep such archive dirs for 4 months = 4 archives (30.5 * 4 = 122 < 123).
#
# But if there're only 1 or 2 archives, then, don't delete anything — because
# that could mean something is amiss: new backups no longer appear.

find_upl_bkps="find $backup_archives_dir -name '*-uploads-up-to-incl-*.d' -type d"

recent_bkps=$(eval $find_upl_bkps -not -mtime +123)
num_recent_bkps=$(echo "$recent_bkps" | wc --lines)

if [ "$num_recent_bkps" -le "2" ]; then
  log_message "There're only $num_recent_bkps recent uploads backups."
  log_message "That's few — maybe something is amiss?"
  log_message "I won't delete any old uploads backups."
  log_message "I see only these uploads backups:"
  echo "$recent_bkps"
  echo
else
  eval $find_upl_bkps -mtime +123  \
      -print -exec rm -r '{}' +  \
      >> $deleted_backups_log
fi

# old, keep for 4 months until these old uploads .tar.gz are gone:
# DO_AFTER 2020-05-01: delete this
find $backup_archives_dir -type f -name '*-uploads-start-*.tar.gz' -mtime +123 -print -delete >> $deleted_backups_log


# Delete old Postgres and config backups
# -------------------

# todo: delete old files like:   <host>-<date>-<tag>random-value.txt


# Show what was done
# -------------------

deleted_backups_str="$(cat $deleted_backups_log)"

if [ -z "$deleted_backups_str" ]
then
  log_message "No backups to delete."
else
  log_message "Deleted these backups:"
  echo "$deleted_backups_str"
  log_message "Done deleting backups."
fi
echo

rm $deleted_backups_log

