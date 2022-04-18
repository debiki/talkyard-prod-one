#!/bin/bash

if [ $# -ne 2 ]; then
  echo "Usage: $0 database site_id"  #  /path/to/dump/dir/in-the-container"
  echo
  echo "E.g.:  $0 talkyard 123"  # /var/log/postgresql/site-121/talkyard-dump-2022-04-17"
  echo
  exit 1
fi

site_id=$2
#host_dest_dir=$2

when="`date '+%FT%H%MZ' --utc`"
#when="`date '+%F' --utc`"  # for now

script_path=$0

pg_database="$1"
pg_user="postgres"

host_parent_dir="/home/user/styd/d9/volumes/rdb-logs"

if [ ! -d "$host_parent_dir" ]; then
  echo "Error: No such directory:  $host_parent_dir"
  echo "Bye."
  exit 1
fi

backup_name="talkyard-site-$site_id-dump-$when"
sub_dir="site-$site_id/$backup_name"
host_dest_dir="$host_parent_dir/$sub_dir"

sudo rm -fr $host_dest_dir
sudo mkdir -p $host_dest_dir/tables
sudo mkdir -p $host_dest_dir/uploads

# Make writable to Postgres running in the container:
sudo chmod -R ugo+w $host_dest_dir/tables
# Hmm maybe not needed?:
sudo chmod -R ugo+w $host_dest_dir/uploads

container_dir="/var/log/postgresql/$sub_dir"
tables_dir="$container_dir/tables"   # in the container


# uploads_dir="./data/uploads"
# if [ ! -d "$uploads_dir" ]; then
#   # We're testing on localhost, dev server?
#   uploads_dir="./volumes/uploads"
# fi
#
# if [ ! -d "$uploads_dir" ]; then
#   echo
#   echo "Error: Cannot see any uploads dir,"
#   echo "   not:  ./data/uploads  nor:  ./volumes/uploads"
#   echo
#   echo "You should be in directory: /opt/talkyard/  (or a dev dir on localhost). Bye."
#   echo
#   exit 1
# fi


# Copy the table structures — but not any contents. Since we want site $site_id only
# we'll need to copy its contents in individual COPY commands.
#
# Not needed:  --clean --if-exists,  since the importer script drops the
# whole  talkyard_imported  database anyway.
#
# --no-owner results in a script that can be restored by any user,
# and will give that user ownership of the stuff in the dump.
#
# We cannot add a comment on plpgsql — it's not the current user's object,
# would log a harmless permission error when importing.
#
sudo /usr/local/bin/docker-compose exec -T rdb pg_dump $pg_database --username=postgres --schema-only --no-owner \
    | sed -r 's/^COMMENT ON EXTENSION plpgsql .*$/-- skip, would fail, not our obj: \0/' \
    | sudo tee $host_dest_dir/database-schema.sql > /dev/null


# Generate a script that copies the table contents:

sudo tee "$host_dest_dir/copy-tables-to-files.sql" > /dev/null << EOF
-- This file copies Talkyard site $site_id PostgreSQL database tables.
-- It was auto generated on: $when
-- by running:  $0 $@
--
-- To run this script, do:
--
--   docker-compose exec rdb psql $pg_database $pg_user -f $container_dir/copy-tables-to-files.sql
--
-- It'll then save copies of the tables in files ./tables/<table-name>.copy.txt
-- (the tables will be from the same database transaction).

-- Just one of these will work — Flyway renamed the table [flyw_tbl]. So do outside
-- the transaction below, otherwise the error, when copying the non-existent one,
-- makes the tx fail. (These tables are changed only when the server shuts down
-- and restart-upgrades itself, so doesn't need to be in the tx.)
--
copy schema_version         to '$tables_dir/schema_version.copy.txt';
copy flyway_schema_history  to '$tables_dir/flyway_schema_history.copy.txt';


start transaction  isolation level serializable  read only;

-- Don't forget to incl new tables here.  [7KUW0ZT2]
copy (select * from alt_page_ids3             where site_id   = $site_id) to '$tables_dir/alt_page_ids3.copy.txt';
copy (select * from api_secrets3              where site_id   = $site_id) to '$tables_dir/api_secrets3.copy.txt';
copy (select * from audit_log3                where site_id   = $site_id) to '$tables_dir/audit_log3.copy.txt';
-- skip:            backup_test_log3          where site_id   = $site_id) to '$tables_dir/backup_test_log3.copy.txt';
copy (select * from blocks3                   where site_id   = $site_id) to '$tables_dir/blocks3.copy.txt';
copy (select * from categories3               where site_id   = $site_id) to '$tables_dir/categories3.copy.txt';
copy (select * from drafts3                   where site_id   = $site_id) to '$tables_dir/drafts3.copy.txt';
copy (select * from emails_out3               where site_id   = $site_id) to '$tables_dir/emails_out3.copy.txt';
-- handled above:   flyway_schema_history
copy (select * from group_participants3       where site_id   = $site_id) to '$tables_dir/group_participants3.copy.txt';
copy (select * from guest_prefs3              where site_id   = $site_id) to '$tables_dir/guest_prefs3.copy.txt';
copy (select * from hosts3                    where site_id   = $site_id) to '$tables_dir/hosts3.copy.txt';
copy (select * from identities3               where site_id   = $site_id) to '$tables_dir/identities3.copy.txt';
copy (select * from idps_t                    where site_id_c = $site_id) to '$tables_dir/idps_t.copy.txt';
copy (select * from index_queue3              where site_id   = $site_id) to '$tables_dir/index_queue3.copy.txt';
copy (select * from invites3                  where site_id   = $site_id) to '$tables_dir/invites3.copy.txt';
copy (select * from link_previews_t           where site_id_c = $site_id) to '$tables_dir/link_previews_t.copy.txt';
copy (select * from links_t                   where site_id_c = $site_id) to '$tables_dir/links_t.copy.txt';
copy (select * from notices_t                 where site_id_c = $site_id) to '$tables_dir/notices_t.copy.txt';
copy (select * from notifications3            where site_id   = $site_id) to '$tables_dir/notifications3.copy.txt';
copy (select * from page_html3                where site_id   = $site_id) to '$tables_dir/page_html3.copy.txt';
copy (select * from page_notf_prefs3          where site_id   = $site_id) to '$tables_dir/page_notf_prefs3.copy.txt';
copy (select * from page_paths3               where site_id   = $site_id) to '$tables_dir/page_paths3.copy.txt';
copy (select * from page_popularity_scores3   where site_id   = $site_id) to '$tables_dir/page_popularity_scores3.copy.txt';
copy (select * from page_users3               where site_id   = $site_id) to '$tables_dir/page_users3.copy.txt';
copy (select * from pages3                    where site_id   = $site_id) to '$tables_dir/pages3.copy.txt';
copy (select * from perms_on_pages3           where site_id   = $site_id) to '$tables_dir/perms_on_pages3.copy.txt';
copy (select * from post_actions3             where site_id   = $site_id) to '$tables_dir/post_actions3.copy.txt';
copy (select * from post_read_stats3          where site_id   = $site_id) to '$tables_dir/post_read_stats3.copy.txt';
copy (select * from post_revisions3           where site_id   = $site_id) to '$tables_dir/post_revisions3.copy.txt';
copy (select * from post_tags3                where site_id   = $site_id) to '$tables_dir/post_tags3.copy.txt';
copy (select * from posts3                    where site_id   = $site_id) to '$tables_dir/posts3.copy.txt';
copy (select * from review_tasks3             where site_id   = $site_id) to '$tables_dir/review_tasks3.copy.txt';
-- handled above:   schema_version
copy (select * from sessions_t                where site_id_c = $site_id) to '$tables_dir/sessions_t.copy.txt';
copy (select * from settings3                 where site_id   = $site_id) to '$tables_dir/settings3.copy.txt';
copy (select * from sites3                    where id        = $site_id) to '$tables_dir/sites3.copy.txt';
copy (select * from spam_check_queue3         where site_id   = $site_id) to '$tables_dir/spam_check_queue3.copy.txt';
copy (select * from tag_notf_levels3          where site_id   = $site_id) to '$tables_dir/tag_notf_levels3.copy.txt';
copy (select * from tags_t                    where site_id_c = $site_id) to '$tables_dir/tags_t.copy.txt';
copy (select * from tagtypes_t                where site_id_c = $site_id) to '$tables_dir/tagtypes_t.copy.txt';
copy (select * from upload_refs3              where site_id   = $site_id) to '$tables_dir/upload_refs3.copy.txt';
-- special case:    uploads3  — see below.
copy (select * from user_emails3              where site_id   = $site_id) to '$tables_dir/user_emails3.copy.txt';
copy (select * from user_stats3               where site_id   = $site_id) to '$tables_dir/user_stats3.copy.txt';
copy (select * from user_visit_stats3         where site_id   = $site_id) to '$tables_dir/user_visit_stats3.copy.txt';
copy (select * from usernames3                where site_id   = $site_id) to '$tables_dir/usernames3.copy.txt';
copy (select * from users3                    where site_id   = $site_id) to '$tables_dir/users3.copy.txt';
copy (select * from webhook_reqs_out_t        where site_id_c = $site_id) to '$tables_dir/webhook_reqs_out_t.copy.txt';
copy (select * from webhooks_t                where site_id_c = $site_id) to '$tables_dir/webhooks_t.copy.txt';

-- Uploaded files.
copy (
    with hps as (
        select avatar_tiny_hash_path as hp from users3
            where site_id = $site_id and avatar_tiny_hash_path is not null
        union
        select avatar_small_hash_path as hp from users3
            where site_id = $site_id and avatar_small_hash_path is not null
        union
        select avatar_medium_hash_path as hp from users3
            where site_id = $site_id and avatar_medium_hash_path is not null
        union
        select hash_path hp from upload_refs3
            where site_id = $site_id
        )
    select distinct uploads3.*
    from uploads3 inner join hps on uploads3.hash_path = hps.hp
  )
  to '$tables_dir/uploads3.copy.txt';


commit;

EOF


# Generate list of uploaded files to copy:
#
#  --tuples-only makes psql exclude colum headers — will only print the hash paths.
#  --no-align  makes psql skip leading ' ' spaces.
#  But this: --quiet  apparently not needed.
#
# wait, done via cURL this time:
#
# sudo /usr/local/bin/docker-compose exec -T rdb psql $pg_database $pg_user \
#     --tuples-only --no-align \
#     -c "
#       select avatar_tiny_hash_path as hp from users3
#           where site_id = $site_id and avatar_tiny_hash_path is not null
#       union
#       select avatar_small_hash_path as hp from users3
#           where site_id = $site_id and avatar_small_hash_path is not null
#       union
#       select avatar_medium_hash_path as hp from users3
#           where site_id = $site_id and avatar_medium_hash_path is not null
#       union
#       select hash_path hp from upload_refs3
#           where site_id = $site_id
#     " \
#     | sudo tee $host_dest_dir/uploads-to-copy.txt > /dev/null
#


# Generate a script that restores the table contents:

sudo tee "$host_dest_dir/copy-files-to-tables.sql" > /dev/null << EOF
-- This file copies Talkyard site $site_id PostgreSQL database tables.
-- It was auto generated on: $when
-- by running:  $0 $@
--
-- To run this script, do:
--
--   docker-compose exec rdb psql $pg_database $pg_user -f $container_dir/copy-files-to-tables.sql
--
-- It'll then copy the table contents in the files ./tables/*.copy.txt
-- into the database, in a single transaction.

-- Bug workaround, forgot to make these deferrable:
alter table page_popularity_scores3 alter constraint pagepopscores_r_pages deferrable;
alter table perms_on_pages3 alter constraint permsonpages_r_cats deferrable;
alter table perms_on_pages3 alter constraint permsonpages_r_pages deferrable;
alter table perms_on_pages3 alter constraint permsonpages_r_people deferrable;
alter table perms_on_pages3 alter constraint permsonpages_r_posts deferrable;


-- Only one of these will work, and doesn't need to be in the transaction below,
-- so let's do here before the tx:  [flyw_tbl]
copy schema_version         from '$tables_dir/schema_version.copy.txt';
copy flyway_schema_history  from '$tables_dir/flyway_schema_history.copy.txt';



start transaction  isolation level serializable  read write  deferrable;

set constraints all deferred;

-- Disable triggers: (except for replica triggers, but there are none)
set session_replication_role = replica;

-- To reenable: (but no need to do that, we'll just exit the script)
-- set session_replication_role = default;


-- Don't forget to incl new tables here.  [7KUW0ZT2]
copy alt_page_ids3             from '$tables_dir/alt_page_ids3.copy.txt';
copy api_secrets3              from '$tables_dir/api_secrets3.copy.txt';
copy audit_log3                from '$tables_dir/audit_log3.copy.txt';
-- skip: backup_test_log3
copy blocks3                   from '$tables_dir/blocks3.copy.txt';
copy categories3               from '$tables_dir/categories3.copy.txt';
copy drafts3                   from '$tables_dir/drafts3.copy.txt';
copy emails_out3               from '$tables_dir/emails_out3.copy.txt';
-- handled above:  flyway_schema_history
copy group_participants3       from '$tables_dir/group_participants3.copy.txt';
copy guest_prefs3              from '$tables_dir/guest_prefs3.copy.txt';
copy hosts3                    from '$tables_dir/hosts3.copy.txt';
copy identities3               from '$tables_dir/identities3.copy.txt';
copy idps_t                    from '$tables_dir/idps_t.copy.txt';
copy index_queue3              from '$tables_dir/index_queue3.copy.txt';
copy invites3                  from '$tables_dir/invites3.copy.txt';
copy link_previews_t           from '$tables_dir/link_previews_t.copy.txt';
copy links_t                   from '$tables_dir/links_t.copy.txt';
copy notices_t                 from '$tables_dir/notices_t.copy.txt';
copy notifications3            from '$tables_dir/notifications3.copy.txt';
copy page_html3                from '$tables_dir/page_html3.copy.txt';
copy page_notf_prefs3          from '$tables_dir/page_notf_prefs3.copy.txt';
copy page_paths3               from '$tables_dir/page_paths3.copy.txt';
copy page_popularity_scores3   from '$tables_dir/page_popularity_scores3.copy.txt';
copy page_users3               from '$tables_dir/page_users3.copy.txt';
copy pages3                    from '$tables_dir/pages3.copy.txt';
copy perms_on_pages3           from '$tables_dir/perms_on_pages3.copy.txt';
copy post_actions3             from '$tables_dir/post_actions3.copy.txt';
copy post_read_stats3          from '$tables_dir/post_read_stats3.copy.txt';
copy post_revisions3           from '$tables_dir/post_revisions3.copy.txt';
copy post_tags3                from '$tables_dir/post_tags3.copy.txt';
copy posts3                    from '$tables_dir/posts3.copy.txt';
copy review_tasks3             from '$tables_dir/review_tasks3.copy.txt';
-- handled above:  schema_version
copy sessions_t                from '$tables_dir/sessions_t.copy.txt';
copy settings3                 from '$tables_dir/settings3.copy.txt';
copy sites3                    from '$tables_dir/sites3.copy.txt';
copy spam_check_queue3         from '$tables_dir/spam_check_queue3.copy.txt';
copy tag_notf_levels3          from '$tables_dir/tag_notf_levels3.copy.txt';
copy tags_t                    from '$tables_dir/tags_t.copy.txt';
copy tagtypes_t                from '$tables_dir/tagtypes_t.copy.txt';
copy upload_refs3              from '$tables_dir/upload_refs3.copy.txt';
copy uploads3                  from '$tables_dir/uploads3.copy.txt';
copy user_emails3              from '$tables_dir/user_emails3.copy.txt';
copy user_stats3               from '$tables_dir/user_stats3.copy.txt';
copy user_visit_stats3         from '$tables_dir/user_visit_stats3.copy.txt';
copy usernames3                from '$tables_dir/usernames3.copy.txt';
copy users3                    from '$tables_dir/users3.copy.txt';
copy webhook_reqs_out_t        from '$tables_dir/webhook_reqs_out_t.copy.txt';
copy webhooks_t                from '$tables_dir/webhooks_t.copy.txt';



-- Talkyard is multitenant. Let's make the exported site the main site,
-- now when importing it, that is, give it site id 1:

-- Don't forget to incl new tables here.  [7KUW0ZT2]
update alt_page_ids3             set site_id   = 1 where site_id   <> 1;
update api_secrets3              set site_id   = 1 where site_id   <> 1;
update audit_log3                set site_id   = 1 where site_id   <> 1;
-- skip: backup_test_log3
update blocks3                   set site_id   = 1 where site_id   <> 1;
update categories3               set site_id   = 1 where site_id   <> 1;
update drafts3                   set site_id   = 1 where site_id   <> 1;
update emails_out3               set site_id   = 1 where site_id   <> 1;
update group_participants3       set site_id   = 1 where site_id   <> 1;
update guest_prefs3              set site_id   = 1 where site_id   <> 1;
update hosts3                    set site_id   = 1 where site_id   <> 1;
update identities3               set site_id   = 1 where site_id   <> 1;
update idps_t                    set site_id_c = 1 where site_id_c <> 1;
update index_queue3              set site_id   = 1 where site_id   <> 1;
update invites3                  set site_id   = 1 where site_id   <> 1;
update link_previews_t           set site_id_c = 1 where site_id_c <> 1;
update links_t                   set site_id_c = 1 where site_id_c <> 1;
update notices_t                 set site_id_c = 1 where site_id_c <> 1;
update notifications3            set site_id   = 1 where site_id   <> 1;
update page_html3                set site_id   = 1 where site_id   <> 1;
update page_notf_prefs3          set site_id   = 1 where site_id   <> 1;
update page_paths3               set site_id   = 1 where site_id   <> 1;
update page_popularity_scores3   set site_id   = 1 where site_id   <> 1;
update page_users3               set site_id   = 1 where site_id   <> 1;
update pages3                    set site_id   = 1 where site_id   <> 1;
update perms_on_pages3           set site_id   = 1 where site_id   <> 1;
update post_actions3             set site_id   = 1 where site_id   <> 1;
update post_read_stats3          set site_id   = 1 where site_id   <> 1;
update post_revisions3           set site_id   = 1 where site_id   <> 1;
update post_tags3                set site_id   = 1 where site_id   <> 1;
update posts3                    set site_id   = 1 where site_id   <> 1;
update review_tasks3             set site_id   = 1 where site_id   <> 1;

update sessions_t                set site_id_c = 1 where site_id_c <> 1;
update settings3                 set site_id   = 1 where site_id   <> 1;
update sites3                    set id        = 1 where id        <> 1;
update spam_check_queue3         set site_id   = 1 where site_id   <> 1;
update tag_notf_levels3          set site_id   = 1 where site_id   <> 1;
update tags_t                    set site_id_c = 1 where site_id_c <> 1;
update tagtypes_t                set site_id_c = 1 where site_id_c <> 1;
update upload_refs3              set site_id   = 1 where site_id   <> 1;
--     uploads3  has not site id column
update user_emails3              set site_id   = 1 where site_id   <> 1;
update user_stats3               set site_id   = 1 where site_id   <> 1;
update user_visit_stats3         set site_id   = 1 where site_id   <> 1;
update usernames3                set site_id   = 1 where site_id   <> 1;
update users3                    set site_id   = 1 where site_id   <> 1;
update webhook_reqs_out_t        set site_id_c = 1 where site_id_c <> 1;
update webhooks_t                set site_id_c = 1 where site_id_c <> 1;


commit;

EOF



# Lets incl a README:

sudo tee "$host_dest_dir/README-how-import.txt" > /dev/null << EOF

To import, currently, a bit odd, copy this whole directory to your Talkyard
server, and place it here:

  /var/log/postgresql/$sub_dir

because that folder is mounted in Talkyard's Docker database container
(see /opt/talkyard/docker-compose.yml) at the same location.
(Since Postgres runs in a Docker container, the SQL files we'll run, needs
to be accessible inside the container. Some time later, it'll be a
directory like  /opt/talkyard-backup-to-import/  instead.)

Then, still on the Talkyard server, CD to the Talkyard installation dir, and run
this import script — it's in the backup dir currently:  (later, it'll be in
/opt/talkyard/scripts/  instead)

    sudo -i # become root
    cd /opt/talkyard
    $container_dir/import-single-site.sh  $container_dir



That should be it.  That script, import-this-site.sh,  will afterwars tell you
to rename the database 'talkyard_imported' to something else, e.g. to 'talkyard',
and to change the 'talkyard' *user* password to something else.

(A 'talkyard' user gets created by the script, if needed — but if you
have installed Talkyard already, maybe the user already exists;
then, probably you've choosen a password already.)

(So, there's a PostgreSQL *user* named 'talkyard', and a *database* named
'talkyard_imported' that you can rename to 'talkyard' too.)



Just if you're curious, this directory should include:

   import-single-site.sh   — above-mentioned import script

   database-schema.sql     — table definitions, but not contents

   copy-files-to-tables.sql   — inserts the table contents into the database.
                                Reads from the files in the tables/ directory.

   copy-tables-to-files.sql   — copies table contents to the files in the tables/
                                directory. *Has been run already* so you can ignore it.

   uploads-to-copy.txt  —  hash paths, like 1/x/q2/abc4564defrgm7cre5q2skrqu2wukq.jpg,
                           to uploaded files to copy.

   tables/
      +- some-table.copy.txt
      +- other-table.copy.txt
      |
      ... all tables, one file per table, generated via Postgres' like so:
          COPY (SELECT FROM table_name WHERE site_id = $site_id) TO '/the/file.copy.txt';

   uploads/
      +- all uploaded files, by content hash (truncated SHA1 currently)

EOF



# Add the import script. Just for now — until it's in the GitHub repo:

sudo cp modules/ed-prod-one-test/scripts/import-single-site.sh \
   $host_dest_dir/



# Export tables, by running a script we generated above:
# (file path needs to be inside the rdb container)

docker-compose exec rdb psql $pg_database $pg_user -f $container_dir/copy-tables-to-files.sql


# # Export uploads:  (this done on the host, not in any container)  — no, not now.
# 
# for hash_path in $(cat $host_dest_dir/uploads-to-copy.txt) ; do
#   hash_dir=$(dirname "$hash_path")
#   mkdir -p "$host_dest_dir/uploads/public/$hash_dir"
# 
#   # --no-clobber avoids overwriting existing files.
#   # These two are like --archive, but without -R recursive:
#   # --no-dereference avoids following symlinks (there aren't any anyway).
#   # --preserve=all keeps timestamp, author, and (there aren't any) symlinks.
#   #
#   cp  --no-clobber --no-dereference --preserve=all  \
#       "$uploads_dir/public/$hash_path"  "$host_dest_dir/uploads/public/$hash_dir/"
# done


echo
echo "Done. Site $site_id backed up to: $host_dest_dir"
echo
echo "You can tar-gzip it:"
echo
echo "  tar -czf $backup_name.tgz  $host_dest_dir"
echo
echo "And encrypt the tar-gzip archive:  (will ask for an encryption password)"
echo
echo "  openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 100000 -salt \\"
echo "     -in $backup_name.tgz \\"
echo "     -out $backup_name.tgz.enc"
echo

# But the importer script should (of course) be run on another server (the server
# one imports to).  I.e. this script:  $container_dir/copy-files-to-tables.sql.


# Could tar-gzip the archive? then good to use  nice,
# so won't spike the CPU at 100% if there's just one.
#
# Can encrypt:
#
#   openssl enc -aes-256-cbc -md sha512 -pbkdf2 -iter 100000 -salt \
#          -in site-__.tgz -out site-__.tgz.enc
#
# see:  https://unix.stackexchange.com/a/507132
#
