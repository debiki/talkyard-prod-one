#!/bin/bash

# Exit on any error, e.g. Nginx config error, when testing with -t.
set -e

certbot --config-dir /opt/talkyard/data/certbot renew

docker-compose exec web nginx -t

# This only happens if  nginx -t  returns status 0 = ok:

echo "Reloading Nginx config."
docker-compose exec web nginx -s reload

