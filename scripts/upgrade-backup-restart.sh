#!/bin/bash

# Find out the next app version, by pulling a version list from a Git repo.
# (The version number changes a bit unpredictably, and also includes the Git hash.)
cd versions
git checkout master
git pull
export VERSION_TAG=`tail -n1 version-tags.log`
cd ..

# Download the new version.
# `docker-compose.yml` uses the environment variable `VERSION_TAG` in the image tags, so it'll pull
# the version we want.
docker-compose pull

# Backup (unless we're starting for the very first time).
if [ -f version-tag ]; then
  PREVIOUS_VERSION=`cat version-tag`
  ./scripts/backup.sh "$PREVIOUS_VERSION"
  echo "$PREVIOUS_VERSION" >> previous-version-tags.log
fi


# Shut down the old version, start the new. The website will go offline for a short while.
docker-compose down
./dc down
echo $VERSION_TAG > version-tag
./dc up -d


# vim: et ts=2 sw=2 tw=0 fo=r
