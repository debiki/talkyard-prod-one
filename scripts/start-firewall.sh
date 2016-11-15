#!/bin/bash

# Configure a firewall: (not needed if you're using Google Compute Engine)
ufw allow 22
ufw allow 80
ufw allow 443
ufw enable  # will ask you to confirm

# Make the firewall work with Docker: (not needed in Google Compute Engine)
# 1) Change forward policy to accept: DEFAULT_FORWARD_POLICY="ACCEPT"
sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/#&\n# This makes Docker work:\nDEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw
# 2) Allow incoming connections on the Docker port:
ufw allow 2375/tcp
ufw reload

