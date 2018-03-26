#!/bin/bash

function log_message {
  echo "`date --iso-8601=seconds --utc` delete-old-logs: $1"
}

deleted_logs=./deleted-logs.tmp.log
truncate -s0 $deleted_logs

# Delete logs older than x days.
find /var/log/postgresql/    -type f -name '*.log' -mtime +90 -print -delete >> $deleted_logs
find /var/log/redis/         -type f -name '*.log' -mtime +90 -print -delete >> $deleted_logs

log_message "Deleted these logs: `cat $deleted_logs`"

