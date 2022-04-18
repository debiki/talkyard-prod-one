#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 /path/to/dump/dir/in-the-container"
  echo
  echo "E.g.:  $0 /var/log/postgresql/site-121/talkyard-dump-2022-04-17"
  exit 1
fi

dump_dir="$1"

echo
echo "Will import from this dir in the container: $dump_dir"
echo
echo "First checking if dir exists in the container:"
echo


# Is the dir path correct?
set -x
docker-compose exec rdb ls -d $dump_dir
dc_exit_code=$?
set +x
if [ $dc_exit_code -ne 0 ]; then
  echo "Bad path. It should be a path *inside the container*. Bye"
  exit 1
fi

# And includes the expected file(s)?
set -x
docker-compose exec rdb ls -d "$dump_dir/database-schema.sql"
dc_exit_code=$?
set +x
if [ $dc_exit_code -ne 0 ]; then
  echo "Directory exists: $dump_dir, but is it empty?"
  echo "At least file database-schema.sql is missing. Bye"
  exit 1
fi



psql="docker-compose exec rdb psql"


echo
echo "Creating user 'talkyard' — this logs an harmless error, if user already exists:"
echo

set -x
$psql -U postgres -c "create user talkyard with password 'change_me';"
set +x

# Hereafter, exit on error
set -e


echo
echo "(Re)creating database talkyard_imported:"
echo

set -x
$psql -U postgres -c 'drop database if exists talkyard_imported;'
$psql -U postgres -c 'create database talkyard_imported owner talkyard;'
set +x


echo
echo "Importing the database schema: (that is, empty tables, indexes, triggers etc)"
echo

set -x
$psql talkyard_imported talkyard -f "$dump_dir/database-schema.sql"
set +x


echo
echo "Done importing schema. Next: importing table conents: (this can take long)"
echo
echo "(And there will be one harmless error, just below,"
echo "either:  relation 'schema_version' does not exist"
echo "    or:  relation 'flyway_schema_history' does not exist"
echo "— because only one of those tables exists, got renamed.)"
echo

set -x
$psql talkyard_imported postgres -f "$dump_dir/copy-files-to-tables.sql"
set +x



echo
echo "Done."
echo
echo "You should rename the database, before you start using it:"
echo ""
echo "  docker-compose exec rdb psql -U postgres -c 'ALTER DATABASE talkyard_imported RENAME TO talkyard;'"
echo
echo
echo "If the 'talkyard' database user was just created, choose a new password:"
echo ""
echo "        docker-compose exec rdb psql -U postgres -c \"ALTER USER talkyard PASSWORD 'something';\""
echo ""
echo "Indent the above command with spaces so it won't get saved in your shell's history"
echo "— which would be bad, since there's a password therein."
echo
echo
echo "Thereafter, update /opt/talkyard/conf/play-framework.conf with the database name,"
echo "database user name, and password. Good luck"
echo
echo


echo "Clear the Redis mem cache ... todo. And ElasticSearch. Uploads."
echo "And configure incoming Postmarkapp email webhooks. And outgoing SMTP."
echo "And off-site backups."
echo

