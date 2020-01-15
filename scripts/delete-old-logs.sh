#!/bin/bash

function log_message {
  echo "`date --iso-8601=seconds --utc` delete-old-logs: $1"
}

deleted_logs=./deleted-logs.tmp.log
truncate -s0 $deleted_logs

# Delete logs older than x days.
find /var/log/postgresql/    -type f -name '*.log' -mtime +89 -print -delete >> $deleted_logs
find /var/log/redis/         -type f -name '*.log' -mtime +89 -print -delete >> $deleted_logs

deleted_logs_str="$(cat $deleted_logs)"

if [ -z "$deleted_logs_str" ]
then
  log_message "No old log files to delete."
else
  log_message "Deleted these old log files:"
  echo "$deleted_logs_str"
  log_message "Done deleting old log files."
fi
echo
