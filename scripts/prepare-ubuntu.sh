#!/bin/bash

# This script makes ElasticSearch work, and simplifies troubleshooting.

function log_message {
  echo "`date --iso-8601=seconds --utc` configure-ubuntu: $1"
}

echo
echo
log_message 'Configuring Ubuntu:'


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
# And install 'tree', nice to have.
log_message 'Installing jq, for json logs. And rng-tools, why not...'
apt-get -y install jq rng-tools tree

log_message 'Installing add-apt-repository...'
apt-get -y install software-properties-common


# Append system config settings, so the ElasticSearch Docker container will work:

if ! grep -q 'EffectiveDiscussions' /etc/sysctl.conf; then
  log_message 'Amending the /etc/sysctl.conf config...'
  cat <<-EOF >> /etc/sysctl.conf
		
		###################################################################
		# EffectiveDiscussions settings
		#
		net.ipv4.ip_forward        # makes Docker networking work
		vm.swappiness=1            # turn off swap, default = 60
		net.core.somaxconn=8192    # Up the max backlog queue size (num connections per port), default = 128. Sync with conf/web/server-listen-http(s).conf.
		vm.max_map_count=262144    # ElasticSearch requires (at least) this, default = 65530
		EOF

  log_message 'Reloading the system config...'
  sysctl --system
fi


# Make Redis happier:
# Redis doesn't want Transparent Huge Pages (THP) enabled, because that creates
# latency and memory usage issues with Redis. Disable THP now directly, and also
# after restart: (as recommended by Redis)
echo 'Disabling Transparent Huge Pages (for Redis)...'
echo never > /sys/kernel/mm/transparent_hugepage/enabled
if ! grep -q 'transparent_hugepage/enabled' /etc/rc.local; then
  echo 'Disabling Transparent Huge Pages after reboot, in /etc/rc.local...'
  # Insert ('i') before the last line ('$') in rc.local, which always? is
  # 'exit 0' in a new Ubuntu installation.
  sed -i -e '$i # For EffectiveDiscussions and the Redis Docker container:\necho never > /sys/kernel/mm/transparent_hugepage/enabled\n' /etc/rc.local
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


# Automatically apply OS security patches.
# The --force-confdef/old tells Apt to not overwrite any existing configuration, and to ask no questions.
# See e.g.: https://askubuntu.com/a/104912/48382.
log_message 'Configuring automatic security updates and reboots...'
apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" \
    unattended-upgrades update-notifier-common
cat <<EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
Unattended-Upgrade::Automatic-Reboot "true";
EOF


log_message 'Done configuring Ubuntu.'
echo

# vim: ts=2 sw=2 tw=0 fo=r list
