#!/bin/bash

# This script makes ElasticSearch work, and simplifies troubleshooting.

function log_message {
  echo "`date --iso-8601=seconds --utc` configure-ubuntu: $1"
}

echo
echo
log_message 'Configuring Ubuntu:'

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
log_message 'Configuring automatic security updates and reboots...'
apt-get install -y unattended-upgrades
apt-get install -y update-notifier-common
cat <<EOF > /etc/apt/apt.conf.d/20auto-upgrades
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
Unattended-Upgrade::Automatic-Reboot "true";
EOF


# Install 'jq', for viewing json logs.
# And start using any hardware random number generator, in case the server has one.
# And install 'tree', nice to have.
log_message 'Installing jq, for json logs, and rng-tools, why not...'
apt install jq rng-tools tree


log_message 'Done configuring Ubuntu.'
echo

# vim: ts=2 sw=2 tw=0 fo=r list
