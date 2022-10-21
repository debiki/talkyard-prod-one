#!/bin/bash

# This is just for testing, for now, so don't actually run this script, unless:
if [ "$1" != "really" ]; then
  echo "No? Really? Yes? Not really? Yes but not in reality?"
  exit 1
fi

echo "Ok, let's test install all."

# This runs all installation scripts, and, NOT IMPL:
#    sets the hosthame to $1, sets random passwords and starts Ty.

# Need the repo first:
# ----
#apt-get update
#apt-get -y install git vim locales
#apt-get -y install tree ncdu                # nice to have
#locale-gen en_US.UTF-8                      # installs English
#export LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8  # starts using English (warnings are harmless)
#
#cd /opt/
#git clone https://github.com/debiki/talkyard-prod-one.git talkyard
#cd talkyard
# ----

./scripts/prepare-os.sh 2>&1 | tee -a talkyard-maint.log

./scripts/install-docker-compose.sh 2>&1 | tee -a talkyard-maint.log

./scripts/start-firewall.sh 2>&1 | tee -a talkyard-maint.log


vi conf/play-framework.conf  # fill in values in the Required Settings section
vi .env                      # type a database password

cp mem/2g.yml docker-compose.override.yml


./scripts/upgrade-if-needed.sh 2>&1 | tee -a talkyard-maint.log

./scripts/schedule-logrotate.sh 2>&1 | tee -a talkyard-maint.log
./scripts/schedule-daily-backups.sh 2>&1 | tee -a talkyard-maint.log
./scripts/schedule-automatic-upgrades.sh 2>&1 | tee -a talkyard-maint.log

