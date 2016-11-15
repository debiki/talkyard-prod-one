#!/bin/bash

# Delete old daily and weekly dumps.
# (For now, never delete monthly dumps.)

backup_dir=/opt/ed-backups
echo "`date '+%F %H:%M'` Searching for old backups to delete in $backup_dir/..."
echo "Doing nothing. Script not yet implemented. Try 'git fetch origin' and see if there's something new."
echo

# Fix later ...
# find $backup_dir -daystart -mtime 13 -name "*-postgres.sql.gz'  -printf 'Could delete daily dump file:  %p\n'

# Keep daily backups 5 days. Then delete 2/3 backups for the next week. Then keep 1/10 backups for the next two months. Keep monthly backups for a year.
# regex: grep -v 'T20..-..-01' — keep monthly backups
# regex: grep -v 'T20..-..-[012]1' — keep one in ten backups: the 01'th, 11'th, 21'th (not the 31'th though)
# regex: grep -v 'T20..-..-[012][148]' — keep 3 of 10 backups.

# echo "Done."
