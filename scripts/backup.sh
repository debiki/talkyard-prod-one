#!/bin/bash

label="${1:-manual}"

exec /usr/bin/docker compose run --rm backup  \
      /ty/backup.sh  "$label"  "$(hostname)"  "$(date '+%FT%H%MZ' --utc)"


