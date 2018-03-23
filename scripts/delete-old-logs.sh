
deleted_backups_log=./deleted-logs.tmp.log

find /var/log/postgresql/    -type f -name '*.log' -mtime +60 -print -delete >> $deleted_backups_log

# These don't log anything?
find /var/log/redis/         -type f -name '*.log' -mtime +60 -print -delete >> $deleted_backups_log
find /var/log/elasticsearch/ -type f -name '*.log' -mtime +60 -print -delete >> $deleted_backups_log


# Play = logback


log_message "Deleted these logs: `cat $deleted_backups_log`"
log_message "Done deleting logs."
