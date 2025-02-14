#! /bin/bash

## The backups dir is special: it should be accessible to backup scripts.
#bkp_dir=/var/opt/backups/talkyard/
#mkdir -p $bkp_dir
#docker volume create --driver local --opt type=none --opt device=$bkp_dir --opt o=bind \
#          talkyard-backups

# See: https://docs.docker.com/reference/cli/docker/volume/create/
docker volume create talkyard-v1-uploads
docker volume create talkyard-v1-cache-data
docker volume create talkyard-v1-pg17-data
docker volume create talkyard-v1-search-data

