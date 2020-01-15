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



function backup_at {
  date_time_colon="$1"  # e.g. "2030-08-15 21:30:11"

  echo >> talkyard-maint.log
  echo "Setting new date: $date_time_colon" >> talkyard-maint.log
  echo >> talkyard-maint.log

  #date_time_t=$(echo "$date_time_colon" | sed 's/://g' | sed 's/ /T/')
  date --set "$date_time_colon"
  # touch $backup_archives_dir/dummy-hostname-2018-06-01T0210Z-daily-postgres.sql.gz
  ./scripts/backup.sh autotest 2>&1 | tee -a talkyard-maint.log
}


function delete_old_backups_at {
  date_time_colon="$1"

  echo >> talkyard-maint.log
  echo "Setting new date: $date_time_colon" >> talkyard-maint.log
  echo >> talkyard-maint.log

  date --set "$date_time_colon"
  ./scripts/delete-old-backups.sh 2>&1 | tee -a talkyard-maint.log
}


delete_old_backups_at "2022-01-01 00:00:01"
backup_at "2022-01-01 10:00:00"
backup_at "2022-01-02 10:00:00"
backup_at "2022-01-03 10:00:00"
delete_old_backups_at "2022-01-03 11:00:01"
echo
echo "That should have deleted nothing"
read -p "Press enter to continue"
echo

backup_at "2022-01-04 10:00:00"
backup_at "2022-01-05 10:00:00"
backup_at "2022-01-06 10:00:00"
backup_at "2022-01-07 10:00:00"
backup_at "2022-01-08 10:00:00"
backup_at "2022-01-09 10:00:00"
backup_at "2022-01-10 10:00:00"
backup_at "2022-01-11 10:00:00"
backup_at "2022-01-12 10:00:00"
backup_at "2022-01-13 10:00:00"
backup_at "2022-01-14 10:00:00"
backup_at "2022-01-15 10:00:00"
backup_at "2022-01-16 10:00:00"
delete_old_backups_at "2022-01-16 11:00:01"
echo
echo "That should have deleted one Postgres, one Config and some Redis backups."
echo "See  min_recent_bkps=8  and   -mtime +15  in scripts/delete-old-backups.sh"
echo
read -p "Press enter to continue"
echo

backup_at "2022-02-01 10:00:00"
backup_at "2022-03-01 10:00:00"
backup_at "2022-04-01 10:00:00"
backup_at "2022-05-01 10:00:00"
backup_at "2022-06-01 10:00:00"
delete_old_backups_at "2022-01-09 11:00:01"
echo
echo "That should have deleted one Uploads backup."
echo "See  recent_bkps=  find  -not -mtime +123  in scripts/delete-old-backups.sh"
echo
echo "And some Redis backups."
echo "But no Postgres or Config backups — min_recent_bkps=8."
echo
read -p "Press enter to continue"
echo

backup_at "2022-06-02 10:00:00"

backup_at "2022-07-01 10:00:00"
backup_at "2022-07-02 10:00:00"
backup_at "2022-07-03 10:00:00"
backup_at "2022-07-04 10:00:00"
backup_at "2022-07-05 10:00:00"
backup_at "2022-07-06 10:00:00"
backup_at "2022-07-07 10:00:00"
backup_at "2022-07-08 10:00:00"
backup_at "2022-07-09 10:00:00"
backup_at "2022-07-10 10:00:00"
backup_at "2022-07-11 10:00:00"
backup_at "2022-07-12 10:00:00"
backup_at "2022-07-13 10:00:00"
backup_at "2022-07-14 10:00:00"
backup_at "2022-07-15 10:00:00"
backup_at "2022-07-16 10:00:00"
backup_at "2022-07-17 10:00:00"
backup_at "2022-07-18 10:00:00"
backup_at "2022-07-19 10:00:00"
backup_at "2022-07-20 10:00:00"
backup_at "2022-07-21 10:00:00"
backup_at "2022-07-22 10:00:00"
backup_at "2022-07-23 10:00:00"
backup_at "2022-07-24 10:00:00"
backup_at "2022-07-25 10:00:00"
backup_at "2022-07-26 10:00:00"
backup_at "2022-07-27 10:00:00"
backup_at "2022-07-28 10:00:00"
backup_at "2022-07-29 10:00:00"
backup_at "2022-07-30 10:00:00"
backup_at "2022-07-31 10:00:00"

backup_at "2022-08-01 10:00:00"
backup_at "2022-08-02 10:00:00"
backup_at "2022-08-03 10:00:00"
backup_at "2022-08-04 10:00:00"
backup_at "2022-08-05 10:00:00"
backup_at "2022-08-06 10:00:00"
backup_at "2022-08-07 10:00:00"
backup_at "2022-08-08 10:00:00"
backup_at "2022-08-09 10:00:00"
backup_at "2022-08-10 10:00:00"
backup_at "2022-08-11 10:00:00"
backup_at "2022-08-12 10:00:00"
backup_at "2022-08-13 10:00:00"
backup_at "2022-08-14 10:00:00"
backup_at "2022-08-15 10:00:00"
backup_at "2022-08-16 10:00:00"
backup_at "2022-08-17 10:00:00"
backup_at "2022-08-18 10:00:00"
backup_at "2022-08-19 10:00:00"
backup_at "2022-08-20 10:00:00"
backup_at "2022-08-21 10:00:00"
backup_at "2022-08-22 10:00:00"
backup_at "2022-08-23 10:00:00"
backup_at "2022-08-24 10:00:00"
backup_at "2022-08-25 10:00:00"
backup_at "2022-08-26 10:00:00"
backup_at "2022-08-27 10:00:00"
backup_at "2022-08-28 10:00:00"
backup_at "2022-08-29 10:00:00"
backup_at "2022-08-30 10:00:00"
backup_at "2022-08-31 10:00:00"

backup_at "2022-09-01 10:00:00"
backup_at "2022-09-02 10:00:00"
backup_at "2022-09-03 10:00:00"
backup_at "2022-09-04 10:00:00"
backup_at "2022-09-05 10:00:00"
backup_at "2022-09-06 10:00:00"
backup_at "2022-09-07 10:00:00"
backup_at "2022-09-08 10:00:00"
backup_at "2022-09-09 10:00:00"
backup_at "2022-09-10 10:00:00"
backup_at "2022-09-11 10:00:00"
backup_at "2022-09-12 10:00:00"
backup_at "2022-09-13 10:00:00"
backup_at "2022-09-14 10:00:00"
backup_at "2022-09-15 10:00:00"
backup_at "2022-09-16 10:00:00"
backup_at "2022-09-17 10:00:00"
backup_at "2022-09-18 10:00:00"
backup_at "2022-09-19 10:00:00"
backup_at "2022-09-20 10:00:00"
backup_at "2022-09-21 10:00:00"
backup_at "2022-09-22 10:00:00"
backup_at "2022-09-23 10:00:00"
backup_at "2022-09-24 10:00:00"
backup_at "2022-09-25 10:00:00"
backup_at "2022-09-26 10:00:00"
backup_at "2022-09-27 10:00:00"
backup_at "2022-09-28 10:00:00"
backup_at "2022-09-29 10:00:00"
backup_at "2022-09-30 10:00:00"


backup_at "2022-10-01 10:00:00"
backup_at "2022-10-02 10:00:00"
backup_at "2022-10-03 10:00:00"
backup_at "2022-10-04 10:00:00"
backup_at "2022-10-05 10:00:00"
backup_at "2022-10-06 10:00:00"
backup_at "2022-10-07 10:00:00"
backup_at "2022-10-08 10:00:00"
backup_at "2022-10-09 10:00:00"
backup_at "2022-10-10 10:00:00"
backup_at "2022-10-11 10:00:00"
backup_at "2022-10-12 10:00:00"
backup_at "2022-10-13 10:00:00"
backup_at "2022-10-14 10:00:00"
backup_at "2022-10-15 10:00:00"
backup_at "2022-10-16 10:00:00"
backup_at "2022-10-17 10:00:00"
backup_at "2022-10-18 10:00:00"
backup_at "2022-10-19 10:00:00"
backup_at "2022-10-20 10:00:00"
backup_at "2022-10-21 10:00:00"
backup_at "2022-10-22 10:00:00"
backup_at "2022-10-23 10:00:00"
backup_at "2022-10-24 10:00:00"
backup_at "2022-10-25 10:00:00"
backup_at "2022-10-26 10:00:00"
backup_at "2022-10-27 10:00:00"
backup_at "2022-10-28 10:00:00"
backup_at "2022-10-29 10:00:00"
backup_at "2022-10-30 10:00:00"
backup_at "2022-10-31 10:00:00"
echo
echo "What now?"
echo


echo
echo
echo "If you want to restore the original date, minus time elapsed: $ORIG_DATE"
echo
echo "date --set \"$ORIG_DATE\""
echo

export PATH="$ORIG_PATH"

