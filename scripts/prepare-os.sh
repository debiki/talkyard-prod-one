#!/bin/bash

# This script makes ElasticSearch work, simplifies troubleshooting,
# and configures automatic security updates, with reboots.

if [ "$EUID" -ne 0 ]; then
  echo 'Error: You need to run this script as root. Bye.'
  exit 1
fi

if [ ! -d scripts/os-conf/ ]; then
  echo "Error: No  scripts/os-conf/  directory."
  echo "You must run this script from the root of the Talkyard installation directory. Bye."
  exit 1
fi

function log_message {
  echo "`date --iso-8601=seconds --utc` prepare-os: $1"
}

echo
echo
log_message 'Configuring this Operating System:'

did_what=''


# ----- System config

# Append system config settings, so the ElasticSearch Docker container will work,
# and so Nginx can handle more connections. [BACKLGSZ]

conf_path='/etc/sysctl.d/99-talkyard.conf'
if [ ! -f "$conf_path" ]; then
  log_message "Adding Talkyard system config: $conf_path ..."
  install -g root -o root -m 644 scripts/os-conf/talkyard-systemctl.conf $conf_path
  log_message 'Reloading the system config...'
  sysctl --system
  did_what="$did_what Added Talkyard system config to $conf_path."
else
  log_message "Talkyard system config found: $conf_path, leaving as is."
fi


# ----- Transparent Huge Pages (Redis)

# Redis doesn't want Transparent Huge Pages (THP) enabled, because that creates
# latency and memory usage issues with Redis. Disable THP now directly, and also
# after restart: (as recommended by Redis)
thp_path=/sys/kernel/mm/transparent_hugepage/enabled
if [ -f $thp_path ] && ! grep -q '\[always\]' $thp_path ; then
  log_message "Transparent Huge Pages is [madvise] or [never], fine, Redis happy."
else
  log_message "Setting Transparent Huge Pages to [madvise], Redis wants this ..."
  echo madvise > $thp_path

  # Remember across restarts. (Debian 12, 13, Ubuntu 24, 26)
  tmpfile_conf='/etc/tmpfiles.d/redis-thp.conf'
  if [ ! -f "$tmpfile_conf" ]; then
    log_message "Remembering [madvise] across reboots in $tmpfile_conf ..."
    echo "w $thp_path - - - - madvise" > "$tmpfile_conf"
    did_what="$did_what Set Transparent Huge Pages to [madvise]."
  fi
fi


# ----- Troubleshooting

# Simplify troubleshooting:  (pointless if using `sudo`, root settings then has no effect, oh well)
if ! grep -q 'HISTTIMEFORMAT' ~/.bashrc; then
  log_message 'Adding history settings to .bashrc...'
  cat <<-EOF >> ~/.bashrc
		
		###################################################################
		export HISTCONTROL=ignoredups
		export HISTCONTROL=ignoreboth
		export HISTSIZE=10100
		export HISTFILESIZE=10100
		export HISTTIMEFORMAT='%F %T %z  '
		EOF
  did_what="$did_what Added HIST* settings to .bashrc."
else
  log_message 'Probably sensible settings found in .bashrc, leaving as is.'
fi


# ----- Security Updates

# Automatically apply OS security patches.
# There's already a 20auto-upgrades file. Let's add our config in a 99 file.
# The --force-confdef/old tells Apt to not overwrite any existing configuration, and to ask no questions.
# See e.g.: https://askubuntu.com/a/104912/48382.
# APT::Periodic::AutoremoveInterval "14"; = remove auto-installed dependencies that are no longer needed.
# APT::Periodic::AutocleanInterval "14";  = remove downloaded installation archives that are nowadays out-of-date.
# APT::Periodic::MinAge "8" = packages won't be deleted until they're these many days old (default is 2).
# more docs: less /usr/lib/apt/apt.systemd.daily
auto_upgr_f="/etc/apt/apt.conf.d/99security-upgrades"
if [ -f $auto_upgr_f ]; then
  log_message "There's already an auto upgrades config file: $auto_upgr_f, fine, leaving as is."
else
  log_message "Enabling automatic security updates and reboots: $auto_upgr_f ..."
  did_what="$did_what Enabled automatic security updates and reboots."
  # (We should have run `apt update` already, it's the 2nd step in ../README.md)
  # About the packages we install:
  # unattended-upgrades: Downloads and installs security upgrades automatically and unattended,
  # see: https://packages.debian.org/trixie/unattended-upgrades
  DEBIAN_FRONTEND=noninteractive \
      apt-get install -y \
          -o Dpkg::Options::="--force-confdef" \
          -o Dpkg::Options::="--force-confold" \
          unattended-upgrades
  install -g root -o root -m 644 scripts/os-conf/talkyard-apt-security-upgrades $auto_upgr_f
fi


log_message "Done configuring the OS."

if [ -z "$did_what" ]; then
  log_message "I did nothing — everything seemed ok already."
else
  log_message "I did this: $did_what"
fi
echo

# vim: ts=2 sw=2 tw=0 fo=r list
