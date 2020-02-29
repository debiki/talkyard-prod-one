
Copy backups elsewhere
======================

After you've installed Talkyard, you should copy the backups
to a safety backup server, regularly. That's what this document is about.

(I'd like to simplify all this, by creating an rsync-read-only backup help
Docker container.)


### Create SSH key

On the backup server, preferably located in another datacenter, create a SSH
key:

    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_remotebackup -C "Automated remote backup"

You can perhaps skip the passphrase, since the backup server will have
read-only rsync access only, all backups will be available on the backup server
anyway. So a passhprase doesn't give any additional security.


### Enable restricted rsync, rrsync

On the Talkyard server, enable rrsync:

    zcat /usr/share/doc/rsync/scripts/rrsync.gz > /usr/local/bin/rrsync
    chmod ugo+x /usr/local/bin/rrsync


### rsync keys

Then create a backup user with an `authorized_keys` file that allows restricted rsync:

    # (still on the Talkyard server)
    useradd --create-home remotebackup
    su - remotebackup
    mkdir .ssh
    echo 'command="/usr/local/bin/rrsync -ro /opt/talkyard-backups/archives/",no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-X11-forwarding' >> .ssh/authorized_keys

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


### Test

Now, on the backup server, test copying backups:

    # replace 'SERVERADDRESS' with your Talkyard server address
    rsync -e "ssh -i $HOME/.ssh/id_remotebackup" -av remotebackup@SERVERADDRESS:/ $HOME/talkyard-backups/


### Schedule copying-of-backups

If the above test works, then schedule a cron job to copy backups regularly. Do this on the backup server:

    # again, replace 'SERVERADDRESS' with your Talkyard server address
    crontab -l | { cat; echo '@hourly rsync -e "ssh -i .ssh/id_remotebackup" -av remotebackup@SERVERADDRESS:/ talkyard-backups/ >> cron.log 2>&1'; } | crontab -

Now you'll have fresh backups of your forum in ~/talkyard-backups/, in case the Talkyard
server disappears.

(Why do we run the rsync client read-only on the backup server? Well, because
if we were to let the Talkyard server connect and write to the backup server, then
someone who breaks in to the Talkyard server could ransomware-encrypt all backups
(that is, encrypt everything and tell you "give me money, only then will I
unencrypt your data so you can read it again"). But when the Talkyard server doesn't
have access to the backup server, this cannot happen. Note that it should be
easier to make the backup server safe, because it doesn't need to run the whole
Talkyard tech stack.)


### Get an email, if backups stop working

*NOT YET IMPLEMENTED* ` [BADBKPEML]`, the following does not yet work:

On the remote backup server, copy the contents of the script
[scripts/check-talkyard-backups.sh](../scripts/check-talkyard-backups.sh)
to your home directory. Edit the script and fill in email server (SMTP)
credentials.

Then, test run the script:

    cd $HOME
    ./check-talkyard-backups.sh --send-email-if-bad talkyard-backups/

And test send an email:

    ./check-talkyard-backups.sh --send-test-email

If seems to work, run daily via Cron:

    crontab -l | { cat; echo '@daily ./check-talkyard-backups.sh --send-email-if-bad talkyard-backups/ >> cron.log 2>&1'; } | crontab -

