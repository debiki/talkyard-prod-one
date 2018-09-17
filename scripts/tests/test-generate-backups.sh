#!/usr/bin/env bash

if [ "$1" != "danger" ]; then
  echo ""
  echo "You didn't say danger"
  echo ""
  echo "Don't run this script. It messes up your computer's date-time."
  echo ""
  exit 1
fi

export ORIG_PATH="$PATH"
export PATH="/usr/bin:/bin"  # that's how Cron works, see:
# https://stackoverflow.com/questions/2135478/how-to-simulate-the-environment-cron-executes-a-script-with

export ORIG_DATE=$(date)


function backup_at_date {
  date_time_colon="$1"  # e.g. "2030-08-15 21:30:11"
  date_time_t=$(echo "$date_time_colon" | sed 's/://g' | sed 's/ /T/')
  date --set "$date_time_colon"
  # touch $backup_archives_dir/dummy-hostname-2018-06-01T0210Z-daily-postgres.sql.gz
  ./scripts/backup.sh  autotest
}

backup_at_date "2016-01-01 02:40:50"

backup_at_date "2017-01-01 02:40:50"
backup_at_date "2017-02-01 02:40:50"
backup_at_date "2017-03-01 02:40:50"
backup_at_date "2017-04-01 02:40:50"
backup_at_date "2017-05-01 02:40:50"
backup_at_date "2017-06-01 02:40:50"
backup_at_date "2017-07-01 02:40:50"
backup_at_date "2017-08-01 02:40:50"
backup_at_date "2017-09-01 02:40:50"  # kept?
backup_at_date "2017-09-02 02:40:50"  # deleted
backup_at_date "2017-10-01 02:40:50"
backup_at_date "2017-11-01 02:40:50"
backup_at_date "2017-12-01 02:40:50"

backup_at_date "2018-01-01 02:40:50"
backup_at_date "2018-01-02 02:40:50"
backup_at_date "2018-01-04 02:40:50"
backup_at_date "2018-01-11 02:40:50"
backup_at_date "2018-01-21 02:40:50"
backup_at_date "2018-01-30 02:40:50"

backup_at_date "2018-02-01 02:40:50"
backup_at_date "2018-02-02 02:40:50"
backup_at_date "2018-02-04 02:40:50"
backup_at_date "2018-02-11 02:40:50"
backup_at_date "2018-02-21 02:40:50"
backup_at_date "2018-02-28 02:40:50"

backup_at_date "2018-03-01 02:40:50"
backup_at_date "2018-03-02 02:40:50"
backup_at_date "2018-03-04 02:40:50"
backup_at_date "2018-03-11 02:40:50"
backup_at_date "2018-03-21 02:40:50"
backup_at_date "2018-03-30 02:40:50"

backup_at_date "2018-04-01 02:40:50"
backup_at_date "2018-04-02 02:40:50"
backup_at_date "2018-04-04 02:40:50"
backup_at_date "2018-04-11 02:40:50"
backup_at_date "2018-04-21 02:40:50"
backup_at_date "2018-04-30 02:40:50"


backup_at_date "2018-05-01 02:40:50"
backup_at_date "2018-05-02 02:40:50"
backup_at_date "2018-05-04 02:40:50"
backup_at_date "2018-05-11 02:40:50"
backup_at_date "2018-05-21 02:40:50"
backup_at_date "2018-05-22 02:40:50"
backup_at_date "2018-05-23 02:40:50"
backup_at_date "2018-05-24 02:40:50"
backup_at_date "2018-05-25 02:40:50"
backup_at_date "2018-05-26 02:40:50"
backup_at_date "2018-05-27 02:40:50"
backup_at_date "2018-05-28 02:40:50"
backup_at_date "2018-05-29 02:40:50"
backup_at_date "2018-05-30 02:40:50"
backup_at_date "2018-05-31 02:40:50"


backup_at_date "2018-06-01 02:40:50"
backup_at_date "2018-06-02 02:40:50"
backup_at_date "2018-06-03 02:40:50"
backup_at_date "2018-06-04 02:40:50"
backup_at_date "2018-06-05 02:40:50"
backup_at_date "2018-06-06 02:40:50"
backup_at_date "2018-06-07 02:40:50"
backup_at_date "2018-06-08 02:40:50"
backup_at_date "2018-06-09 02:40:50"
backup_at_date "2018-06-10 02:40:50"
backup_at_date "2018-06-11 02:40:50"
backup_at_date "2018-06-12 02:40:50"
backup_at_date "2018-06-13 02:40:50"
backup_at_date "2018-06-14 02:40:50"
backup_at_date "2018-06-15 02:40:50"
backup_at_date "2018-06-16 02:40:50"
backup_at_date "2018-06-17 02:40:50"
backup_at_date "2018-06-18 02:40:50"
backup_at_date "2018-06-19 02:40:50"
backup_at_date "2018-06-20 02:40:50"
backup_at_date "2018-06-21 02:40:50"
backup_at_date "2018-06-22 02:40:50"
backup_at_date "2018-06-23 02:40:50"
backup_at_date "2018-06-24 02:40:50"
backup_at_date "2018-06-25 02:40:50"
backup_at_date "2018-06-26 02:40:50"
backup_at_date "2018-06-27 02:40:50"
backup_at_date "2018-06-28 02:40:50"
backup_at_date "2018-06-29 02:40:50"
backup_at_date "2018-06-30 02:40:50"


backup_at_date "2018-07-01 02:40:50"
backup_at_date "2018-07-02 02:40:50"
backup_at_date "2018-07-03 02:40:50"
backup_at_date "2018-07-04 02:40:50"
backup_at_date "2018-07-05 02:40:50"
backup_at_date "2018-07-06 02:40:50"
backup_at_date "2018-07-07 02:40:50"
backup_at_date "2018-07-08 02:40:50"
backup_at_date "2018-07-09 02:40:50"
backup_at_date "2018-07-10 02:40:50"
backup_at_date "2018-07-11 02:40:50"
backup_at_date "2018-07-12 02:40:50"
backup_at_date "2018-07-13 02:40:50"
backup_at_date "2018-07-14 02:40:50"
backup_at_date "2018-07-15 02:40:50"
backup_at_date "2018-07-16 02:40:50"
backup_at_date "2018-07-17 02:40:50"
backup_at_date "2018-07-18 02:40:50"
backup_at_date "2018-07-19 02:40:50"
backup_at_date "2018-07-20 02:40:50"
backup_at_date "2018-07-21 02:40:50"
backup_at_date "2018-07-22 02:40:50"
backup_at_date "2018-07-23 02:40:50"
backup_at_date "2018-07-24 02:40:50"
backup_at_date "2018-07-25 02:40:50"
backup_at_date "2018-07-26 02:40:50"
backup_at_date "2018-07-27 02:40:50"
backup_at_date "2018-07-28 02:40:50"
backup_at_date "2018-07-29 02:40:50"
backup_at_date "2018-07-30 02:40:50"
backup_at_date "2018-07-31 02:40:50"


backup_at_date "2018-08-01 02:40:50"
backup_at_date "2018-08-02 02:40:50"
backup_at_date "2018-08-03 02:40:50"
backup_at_date "2018-08-04 02:40:50"
backup_at_date "2018-08-05 02:40:50"
backup_at_date "2018-08-06 02:40:50"
backup_at_date "2018-08-07 02:40:50"
backup_at_date "2018-08-08 02:40:50"
backup_at_date "2018-08-09 02:40:50"
backup_at_date "2018-08-10 02:40:50"
backup_at_date "2018-08-11 02:40:50"
backup_at_date "2018-08-12 02:40:50"
backup_at_date "2018-08-13 02:40:50"
backup_at_date "2018-08-14 02:40:50"
backup_at_date "2018-08-15 02:40:50"
backup_at_date "2018-08-16 02:40:50"
backup_at_date "2018-08-17 02:40:50"
backup_at_date "2018-08-18 02:40:50"
backup_at_date "2018-08-19 02:40:50"
backup_at_date "2018-08-20 02:40:50"
backup_at_date "2018-08-21 02:40:50"
backup_at_date "2018-08-22 02:40:50"
backup_at_date "2018-08-23 02:40:50"
backup_at_date "2018-08-24 02:40:50"
backup_at_date "2018-08-25 02:40:50"
backup_at_date "2018-08-26 02:40:50"
backup_at_date "2018-08-27 02:40:50"
backup_at_date "2018-08-28 02:40:50"
backup_at_date "2018-08-29 02:40:50"
backup_at_date "2018-08-30 02:40:50"  # sync with test-delete-backups.sh [4ABKR207]


date --set "$ORIG_DATE"   # minus the time taken, to create the backups  :-(

export PATH="$ORIG_PATH"

