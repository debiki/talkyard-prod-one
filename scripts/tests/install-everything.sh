#!/usr/bin/env bash


./scripts/prepare-ubuntu.sh 2>&1 | tee -a talkyard-maint.log
./scripts/install-docker-compose.sh 2>&1 | tee -a talkyard-maint.log

# This answers Yes to the do-you-really-want-to-enable-the-firewall? question.
echo "y" | ./scripts/start-firewall.sh 2>&1 | tee -a talkyard-maint.log

sed --in-place=.orig 's/="change_this"/="changzzz_thizzz_ok_done"/'  conf/play-framework.conf
sed --in-place=.orig 's/=change_me/=changzzz_myyy_ok_done/'  .env

cp mem/1.7g.yml docker-compose.override.yml

./scripts/upgrade-if-needed.sh 2>&1 | tee -a talkyard-maint.log


./scripts/schedule-logrotate.sh 2>&1 | tee -a talkyard-maint.log
./scripts/schedule-daily-backups.sh 2>&1 | tee -a talkyard-maint.log
./scripts/schedule-automatic-upgrades.sh 2>&1 | tee -a talkyard-maint.log
