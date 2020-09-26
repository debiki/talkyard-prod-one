#!/bin/bash

# This prints admin one-time login links, and admin reset password links,
# generated via:  http://ty-server/-/admin-login
# or via the Reset Password buttons.
#
# This is useful, if email hasn't yet been configured. Then one
# can login as root, and run this script instead.
#
# Sync with this: [GETADMLNK] and [RSTPWDLNK].

dc="/usr/local/bin/docker-compose"

db_user="$1"

if [ -z "$db_user" ]; then
  db_user="talkyard"
fi

# Set  pager=off  otherwise psql prints "More..." and waits for you to
# hit Space.
psql="psql -P pager=off $db_user $db_user"


# Print admin emails, in case one doesn't remember one's admin email — e.g.
# after migrating from Talkyard.net to self hosted:

admin_addrs=$($dc exec rdb $psql -c "
    select site_id, primary_email_addr, username, full_name
    from users3
    where
      is_admin
      -- Exclude System and Sysbot.
      and user_id >= 100
    order by site_id asc, username asc
    ")

echo
echo "First, a tips:"
echo "To generate admin login links, go to:  https://your-talkyard-server/-/admin-login"
echo "and type your admin email."
echo
echo "Here're the admin email addresses:"
echo
echo "$admin_addrs"
echo


# Print admin one time login links.

echo "Looking in $db_user's database for admin login link emails"
echo "and reset password emails ..."

emails=$($dc exec rdb $psql -c "
    select
       -- Remove newlines, so can count and grep properly.
       -- (Need \\ not \, because Bash eats one.)
       regexp_replace(body_html, '[\\n\\r]+', ' ', 'g' ) || '\n'
    from emails_out3
    where
      -- This is EmailType.ResetPassword = 22 and OneTimeLoginLink = 23.
      type in (22, 23)
      -- One day should be enough?
      and sent_on > now_utc() - interval '1 day'
      order by sent_on asc
      limit 22
    ")


# Sync with the email generating code [ADMLOGINEML].
name_urls=$(echo "$emails" | \
    sed -nr 's#.*>(Hi [^<]+).*(https?://[^"]+).*$#  \1  \2#p')

if [ -z "$name_urls" ]; then
  echo
  echo "Found nothing."
else
  how_many=$(echo "$name_urls" | wc --lines)
  echo
  echo "Found $how_many recent admin login or reset password links, most recent last:"
  echo
  echo "$name_urls"
  echo "                                    ^---- this last link is the most recent"
  echo
  echo "Copy-paste the links into your browser address bar."
  echo "Each link works only once."
fi

echo
