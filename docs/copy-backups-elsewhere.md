
Copy backups elsewhere
======================

After you've installed EffectiveDiscussions, you should copy the backups
to a safety backup server, regularly. That's what this document is about.

(I'd like to simplify all this, by creating an rsync-read-only backup help
Docker container.)

On the backup server, preferably located in another datacenter, create a SSH
key:

    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_remotebackup -C "Automated remote backup"

You can perhaps skip the passphrase, since the backup server will have
read-only rsync access only, all backups will be available on the backup server
anyway. So a passhprase doesn't give any additional security.

On the EffectiveDiscussions (ED) server, enable rrsync (restricted rsync):

    zcat /usr/share/doc/rsync/scripts/rrsync.gz > /usr/local/bin/rrsync
    chmod ugo+x /usr/local/bin/rrsync

Then create a backup user with an `authorized_keys` file that allows restricted rsync:

    # (still on the ED server)
    useradd -m remotebackup
    su - remotebackup
    mkdir .ssh
    echo 'command="/usr/local/bin/rrsync -ro /opt/ed-backups/",no-agent-forwarding,no-port-forwarding,no-pty,no-user-rc,no-X11-forwarding' >> .ssh/authorized_keys

Copy the public key on the backup server:

    # on the backup server:
    cat ~/.ssh/id_remotebackup.pub

   # copy the output

Append the public key to the last line in `authorized_keys` on the ED server:

    # as user remotebackup: (!)
    nano ~/.ssh/authorized_keys

    # append the stuff you just copied to the last line (which should be the only line).
    # Do not paste it on a new line.

The result should be that the `authorized_keys` file looks like: (and it's a really long line)

    command=..... ssh-rsa AAAA................ Automated remote backup

Now, on the backup server, test to copy backups:

    # replace 'serveraddress' with the server address
    rsync -e "ssh -i .ssh/id_remotebackup" -av remotebackup@serveraddress:/ ed-backups/

If it works, then schedule a cron job to do this regularly: (on the backup server)

    # (replace 'serveraddress' with the server address)
    crontab -l | { cat; echo '@hourly rsync -e "ssh -i .ssh/id_remotebackup" -av remotebackup@serveraddress:/ ed-backups/ >> cron.log 2>&1'; } | crontab -

Now you'll have fresh backups of your forum in ~/ed-backups/, in case the ED
server disappears.

(Why do we run the rsync client read-only on the backup server? Well, because
if we were to let the ED server connect and write to the backup server, then
someone who breaks in to the ED server could ransomware-encrypt all backups
(that is, encrypt everything and tell you "give me money, only then will I
unencrypt your data so you can read it again"). But when the ED server doesn't
have access to the backup server, this cannot happen. Note that it should be
easier to make the backup server safe, because it doesn't need to run the whole
ED tech stack.)




