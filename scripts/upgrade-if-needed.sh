#!/bin/bash

# Exit on any error.
set -e

function log_message {
  echo "`date --iso-8601=seconds --utc` upgrade-script: $1"
}

echo


# Determine current version
# ===========================

CURRENT_VERSION=`sed -nr 's/VERSION_TAG=([a-zA-Z0-9\._-]*).*/\1/p' .env`
if [ -z "$CURRENT_VERSION" ]; then
  log_message "Apparently no version currently installed."
  log_message "Checking for latest version..."
else
  log_message "Current version: $CURRENT_VERSION"
  log_message "Checking for newer versions..."
fi


# Determine new version
# ===========================

if [ ! -f versions/version-tags.log ]; then
  log_message "Downloading version numbers submodule..."
  /usr/bin/git submodule update --init
fi

# Find out the next app version, by pulling a version list from a Git repo.
# (The version number changes a bit unpredictably, and also includes the Git hash.)
cd versions
/usr/bin/git checkout master
/usr/bin/git pull

# Don't upgrade to WIP = work-in-progress versions, or 'test' version. And, by default, neither
# to 'alpha' or 'beta' or 'tp' (tech preview) 'rc' (release candidate) or 'maint'enance versions.
# Don't upgrade to new software stack versions = 'stack' because in order to do than,
# one will probably need to run `git pull` and resolve edit conflicts,
# perhaps run scripts or even export the PostgreSQL database and import into another type of database.
NEXT_VERSION=`grep -iv --regex='-wip' --regex='-tp' --regex='-alpha' --regex='-beta' --regex='-rc' --regex='-maint' --regex='stack' --regex='test' version-tags.log | tail -n1`
cd ..

if [ -z "$NEXT_VERSION" ]; then
  log_message "ERROR: Didn't find any usable software version. Don't know what to do. Bye. [EdEUPNOVER]"
  exit 1
fi


# Decide what to do
# ===========================

if [ "$CURRENT_VERSION" == "$NEXT_VERSION" ]; then
  log_message "No new version to upgrade to. Doing nothing. Bye."
  echo
  exit 0
fi

if [ -z "$CURRENT_VERSION" ]; then
  log_message "I will install version $NEXT_VERSION."
  WHAT='Installing'
else
  log_message "I will upgrade to $NEXT_VERSION."
  log_message "Backing up before upgrading..."
  ./scripts/backup.sh "$CURRENT_VERSION"
  echo "$CURRENT_VERSION" >> previous-version-tags.log
  WHAT='Upgrading'
fi


# Remove old images & containers
# ===========================

# So won't run out of disk. Let's keep images less than three months old, in case
# need to downgrade to previous server version because of some bug.
# Also, do this whilst the old containers are still running, so their images
# won't be removed (that is, before the Upgrade step below).  24h * 92 = 2208.

# Docker 18.09.0 errors out, because of until= ... [1809DKRBUG]
/usr/bin/docker system prune --all --force --filter "until=2208h"


# Download new version
# ===========================

# `docker-compose.yml` uses the environment variable `$VERSION_TAG` in the image tags, so it'll pull
# the version we want.
log_message "Downloading version $NEXT_VERSION... (this might take long)"
VERSION_TAG="$NEXT_VERSION" /usr/local/bin/docker-compose pull


# Upgrade
# ===========================

if [ -n "$CURRENT_VERSION" ]; then
  log_message "Upgrading: Shutting down old version $CURRENT_VERSION..."
  /usr/local/bin/docker-compose down
fi

log_message "$WHAT: Starting version $NEXT_VERSION..."
VERSION_TAG="$NEXT_VERSION" /usr/local/bin/docker-compose up -d

# Bump the current version number, but not until after 'docker-compose up' above
# has exited successfully so we know it works.
log_message "$WHAT: Setting current version number to $NEXT_VERSION..."
sed --in-place=.prev-version -r "s/^(VERSION_TAG=)([a-zA-Z0-9\\._-]*)(.*)$/\1$NEXT_VERSION\3/" .env


log_message "Done. Bye."
echo

# vim: et ts=2 sw=2 tw=0 fo=r
