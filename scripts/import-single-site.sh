#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Usage: $0 /path/to/dump/dir/in-the-container"
  echo
  echo "E.g.:  $0 /var/log/postgresql/site-121/talkyard-dump-2022-04-17"
  exit 1
fi

dump_dir="$1"


echo
echo "Will import from this dir: $dump_dir"
#echo
# echo "First checking that dir exists on the host:"
# echo
# 
# set -x
# ls -d $dump_dir
# host_exit_code=$?
# set +x
# if [ $host_exit_code -ne 0 ]; then
#   echo "Bad path, not a directory: $dump_dir. Bye"
#   exit 1
# fi


echo
echo "Checking if dir exists in the database container, at the same path:"
echo

set -x
docker-compose exec rdb ls -d $dump_dir
dc_exit_code=$?
set +x
if [ $dc_exit_code -ne 0 ]; then
  echo "Bad path. It should be a path *inside the container* too. Bye"
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
echo "Done importing tables. Now importing uploaded files: ... No, already done via cURL."
echo

#  set -x
#  pushd .
#  cd "$dump_dir/uploads/public"
#  set +x
#  echo
#  echo 'Next:  for hash_path in $(find . -type f); do ... mkdir ... cp $hash_path ...  ; done'
#  echo
#  for hash_path in $(find . -type f); do
#    # The files are in paths like  ./1/a/bc/defghijk56789...def.jpg
#    # so we need to first create the ./1/a/bc/ directory, then copy the file:
#    hash_dir=$(dirname "$hash_path")
#    mkdir -p "$hash_dir"
#    cp  --no-clobber --no-dereference --preserve=all  "$hash_path"  "$hash_dir/"
#  done
#  set -x
#  popd
#  set +x


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

