#!/bin/bash

# Calls check-talkyard-backups.sh and alerts you, if something looks wrong
# with the backups.
#
# **Edit** the configuration here at the top, and the send-alert command at the bottom.
#
# Then, test if it works, by pointing it to an empty dir.
#
# Then, run this script as a daily cron job, e.g. add this line to your crontab:
#
#   @daily cd /home/user && ./alert-if-talkyard-backups-bad.sh >> talkyard-cron.log 2>&1
#

# ===== Configuration

check_backups_script='/home/user/check-talkyard-backups.sh'
from_addr='talkyard-backup-alert-noreply@your-company.com'
to_addr='your-name@your-company.com'

secret_token='1234abcd....'  #  or ="$SOME_ENV_VAR"

backups_dir="/path/to/backups"
# Or `backups_dir` as a parameter:
# if [ -z "$1" ]; then
#     echo "Error: Backup directory path missing." >&2
#     echo "Usage: $0 /path/to/backup/dir" >&2
#     exit 2
# fi
# backups_dir="$1"


# ===== Any errors?

# Check for errors, capture stderr, ignore stdout.
err_msgs=$("$check_backups_script" "$backups_dir" 2>&1 >/dev/null)
exit_code=$?

server_name="$(hostname)"
time_now="$(date --iso-8601=seconds --utc)"

function log_message {
  echo "$time_now check-backups: $1"
}

# All fine?
if [ "$exit_code" -eq 0 ]; then
  log_message "Yesterday's backup in $backups_dir looks fine."
  exit
fi

# Error message missing?
if [ -z "$err_msgs" ]; then
    err_msgs="Backup check failed, exit code $exit_code, but no output. This script: $check_backups_script, backups dir: $backups_dir."
fi

log_message "Backup problems? Sending an alert to: $to_addr.  Reasons: $err_msgs.  Backups dir: $backups_dir."


# ===== Send Alert

# Replace this with whatever works for you. You can use `sudo -u nobody <command>`
# to run the network request / sending the email  as a non-privileged user.
# (And remove 'echo'.)
#
# $err_msgs shouldn't include any '"' double quotes or newlines, so should be ok to
# just inline as-is in the json body. (Maybe use jq instead? Or a Deno script?)
#
# This example sends an email via Postmarkapp, a transactional email service:
#
echo Example curl request to notify yourself:
echo sudo -u nobody curl --silent --show-error "https://api.postmarkapp.com/email"  \
    -X POST \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "X-Postmark-Server-Token: $secret_token" \
    -d "{ \"From\": \"$from_addr\",
          \"To\": \"$to_addr\",
          \"Subject\": \"Talkyard backup problems\",
          \"HtmlBody\": \"Problems with yesterday's backup:  $err_msgs.  Time now: $time_now. Server: $server_name. Backups dir: $backups_dir.\",
          \"MessageStream\": \"outbound\"
        }"

