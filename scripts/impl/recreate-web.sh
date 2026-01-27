#/bin/bash

# This makes 'web' container config changes in docker-compose.yml take effect
# (need to recreate the container).

docker compose kill web
docker compose rm -f web
docker compose up -d web
