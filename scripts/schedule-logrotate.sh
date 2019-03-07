#!/bin/bash

function log_message {
  echo "`date --iso-8601=seconds --utc` schedule-logrotate: $1"
}


echo
log_message "Scheduling deletion of old log files..."
did_something=''


logr_dest=/etc/logrotate.d/talkyard

if [ ! -f $logr_dest ]; then
    cp ./conf/talkyard-logrotate.conf $logr_dest
    log_message "Installed $logr_dest."
    did_something='yes'
fi


cron_match=`crontab -l | grep '/opt/talkyard.*/delete-old-logs.sh'`

if [ -z "$cron_match" ]; then
    crontab -l | { cat; echo '10 0 * * * cd /opt/talkyard && ./scripts/delete-old-logs.sh >> talkyard-maint.log 2>&1'; } | crontab -
    log_message "Added delete-old-logs.sh cron job."
    did_something='yes'
fi


if [ -n "$did_something" ]; then
    log_message "Done. Bye."
else
    log_message "Apparently already done. Doing nothing. Bye."
fi
echo

