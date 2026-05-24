#!/bin/bash

# Checks if yesterday's Talkyard backup looks ok.
#
# $1 = backup dir path,  $2 = optional min free disk %, default 90%.
#
# Returns 0 if no problems detected, otherwise,
# returns an error code,
# and prints the problems to stderr on a single line, no double quotes
# (so should be safe to incl in a json doc).

if [ -z "$1" ]; then
  echo "Error: Backup directory path is required." >&2
  echo "Usage: $0 path/to/backup/dir" >&2
  exit 2
fi

backup_dir="$1"
if [ ! -d "$backup_dir" ]; then
  echo "Error: Backup directory '$backup_dir' does not exist. Bye" >&2
  exit 2
fi

max_disk_usage="${2:-90}"  # default is 90
if [[ ! "$max_disk_usage" =~ ^[0-9]+$ ]]; then
  echo "Error: Weird max disk usage param: '$max_disk_usage'." >&2
  echo "Usage: $0 path/to/backup/dir NN   # where NN is e.g. 85, for 85%. Bye" >&2
  exit 2
fi


# Let's check yesterday's backups, in case this script runs before today's backups done.
# Maybe will send 1 alert, when started 1st time? Oh well, maybe that's even a good thing?
cur_date=$(date -d "yesterday" +%Y-%m-%d)
cur_month=$(date -d "yesterday" +%Y-%m)

errors=()  # empty array

# Almost out of disk?
disk_usage=$(df -P "$backup_dir" | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$disk_usage" -gt "$max_disk_usage" ]; then
  errors+=("Disk usage high: ${disk_usage}% (limit: $max_disk_usage%).")
fi

# This month's uploads folder exists?
uploads_dir=$(find "$backup_dir" -maxdepth 1 -type d -name "*-uploads-up-to-incl-${cur_month}.d" | head -n 1)
if [ -z "$uploads_dir" ]; then
  errors+=("Uploads backup directory is missing for month ${cur_month}.")
fi

# Check databases & config file backups, & size.
components=("postgres.sql.gz" "redis.rdb.gz" "config.tar.gz")

for comp in "${components[@]}"; do
  # Re `head -n1`: If many backups from the same day, for now, let's look at just one,
  # good enough for now. Later, could look at ... the biggest? The most recent?
  backup_file=$(find "$backup_dir" -maxdepth 1 -type f -name "*${cur_date}*${comp}" | head -n 1)

  if [ -z "$backup_file" ]; then
    errors+=("Yesterday's backup missing: ${comp}")
  else
    # Files not empty, or hopelessly small?
    file_size=$(stat -c %s "$backup_file")
    if [ "$file_size" -lt 10100 ]; then
      errors+=("Backup file suspiciously small: $backup_file, ${file_size} bytes.")
    fi
  fi
done

# Later: Look at the  random-value.txt  file, and see if it's incl in the
# Postgres dump too, after decrypting & extracting.  [BADBKPEML]
# But it's enough to `grep` the postgres.sql backup file — no need to restore
# the database and run SQL queries.
#
# good_row=$(zcat | grep "$random_value" | grep "$hostname" | grep 'postgres.sql')

# Print any errors to stderr, exit w error code 1.
if [ "${#errors[@]}" -gt 0 ]; then
  # Concat array items.
  err_msg=$(printf " | %s" "${errors[@]}")
  echo "${err_msg:3}" >&2
  exit 1
fi

# Backups not obviously broken.
exit 0

