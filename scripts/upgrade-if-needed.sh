#!/bin/bash

# Exit on any error.
set -e

function log_message {
  echo "`date --iso-8601=seconds --utc` upgrade-script: $1"
}

docker='/usr/bin/docker'
docker_compose="$docker compose"

echo


# Determine release branch
# ===========================

RELEASE_BRANCH_LINE=`egrep '^ *RELEASE_BRANCH=.*$' .env`
RELEASE_BRANCH=`sed -nr 's/^RELEASE_BRANCH= *([^# ]+) *$/\1/p' .env`
if [ -z "$RELEASE_BRANCH" ]; then
  if [ -n "$RELEASE_BRANCH_LINE" ]; then
    log_message "ERROR: Weird RELEASE_BRANCH=... line: (between ---)"
    log_message "----"
    log_message "$RELEASE_BRANCH_LINE"
    log_message "----"
    exit 1
  fi
  RELEASE_BRANCH='tyse-v1-regular'
  log_message "Using default release branch: $RELEASE_BRANCH (since nothing specified in .env)."
else
  log_message "Using release branch: $RELEASE_BRANCH."
fi

# This script (and others in this repo) are compatible only with Talkyard epoch 1.
if [ -z "$(echo "$RELEASE_BRANCH" | grep -e '-v1-')" ]; then
  log_message "ERROR: Wrong epoch in release branch. Should be '...-v1-...'"
  log_message "but is: '$RELEASE_BRANCH'."
  exit 1
fi

# Later: Check if >= 2 RELEASE_BRANCH lines. [ty_v1]


# Determine current version
# ===========================

CURRENT_VERSION=`sed -nr 's/VERSION_TAG=([a-zA-Z0-9\._-]*).*/\1/p' .env`
if [ -z "$CURRENT_VERSION" ]; then
  log_message "Apparently no Talkyard v1 version currently installed."
  log_message "Checking for latest version..."
else
  log_message "Current version: $CURRENT_VERSION"
  log_message "Checking for newer versions..."
fi


# Determine new version
# ===========================

# We'll find the next Talkyard version, by pulling a version list from a Git repo
# and looking at the last line in a version list file.
# (The version number changes a bit unpredictably, so we can't just bump it. And it
# also includes the Git revision which is "random".)

if [ ! -f versions/version-tags.log ]; then
  log_message "Downloading version numbers submodule..."
  /usr/bin/git submodule update --init
fi

cd versions
/usr/bin/git fetch origin
# This creates a branch named $RELEASE_BRANCH if it didn't already exist.
# Then checks out that branch, and hard-resets it to origin/$RELEASE_BRANCH.
# And sets it to track that origin branch (which isn't really needed since we
# hard-reset here anyway).
/usr/bin/git checkout -B $RELEASE_BRANCH --track origin/$RELEASE_BRANCH
cd ..

NEXT_VERSION=$(tail -n1 versions/version-tags.log)

if [ -z "$NEXT_VERSION" ]; then
  log_message "ERROR: Didn't find any usable Talkyard version. Don't know what to do. Bye. [EdEUPNOVER]"
  exit 1
fi

# Later: Check if CURRENT_VERSION is from the correct epoch, and NEXT too?  [ty_v1]
# (But wait until there are such versions)


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


# Remove old Talkyard images & containers
# ===========================

# So won't run out of disk. Let's keep images less than a year old, in case
# need to downgrade to previous server version:  31 * 12 * 24h = 8928.
# Also, do this whilst the old containers are still running, so their images
# won't be removed (that is, before the Upgrade step below).

if [ -n "$CURRENT_VERSION" ]; then
  # Let's make this work both with reverse DNS key names, and without (just "talkyard").
  # And if moving from .io to .app / .dev / .org TLD in the future, hmm.
  for label in "io.talkyard" "app.talkyard" "dev.talkyard" "org.talkyard" "talkyard" ; do
    # --all removes also unused but not-dangling images, but not volumes
    # (need to add --volumes to remove volumes too).
    $docker system prune --all --force --filter "until=8928h" \
            --filter "label=$label.prune=true" \
            --filter "label=$label.edition=tyse" \
            --filter "label=$label.epoch=1"
  done
fi


# Download new version
# ===========================

# `docker-compose.yml` uses the environment variable `$VERSION_TAG` in the image tags, so it'll pull
# the version we want.
log_message "Downloading version $NEXT_VERSION... (this might take long)"
VERSION_TAG="$NEXT_VERSION" $docker_compose pull


# Upgrade
# ===========================


# Shut down old version
# ```````````````````````````

if [ -n "$CURRENT_VERSION" ]; then
  log_message "Upgrading: Shutting down old version $CURRENT_VERSION..."
  # Stop 'app' before 'web', otherwise Play Framework (in 'app') logs warnings
  # about "ConnectionClosed PeerClosed". Better stop 'search' first of all, in case
  # ElasticSearch is a bit slow with reacting — so 'app' continues handling requests,
  # meanwhile.
  $docker_compose stop search
  $docker_compose stop app
  $docker_compose down
  log_message "Upgrading: Done shutting down."
fi


# Start any database migration
# ```````````````````````````

log_message "$WHAT: Starting v$NEXT_VERSION, the app and database ..."
VERSION_TAG="$NEXT_VERSION" $docker_compose up -d app


# Under Maintenance message
# ```````````````````````````

if [ -n "$CURRENT_VERSION" ]; then
  log_message "$WHAT: Starting 'web': Showing an Under Maintenance page"

  # For whatever reason (although we use `run --rm` below) the ty-maint container
  # might already exist. Then, remove it. But if it doesn't, then, disable `set -e`
  # so this script won't exit here when `rm` fails.
  set +e
  $docker rm -f ty-maint
  set -e

  # Start 'web' and change the 502.html error page to an Under Maintenance page.
  #
  # Also change 'app's IP addr so 'web' cannot connect to it  [maint_app_ip]
  # — otherwise, if 'web' can connect to Play Framework in 'app', then, making
  # requests to 'web' hangs, waiting for 'app' to have started completely.
  # We cannot use `--add-host=app:172.26.0...` — that param is for `docker`
  # only not `docker compose`. Instead, we add scripts/docker-compose.wrong-app-ip.yml
  # which does the same thing.
  #
  # Also, need to explicitly mount the Nginx config volumes, otherwise, when using
  # 'run', apparently they're not mounted.
  #
  set +e  # if doesn't work, harmless
  VERSION_TAG="$NEXT_VERSION"  \
      $docker_compose \
                        -f docker-compose.yml  \
                        -f scripts/docker-compose.wrong-app-ip.yml  \
        run --rm -d --no-deps  \
          --name ty-maint  \
          -p80:80  -p443:443  \
          -e TY_MAINT_MODE=true  \
          -v /opt/talkyard-v1/conf/maint-msg.html:/opt/nginx/html/502.html  \
          -v /opt/talkyard-v1/conf/sites-enabled-manual/:/etc/nginx/sites-enabled-manual/:ro  \
          -v /opt/talkyard-v1/data/sites-enabled-auto-gen/:/etc/nginx/sites-enabled-auto-gen/:ro  \
          -v /opt/talkyard-v1/data/certbot/:/etc/certbot/:ro  \
          web
  set -e

  # Poll-wait until: the app server has started, and is done with any database
  # migration, and with warming up the Nashorn Javascript engine.
  # We need to run cURL in the 'app' container, because 'web' is temporarily
  # connected to the wrong IP. [maint_app_ip]
  log_message "$WHAT: Waiting for the app server to have started ..."
  # (We've done: `set -e`, but that ignores `if` and `until` tests.)
  until $($docker exec -i "$($docker_compose ps -q app)"  \
            curl --output /dev/null --silent --head --fail  \
                 http://localhost:9000/-/are-scripts-ready)
  do
    printf '.'
    sleep 1
  done

  log_message "$WHAT: App server has started. Removing the Under Maintenance message ..."
  set +e
  $docker stop ty-maint
  set -e
fi

# Start everything
# ```````````````````````````

# Just 'web' left to start.
log_message "$WHAT: Starting 'web' (Nginx) ..."
VERSION_TAG="$NEXT_VERSION" $docker_compose up -d


# Done. Bump version
# ===========================

# Bump the current version number, but not until after 'docker compose up' above
# has exited successfully so we know it works.
log_message "$WHAT: Setting current version number to $NEXT_VERSION..."
sed --in-place=.prev-version -r "s/^(VERSION_TAG=)([a-zA-Z0-9\\._-]*)(.*)$/\1$NEXT_VERSION\3/" .env


log_message "Done. Bye."
echo

# vim: et ts=2 sw=2 tw=0 fo=r
