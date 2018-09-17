#!/usr/bin/env bash

if [ "$1" != "danger" ]; then
  echo ""
  echo "You didn't say danger"
  echo ""
  echo "Don't run this script. It's maybe dangerous."
  echo ""
  exit 1
fi

export ORIG_PATH="$PATH"
export PATH="/usr/bin:/bin"  # that's what Cron sees, see:
# https://stackoverflow.com/questions/2135478/how-to-simulate-the-environment-cron-executes-a-script-with

export ORIG_DATE=$(date)
date --set "2018-08-30 03:30:00"   # sync with test-generate-backups.sh [4ABKR207]

./scripts/delete-old-backups.sh

date --set "$ORIG_DATE"   # minus the time taken, to delete backups  :-(
export PATH="$ORIG_PATH"

