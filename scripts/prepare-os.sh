#!/bin/bash

# This script makes ElasticSearch work, simplifies troubleshooting,
# and configures automatic security updates, with reboots.

function log_message {
  echo "`date --iso-8601=seconds --utc` prepare-os: $1"
}

echo
echo
log_message 'Configuring this Operating System:'


# Avoid harmless "warning: Setting locale failed" warnings from Perl:
# (https://askubuntu.com/questions/162391/how-do-i-fix-my-locale-issue)
locale-gen 'en_US.UTF-8'
if ! grep -q 'LC_ALL=' /etc/default/locale; then
  echo 'Setting LC_ALL to en_US.UTF-8...'
  echo 'LC_ALL=en_US.UTF-8' >> /etc/default/locale
  export LC_ALL='en_US.UTF-8'
fi
if ! grep -q 'LANG=' /etc/default/locale; then
  echo 'Setting LANG to en_US.UTF-8...'
  echo 'LANG=en_US.UTF-8' >> /etc/default/locale
  export LANG='en_US.UTF-8'
fi


# Install 'jq', for viewing json logs.
# And start using any hardware random number generator, in case the server has one.
log_message 'Installing jq and rng-tools, for json logs and hardware random numbers...'
apt-get -y install jq rng-tools

log_message 'Installing add-apt-repository...'
apt-get -y install software-properties-common


# Append system config settings, so the ElasticSearch Docker container will work,
# and so Nginx can handle more connections. [BACKLGSZ]

if ! grep -q 'Talkyard' /etc/sysctl.conf; then
  log_message 'Amending the /etc/sysctl.conf config...'
  cat <<-EOF >> /etc/sysctl.conf
		
		###################################################################
		# Talkyard settings
		#
		# Turn off swap, default = 60.
		vm.swappiness=0
		# Up the max backlog queue size (num connections per port), default = 128.
		# Sync with conf/sites-enabled-manual/talkyard-servers.conf.
		net.core.somaxconn=8192
		# ElasticSearch wants this, default = 65530
		# See: https://www.elastic.co/guide/en/elasticsearch/reference/current/vm-max-map-count.html
		vm.max_map_count=262144
		EOF

  log_message 'Reloading the system config...'
  sysctl --system
fi


# Make Redis happier:
# Redis doesn't want Transparent Huge Pages (THP) enabled, because that creates
# latency and memory usage issues with Redis. Disable THP now directly, and also
# after restart: (as recommended by Redis)
if ! grep -q '\[always\]' /sys/kernel/mm/transparent_hugepage/enabled ; then
  echo "Transparent Huge Pages is [madvise] or [never], fine, Redis happy."
else
  echo "Setting Transparent Huge Pages to [madvise], Redis wants this ..."
  echo madvise > /sys/kernel/mm/transparent_hugepage/enabled
  # We can use rc.local — also with Systemd, see: https://askubuntu.com/a/919598.
  rc_local_f="/etc/rc.local"
  if [ ! -f $rc_local_f ]; then
    echo "exit 0" >> $rc_local_f
  fi
  if ! grep -q 'transparent_hugepage/enabled' $rc_local_f ; then
    echo "Setting Transparent Huge Pages to [madvise] after reboot, in $rc_local_f..."
    # Insert ('i') before the last line ('$') in rc.local, which always? is
    # 'exit 0' in a new Ubuntu installation ... no, Debian now.
    sed -i -e '$i # For Talkyard and the Redis Docker container:\necho madvise > /sys/kernel/mm/transparent_hugepage/enabled\n' $rc_local_f
  fi
fi


# Simplify troubleshooting:
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
fi


# [ty_v1] Auto upgr:  Ask if, and recommend that, auto reboot if needed after security
# upgrades, and if Yes, then, add Automatic-Reboot also if there's already
# a 20auto-upgrades file.  Seems such a file exists by default, nowadays, Debian 12.

# Automatically apply OS security patches.
# The --force-confdef/old tells Apt to not overwrite any existing configuration, and to ask no questions.
# See e.g.: https://askubuntu.com/a/104912/48382.
# APT::Periodic::AutoremoveInterval "14"; = remove auto-installed dependencies that are no longer needed.
# APT::Periodic::AutocleanInterval "14";  = remove downloaded installation archives that are nowadays out-of-date.
# APT::Periodic::MinAge "8" = packages won't be deleted until they're these many days old (default is 2).
# more docs: less /usr/lib/apt/apt.systemd.daily
auto_upgr_f="/etc/apt/apt.conf.d/20auto-upgrades"
if [ -f $auto_upgr_f ]; then
  log_message "There's already an auto upgrades config file: $auto_upgr_f."
  log_message "I'll leave it as is — I won't (re)configure automatic upgrades."
  log_message "---- It's contents: ------"
  cat $auto_upgr_f
  log_message "--------------------------"
  log_message "Consider adding the below line,  if it's missing,"
  log_message "so your server will reboot if needed, for upgrades to take effect:"
  echo
  echo 'Unattended-Upgrade::Automatic-Reboot "true";'
  echo
else
  log_message 'Enabling automatic security updates and reboots...'
  DEBIAN_FRONTEND=noninteractive \
      apt-get install -y \
          -o Dpkg::Options::="--force-confdef" \
          -o Dpkg::Options::="--force-confold" \
          unattended-upgrades \
          update-notifier-common
  # [ty_v1] Change from "1" to "always", and use systemd to configure how often,
  # works with Debian >= 10, see: https://unix.stackexchange.com/a/541426
  cat <<EOF > $auto_upgr_f
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutoremoveInterval "14";
APT::Periodic::AutocleanInterval "14";
APT::Periodic::MinAge "8";
Unattended-Upgrade::Automatic-Reboot "true";
EOF
fi


log_message 'Done configuring the OS.'
echo

# vim: ts=2 sw=2 tw=0 fo=r list
