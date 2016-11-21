#!/bin/bash

backup_match=`crontab -l | grep '/opt/ed.*/backup.sh daily'`
delete_match=`crontab -l | grep '/opt/ed.*/delete-old-backups.sh'`


if [ -z "$backup_match" ]; then
	crontab -l | { cat; echo '10 2 * * * cd /opt/ed && ./scripts/backup.sh daily >> cron.log 2>&1'; } | crontab -
fi

if [ -z "$delete_match" ]; then
	crontab -l | { cat; echo '10 4 * * * cd /opt/ed && ./scripts/delete-old-backups.sh >> cron.log 2>&1'; } | crontab -
fi

