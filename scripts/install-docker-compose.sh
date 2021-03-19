#!/bin/bash

# This installs Docker and Docker-Compose on a totally new & blank Ubuntu 18.04 server,
# based on: https://docs.docker.com/engine/install/ubuntu/

function log_message {
  echo "`date --iso-8601=seconds --utc` install-docker: $1"
}

echo
log_message "Installing Docker and Docker-Compose..."


# ------- Add Docker repository

# Install packages to allow apt to use a repository over HTTPS:
apt-get update
apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    software-properties-common

# Add Docker’s official GPG key.
# And check its sha256 hash — in case the Docker servers has been compromised?
# (Note that the Debian packages are later downloaded from the same server,
# that is, download.docker.com, so, an attacker might be able to modify
# both the packages, and the keyring file, at the same time?)
d_gpg="/usr/share/keyrings/docker-archive-keyring.gpg"
if [ ! -f $d_gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o $d_gpg

  # As of 2021-03-19.
  gpg_hash_expected="a09e26b72228e330d55bf134b8eaca57365ef44bf70b8e27c5f55ea87a8b05e2"
  gpg_hash_actual="$(sha256sum $d_gpg)"
  if [[ ! $gpg_hash_actual =~ $gpg_hash_expected ]]; then
    echo "Unexpected SHA256 hash of: $d_gpg"
    echo "Expected: $gpg_hash_expected"
    echo "But sha256sum says:"
    echo "  $gpg_hash_actual"
    exit 1
  fi
fi


# Check that the fingerprint is correct:
# (see https://docs.docker.com/engine/installation/linux/ubuntu/#install-using-the-repository)
MATCHING_KEY_ROW="`apt-key fingerprint 0EBFCD88 | grep '9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88'`"
if [ -z "$MATCHING_KEY_ROW" ]; then
	echo
	log_message "ERROR: Bad Docker GPG key fingerprint. [TyEDKRFNGR]"
	log_message "Don't continue installing."
	log_message "Instead, ask for help in the Docker forums: https://forums.docker.com/,"
	log_message "and show them the output from running this:"
	log_message "    apt-key fingerprint 0EBFCD88"
	log_message "and include a link to this script too, here it is:"
	log_message "    https://github.com/debiki/talkyard-prod-one/blob/master/scripts/install-docker-compose.sh"
	echo
	exit 1
fi

if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
  echo \
    "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list
fi


# ------- Install Docker CE:

# List versions: apt-cache madison docker-ce
# Upgrade:
#   service docker stop
#   apt-get update
#   apt-get upgrade  # hmm seems to upgrade Docker too, also if installed via docker-ce=...
#   apt-get -y install docker-ce=VERSION   # or is this needed?

DOCKER_VERSION="5:20.10.5~3-0~ubuntu-focal"
apt-get update
apt-get -y install \
   docker-ce=$DOCKER_VERSION \
   docker-ce-cli=$DOCKER_VERSION \
   containerd.io

log_message "Testing Docker: running 'docker run hello-world' ..."

HELLO_WORLD="$(docker run hello-world | grep -i 'hello ')"
if [ -z "$HELLO_WORLD" ]; then
	echo
	log_message "Error installing or starting Docker: 'docker run hello-world' doesn't work. [EdEDKRBROKEN]"
	log_message "Ask for help in the Talkyard forum: https://www.talkyard.io/forum/"
	log_message "and/or in the Docker forums: https://forums.docker.com/"
	echo
	exit 1
fi

echo
log_message "The Docker hello-world image says:  $HELLO_WORLD"
echo
log_message "Docker worked fine. Installing Docker-Compose ..."


service docker start

# Make everything start automatically on server startup. Not needed though:
# on Debian and Ubuntu, the Docker service is configured to start on boot by default.
systemctl enable docker.service
systemctl enable containerd.service


# Enable log rotation, if there's no config file already.
docker_config_file="/etc/docker/daemon.json"
if [ ! -f "$docker_config_file" ]; then
  echo '
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "25m",
    "max-file": "5"
  }
}
' | tee -a $docker_config_file
  systemctl restart docker
fi



# Install Docker Compose (see https://github.com/docker/compose/releases)
#
# And verify it's the right file — check the sha256 hash.

dc_file="/usr/local/bin/docker-compose"
if [ -f $dc_file ]; then
  log_message "Docker-Compose already installed at: $dc_file"
else
  log_message "Installing Docker-Compose ..."
  curl -L "https://github.com/docker/compose/releases/download/1.28.5/docker-compose-$(uname -s)-$(uname -m)" -o $dc_file

  # The file name is docker-compose-Linux-x86_64 (renamed to docker-compose) —
  # probably on almost all Linux distros? So this hash should almost always work?
  # Version 1.28.5, as of 2021-03-19:
  dc_hash_expected="46406eb5d8443cc0163a483fcff001d557532a7fad5981e268903ad40b75534c"
  dc_hash_actual="$(sha256sum $dc_file)"
  if [[ ! $dc_hash_actual =~ $dc_hash_expected ]]; then
    echo "Bad SHA256 hash of: $dc_file"
    echo "Expected hash: $dc_hash_expected"
    echo "But sha256sum says:"
    echo "  $dc_hash_actual"
    exit 1
  fi
  chmod +x $dc_file
  log_message
fi

log_message
log_message
log_message "*** Done ***"
log_message
log_message "Docker and Docker-Compose installed."
log_message
log_message "This should print 'docker-compose version 1.28...' or later:"
log_message "----------------------------"
docker-compose -v
log_message "----------------------------"
echo

