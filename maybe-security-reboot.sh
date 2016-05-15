#!/bin/bash

# Reboots if a reboot is required because of some high priority security upgrades.

if [ ! -f /var/run/reboot-required.pkgs ]; then
  exit 0
fi

urgent_lines=`xargs aptitude changelog < /var/run/reboot-required.pkgs | grep 'urgency=' | egrep -v '=(low|medium)'`

if [ -n "$urgent_lines" ]; then
  echo
  echo "`date '+%F %H:%M'` Some high priority security upgrades require a reboot. So I'll reboot."
  echo "Here are all packages that want a reboot right now: (including low priority security upgrades)"
  cat /var/run/reboot-required.pkgs
  echo
  echo "`date '+%F %H:%M'` Rebooting in five minutes..."
  echo

  /sbin/shutdown --reboot +5 "This server will reboot in 5 minutes, because of security upgrades. Please save your work."
fi

