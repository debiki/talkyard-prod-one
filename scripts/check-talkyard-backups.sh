#!/bin/bash

function log_message {
  echo "`date --iso-8601=seconds --utc` check-backups: $1"
}

if [ $# -ne 2 ]; then
  echo "Usage:  $0  --send-email-if-bad  BACKUP_DIR"
  echo "Or:     $0  --send-test-email"
  exit 1
fi

backup_dir="$2"

echo "Not yet implemented.  Bye.  [BADBKPEML]"
exit

# echo "Checking daily backups in $2:"



# Find the most recent Postgres backup.
# if [ older than two days — check both date in file name, and unix ctime? ]
# then
#   problems=" ....."
# fi


# Get the backup's random value.
# We can just look at the textual contents of the backup, to find out if they're
# most likely ok — no need to restore the database into a real PostgreSQL
# server. It'd be nice to do this too, optionally, though.
#
# good_row=$(zcat | grep "$random_value" | grep "$hostname" | grep 'postgres.sql')

# if [ -z "$good_row" ]
# then
#   problems=" ....."
# fi


# Have look in the uploads dir.
# There should be this file:
#    touch $backup_test_dir/$when--$(hostname)--$random_value
# if [ no such file ]
# then
#   problems="$problems\n ... more problems....."
# fi

# if [ uploads backup is older than two days ]
# then
#   problems=" ....."
# fi


# if [ "$problems" ]
# then
#   Send an email with the "$problems".  [BADBKPEML]
#   Need SMTP server addr, username, pwd, send-to address.
#
#   Websearch for "how send email from linux server" to find out how.
#
# fi
