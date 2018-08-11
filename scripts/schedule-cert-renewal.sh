#!/bin/bash

function log_message {
  echo "`date --iso-8601=seconds --utc` schedule-upgrades: $1"
}

echo
log_message "Scheduling renewal of HTTPS certificates..."

certbot_match=`crontab -l | grep 'renew-https-certs' | grep '/opt/talkyard'`

if [ -z "$certbot_match" ]; then
  crontab -l | { cat; echo '51 0 * * * cd /opt/talkyard && ./scripts/renew-https-certs.sh >> talkyard-maint.log 2>&1'; } | crontab -
  log_message "Added entry to crontab. Done. Bye."
else
  log_message "Already done. Nothing to do. Bye."
fi
echo
