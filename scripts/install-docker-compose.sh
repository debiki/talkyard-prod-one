#!/bin/bash

# This installs Docker and Docker-Compose on a totally new & blank Debian server,
# based on: https://docs.docker.com/engine/install/debian/

function log_message {
  echo "`date --iso-8601=seconds --utc` install-docker: $1"
}

echo
log_message "Installing Docker and Docker-Compose..."


# ------- Uninstall conflicting software

## [ty_v1] Look for any of these packages, and if found, ask if we can remove
## them. If not, don't proceed?
## But not that important — on a new Debian 12 VPS, none of them were installed
## by default.
# for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
#   sudo apt-get remove $pkg
# done


# ------- Add Docker repository

# Install packages to allow apt to use a repository over HTTPS:
apt-get update
apt-get -y install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    software-properties-common

# Add Docker’s official GPG key.
# And check its sha256 hash — in case the Docker servers has been compromised?
# (Note that the Debian packages are later downloaded from the same server,
# that is, download.docker.com, so, an attacker might be able to modify
# both the packages, and the keyring file, at the same time?
# Indeed, someone else has commented about this, and suggests that the
# public key be available in other ways than only via docker.com:
# https://github.com/docker/for-linux/issues/849#issuecomment-554721114 )
d_gpg_f="/etc/apt/keyrings/docker.gpg"
if [ -f $d_gpg_f ]; then
  log_message "Docker GPG key already present: $d_gpg_f, fine."
else
  gpg_url="https://download.docker.com/linux/debian/gpg"
  log_message "Downloading Docker GPG key to: $d_gpg_f, from: $gpg_url ..."
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL "$gpg_url" | gpg --dearmor -o $d_gpg_f
  sudo chmod a+r $d_gpg_f

  # As of 2021-03-19 ... and 2022-10-20 ... and 2023-07-10  [hash_instead]
  # Works for both Debian and Ubuntu (apparently same gpg key).
  gpg_hash_expected="a09e26b72228e330d55bf134b8eaca57365ef44bf70b8e27c5f55ea87a8b05e2"
  gpg_hash_actual="$(sha256sum $d_gpg_f)"
  if [[ ! $gpg_hash_actual =~ $gpg_hash_expected ]]; then
    echo
    log_message "Unexpected SHA256 hash of: $d_gpg_f"
    log_message "Expected: $gpg_hash_expected"
    log_message "But sha256sum says:"
    log_message "  $gpg_hash_actual"
    log_message "Is something amiss? I don't know. Aborting installation."
    echo
    log_message "ERROR, see above."
    exit 1
  fi
  log_message "Done. Docker GPG key SHA256 hash looks fine."
fi


# Check that the fingerprint is correct:
# But how do that, using only gpg? not apt-key?  [hash_instead]
# (see https://docs.docker.com/engine/installation/linux/debian/#install-using-the-repository)
# Sth like:
# pub_key_expected='9DC858229FC7DD38854AE2D88D81803C0EBFCD88'
# if [[ ! $(gpg $d_gpg_f) =~ $pub_key_expected ]]; then
# echo
# log_message "ERROR: Bad Docker GPG key fingerprint. [TyEDKRFNGR]"
# log_message "Don't continue installing."
# log_message "Instead, ask for help in the Docker forums: https://forums.docker.com/,"
# log_message "and show them the output from running this:"
# log_message "    apt-key fingerprint 0EBFCD88"
# log_message "and include a link to this script too, here it is:"
# log_message "    https://github.com/debiki/talkyard-prod-one/blob/master/scripts/install-docker-compose.sh"
# echo
# exit 1
#fi

d_list_f="/etc/apt/sources.list.d/docker.list"
if [ -f $d_list_f ]; then
  log_message "Docker Apt repo config file already here: $d_list_f, fine."
else
  log_message "Adding Docker Apt repo in $d_list_f:"
  echo \
      "deb [arch="$(dpkg --print-architecture)" signed-by=$d_gpg_f] \
https://download.docker.com/linux/debian \
"$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" \
      | tee $d_list_f
fi


# ------- Install Docker CE:


# List versions: apt-cache madison docker-ce
# Upgrade:
#   service docker stop
#   apt-get update
#   apt-get upgrade  # hmm seems to upgrade Docker too, also if installed via docker-ce=...
#   apt-get -y install docker-ce=VERSION   # or is this needed?

# To use a specific version:  (don't forget the '=', the first character)
#EQ_DOCKER_VERSION="=1.5-2"
# But the Debian default version is probably ok, so just skip '=VERSION':
EQ_DOCKER_VERSION=""

if [ ! -z "$(which docker)" ]; then
  log_message  "Docker already installed, fine."
else
  log_message "Installing Docker $EQ_DOCKER_VERSION..."
  apt-get update
  apt-get -y install \
        docker-ce$EQ_DOCKER_VERSION \
        docker-ce-cli$EQ_DOCKER_VERSION \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
fi

log_message "Testing Docker: Running 'docker run hello-world' ..."

HELLO_WORLD="$(docker run hello-world | grep -i 'hello ')"
if [ -z "$HELLO_WORLD" ]; then
  echo
  log_message "Error installing or starting Docker: 'docker run hello-world' doesn't work. [EdEDKRBROKEN]"
  log_message "Ask for help in the Talkyard forum: https://www.talkyard.io/forum/"
  log_message "and/or in the Docker forums: https://forums.docker.com/"
  echo
  log_message "ERROR, see above."
  exit 1
fi

echo
log_message "The Docker hello-world image says:  $HELLO_WORLD"
echo
log_message "Docker worked fine. Installing Docker-Compose ..."


service docker start

# Make everything start automatically on server startup. Not needed though:
# on Debian and Ubuntu, the Docker service is configured to start on boot by default.
# And if the server admins have changed that, leave as is.
#systemctl enable docker.service
#systemctl enable containerd.service


# Enable log rotation.

d_conf_f="/etc/docker/daemon.json"
if [ -f "$d_conf_f" ]; then
  log_message "There's already a Docker daemon.json: $d_conf_f,"
  log_message "I'll leave it as is; I won't configure Docker log rotation."
else
  log_message "Creating $d_conf_f with Docker log rotation settings..."
  echo '
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "25m",
    "max-file": "5"
  }
}
' | tee -a $d_conf_f
  systemctl restart docker
fi



# Install Docker Compose (see https://github.com/docker/compose/releases)
#
# And verify it's the right file — check the sha256 hash.

docker_compose_f="/usr/local/bin/docker-compose"
if [ -f $docker_compose_f ]; then
  log_message "Docker-Compose already installed at: $docker_compose_f"
else
  # Haven't yet upgraded to the new Docker Compose plugin written in Go. [ty_v1]
  d_c_url="https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)"
  log_message "Installing old Docker-Compose v1.29 from: $d_c_url ..."
  curl -L "$d_c_url" -o $docker_compose_f
  chmod +x $docker_compose_f

  # The file name is docker-compose-Linux-x86_64 (renamed to docker-compose) —
  # probably on almost all Linux distros? So this hash should almost always work?
  # Version 1.29.2, as of 2022-10-20:
  dc_hash_expected="f3f10cf3dbb8107e9ba2ea5f23c1d2159ff7321d16f0a23051d68d8e2547b323"
  dc_hash_actual="$(sha256sum $docker_compose_f)"
  if [[ ! $dc_hash_actual =~ $dc_hash_expected ]]; then
    echo
    log_message "Unexpected SHA256 hash of: $docker_compose_f"
    log_message "Expected: $dc_hash_expected"
    log_message "But sha256sum says:"
    log_message "  $dc_hash_actual"
    log_message "Is something amiss? I'm not sure. Aborting installation."
    echo
    log_message "ERROR, see above."
    echo
    exit 1
  fi
  log_message
fi

log_message
log_message
log_message "*** Done ***"
log_message
log_message "Docker and Docker-Compose installed."
log_message
log_message "This should print 'docker-compose version 1.29...' or later: (not yet using v2.x)"
log_message "----------------------------"
docker-compose -v
d_c_status_code="$?"
log_message "----------------------------"
echo

if [ $d_c_status_code -ne 0 ]; then
  log_message "ERROR: docker-compose didn't work, see above. Bye."
  exit 1
fi

exit 0
