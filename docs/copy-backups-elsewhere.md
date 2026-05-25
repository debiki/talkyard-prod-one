Take regular off-site backups
======================

After you've installed Talkyard, you should regularly copy the backups
to an off-site backup server. Here's a way to do that.

### Create SSH key

On the backup server, preferably located in another datacenter and another
hosting provider (e.g. Upcloud instead of AWS), create an SSH key:

    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_remotebackup -C "Automated remote backup"

You can perhaps skip the passphrase, since the backup server will have
read-only rsync access only, all backups will be available on the backup server
anyway. So a passphrase doesn't give any additional security.


### Install ACL and restricted rsync, rrsync

On the Talkyard server, install ACL (Access Control Lists) and rrsync (restricted rsync):

    apt install acl     # getfacl, setfacl
    apt install rsync   # this installs rrsync too


### rsync keys

Then create a backup user with an `authorized_keys` file that allows restricted rsync:

    # (still on the Talkyard server)
    useradd --create-home remotebackup
    su - remotebackup
    mkdir .ssh
    echo -n 'command="/usr/bin/rrsync -ro /var/opt/backups/talkyard/v1/archives/",no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-X11-forwarding' >> .ssh/authorized_keys

Copy the public key on the backup server:

    # on the backup server:
    cat ~/.ssh/id_remotebackup.pub

    # copy the output

Append the public key to the last line in `authorized_keys` on the Talkyard server:

    # as user remotebackup: (!)
    nano ~/.ssh/authorized_keys

    # append a space and then the stuff you just copied to the last line (which is the only line, if the file was just created).
    # Do not paste it on a new line.

The result should be that the `authorized_keys` file looks like: (and it's a really long line)

    command=..... ssh-rsa AAAA................ Automated remote backup


### Let the backup user access backups

On the Talkyard server, edit the ACL, as root:

    # Let remotebackup access future backups.
    setfacl -R -d -m u:remotebackup:r-X /var/opt/backups/talkyard/v1/archives/

    # Let remotebackup access already existing backups.
    setfacl -R -m u:remotebackup:r-X /var/opt/backups/talkyard/v1/archives/


### Test

On the Talkyard server:

    su remotebackup
    ls -halt /var/opt/backups/talkyard/v1/archives/  # does it work?
    exit # become root again

If there's a Permission Denied error: Check if `remotebackup` has access to
all parent directories: `namei -om /var/opt/backups/talkyard/v1/archives/`,
and check the ACL list:
`getfacl /var/opt/backups/talkyard/v1/archives/`.

On the backup server, test copying backups:

    # replace 'SERVERADDRESS' with your Talkyard server address
    rsync -e "ssh -i $HOME/.ssh/id_remotebackup" -av remotebackup@SERVERADDRESS:. $HOME/talkyard-backups/


### Schedule copying-of-backups

If the above test works, then schedule a cron job to copy backups regularly. Do this on the backup server:

    # again, replace 'SERVERADDRESS' with your Talkyard server address
    crontab -l | { cat; echo '@hourly rsync -e "ssh -i $HOME/.ssh/id_remotebackup" -av remotebackup@SERVERADDRESS:. $HOME/talkyard-backups/ >> $HOME/talkyard-cron.log 2>&1'; } | crontab -

Now you'll have fresh backups of your forum in ~/talkyard-backups/, in case the Talkyard
server disappears.

> Security note: Why do we run the rsync client read-only on the backup server? Well, because
if we were to let the Talkyard server connect and write to the backup server, then
someone who breaks into the Talkyard server could ransomware-encrypt all backups
(that is, encrypt everything and tell you "give me money, only then will I
decrypt your data so you can read it again"). But when the Talkyard server doesn't
have access to the backup server, this cannot happen. Note that it should be
easier to make the backup server safe, because it doesn't need to run the whole
Talkyard tech stack.


### Get an email, if backups stop working

There's two scripts you can copy-paste to the off-site backup server,
to get notified if backups stop working:<!-- [BADBKPEML] -->

- [scripts/offsite-backup-checks/check-talkyard-backups.sh](../scripts/offsite-backup-checks/check-talkyard-backups.sh)
- [scripts/offsite-backup-checks/alert-if-talkyard-backups-bad.sh](../scripts/offsite-backup-checks/alert-if-talkyard-backups-bad.sh)

You could place side-by-side with the off-site backup directory.

Then, open `alert-if-talkyard-backups-bad.sh` and read the instructions about how to
edit that script so you'll get notified if backups stop working.
— You'll need your own email account or transactional email service.

(But you're not supposed to edit `check-talkyard-backups.sh`.)

Test run the script:

    ./alert-if-talkyard-backups-bad.sh  wrong/dir/
    ./alert-if-talkyard-backups-bad.sh  correct/backup/dir/

And see if you get notified when specifying, say, an empty directory.

Run `alert-if-talkyard-backups-bad.sh` daily via Cron (instructions in the script).

