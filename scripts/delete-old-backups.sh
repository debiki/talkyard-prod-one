#!/bin/bash

exec /usr/bin/docker compose run --rm backup  \
      /ty/delete-old-backups.sh

