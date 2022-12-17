#!/bin/bash

# Exit on any error.
set -e

function log_message {
  echo "`date --iso-8601=seconds --utc` upgrade-script: $1"
}

echo


# Determine release channel
# ===========================

RELEASE_CHANNEL_LINE=`egrep '^ *RELEASE_CHANNEL=.*$' .env`
RELEASE_CHANNEL=`sed -nr 's/^RELEASE_CHANNEL= *([^# ]+) *$/\1/p' .env`
if [ -z "$RELEASE_CHANNEL" ]; then
  if [ -n "$RELEASE_CHANNEL_LINE" ]; then
    log_message "ERROR: Weird RELEASE_CHANNEL=... line: (between ---)"
    log_message "----"
    log_message "$RELEASE_CHANNEL_LINE"
    log_message "----"
    exit 1
  fi
  RELEASE_CHANNEL='master'
  log_message "Using release channel: $RELEASE_CHANNEL, same as tyse-v0-regular."
else
  log_message "Using release channel: $RELEASE_CHANNEL."
fi

# Later: Check if doing a crazy channel change, like, from tyse-v1-x and *downwards*
# to tyse-v0-x.  But wait until has ported all this from Bash to Deno. [bash2deno]
# And if >= 2 RELEASE_CHANNEL lines.  And CURRENT_VERSION sanity checks too. [ty_v1]


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
/usr/bin/git fetch origin
# This creates a branch named $RELEASE_CHANNEL if it didn't already exist.
# Then checks out that branch, and hard-resets it to origin/$RELEASE_CHANNEL.
# And sets it to track that origin branch (which isn't really needed since we
# hard-reset here anyway).
/usr/bin/git checkout -B $RELEASE_CHANNEL --track origin/$RELEASE_CHANNEL

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

# So won't run out of disk. Let's keep images less than six months old, in case
# need to downgrade to previous server version.
# Also, do this whilst the old containers are still running, so their images
# won't be removed (that is, before the Upgrade step below).  31 * 6 * 24h = 4464.

if [ -n "$CURRENT_VERSION" ]; then
  /usr/bin/docker system prune --all --force --filter "until=4464h"
fi


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
  # Stop 'app' before 'web', otherwise Play Framework (in 'app') logs warnings
  # about "ConnectionClosed PeerClosed". Better stop 'search' first of all, in case
  # ElasticSearch is a bit slow with reacting — so 'app' continues handling requests,
  # meanwhile.
  /usr/local/bin/docker-compose stop search
  /usr/local/bin/docker-compose stop app
  /usr/local/bin/docker-compose down
  log_message "Upgrading: Done shutting down."
fi

log_message "$WHAT: Starting v$NEXT_VERSION, the app and database ..."
VERSION_TAG="$NEXT_VERSION" /usr/local/bin/docker-compose up -d app

if [ -n "$CURRENT_VERSION" ]; then
  log_message "$WHAT: Starting 'web': Showing an Under Maintenance page"
  VERSION_TAG="$NEXT_VERSION" /usr/local/bin/docker-compose run --rm -d  \
        --name ty-maint  --no-deps  \
        -p80:80  -p443:443  \
        -v /opt/talkyard/conf/maint-msg.html:/opt/nginx/html/502.html  \
        web

  # Wait until the app server is done with any database migration and with
  # warming up Nashorn.
  # Let's try both HTTPS and HTTP, in case HTTP gets redirected to HTTPS,
  # or in case HTTPS hasn't been configured (testing on localhost).
  # Use --insecure HTTPS because https://localhost has no valid cert.
  log_message "$WHAT: Waiting for the app server to have started ..."
  ready_host_path='localhost/-/are-scripts-ready'
  until $(curl --output /dev/null --silent --head --fail --location --insecure http://$ready_host_path)
  do
    printf '.'
    sleep 1
  done

  log_message "$WHAT: App server has started. Removing Under Maintenance message ..."
  docker kill ty-maint
fi

# Just 'web' left to start.
log_message "$WHAT: Starting the HTTP server ..."
VERSION_TAG="$NEXT_VERSION" /usr/local/bin/docker-compose up -d

# Bump the current version number, but not until after 'docker-compose up' above
# has exited successfully so we know it works.
log_message "$WHAT: Setting current version number to $NEXT_VERSION..."
sed --in-place=.prev-version -r "s/^(VERSION_TAG=)([a-zA-Z0-9\\._-]*)(.*)$/\1$NEXT_VERSION\3/" .env


log_message "Done. Bye."
echo

# vim: et ts=2 sw=2 tw=0 fo=r
