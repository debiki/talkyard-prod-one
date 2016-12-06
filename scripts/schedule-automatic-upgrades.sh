#!/bin/bash

function log_message {
  echo "`date --iso-8601=seconds --utc` schedule-upgrades: $1"
}

echo
log_message "Scheduling automatic upgrades..."

upgrade_match=`crontab -l | grep '/opt/ed.*/upgrade-if-needed'`

# We backup at 02:10, delete old backups at 03:10 (see schedule-daily-backups.sh),
# so let's check for new versions and upgrade, at 04:10.

if [ -z "$upgrade_match" ]; then
	crontab -l | { cat; echo '10 4 * * * cd /opt/ed && ./scripts/upgrade-if-needed.sh >> maint.log 2>&1'; } | crontab -
	log_message "Added entry to crontab. Done. Bye."
else
	log_message "Already done. Nothing to do. Bye."
fi
echo

