Effective Discussions — Production Installation
================

Please read the license (at the end of this page): all this is provided "as-is"
without any warranty of any kind. The software is rather untested and the risk
that something will break and that you'll lose data, is relatively high. Also,
these instructions and config files have not been so very tested. They might be
wrong or misleading.

Currently I recommend that you don't try this, unless you know how to use Git
and can resolve edit conflicts. Because I will update the files herein, but if
you've edited the same files and lines — then there will be edit conflicts,
which you will need to resolve.

Feel free to tell me about problems you find; post a something-is-broken topic here:
http://www.effectivediscussions.org/forum/latest/support

Perhaps I'll rename all config variables from `debiki.…` to `ed.…`, hmm.


Preparation
----------------

Provision an Ubuntu 16.04 server, ssh into the server and install Docker-Engine
1.11+ (perhaps 1.10+ will work too, haven't tested) and Docker-Compose 1.7+
(1.6 won't work).

As of now, seems you'll need at least 2 GB RAM. But I think 0.6 GB ought to
work fine; I'll look into this later.

Here are two good places to hire servers:

- Google Compute Engine: https://cloud.google.com/compute/
  For advanced users. You should be a company, because Google says you should pay taxes yourself.

- Digital Ocean: https://www.digitalocean.com/
  Easy to use.

(The server should be amd64, not ARM. So you cannot use Scaleway's bare-metal
ARM servers.)

On a totally new & blank Ubuntu 16.04 server, you can install Docker-Engine and
Docker-Compose as follows:

    # from https://docs.docker.com/engine/installation/linux/ubuntulinux/:
    apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
    echo 'deb https://apt.dockerproject.org/repo ubuntu-xenial main' > /etc/apt/sources.list.d/docker.list
    apt-get update

    # Now this should show version 1.11 or later, but not 1.10:
    apt-cache policy docker-engine

    apt-get install linux-image-extra-$(uname -r)
    apt-get install docker-engine
    service docker start

    # Now this should say "Hello from Docker ...":
    docker run hello-world

    # Make everything start automatically on server startup:
    systemctl enable docker

    # Install Docker Compose 1.7+ (see https://github.com/docker/compose/releases/tag/1.7.0 )
    curl -L https://github.com/docker/compose/releases/download/1.7.1/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # This should say "docker-compose version 1.7.0 ..." (or later):
    docker-compose -v


Make Docker work after OS upgrades: (Docker needs you to install some stuff
when the Linux kernel has been upgraded)

    # but this won't work :-(  why not. Nothing happens after reboot (when 'install' is needed)
    # however, @reboot does work, echoing to a file shows it works.

    crontab -l | { cat; echo '@reboot apt-get install linux-image-extra-`uname -r` && sudo modprobe aufs'; } | crontab -


I think you should also configure a firewall and automatic security upgrades:

    # Configure a firewall: (not needed if you're using Google Compute Engine)
    ufw allow 22
    ufw allow 80
    ufw allow 443
    ufw enable  # will ask you to confirm

    # Make the firewall work with Docker: (not needed in Google Compute Engine)
    vi /etc/default/ufw # change forward policy to accept: DEFAULT_FORWARD_POLICY="ACCEPT"
    ufw allow 2375/tcp  # Docker needs this port
    ufw reload

    # Automatically apply OS security patches. I don't think this will cause anything to
    # break, because the whole Effective Discussions stack runs in Docker containers anyway.
    # Some questions will pop up; I suppose you can just click Yes and accept all defaults.
    apt-get install unattended-upgrades
    dpkg-reconfigure --priority=low unattended-upgrades

    # Automatically reboot, if there's some urgent security upgrades that require a reboot:
    # (we'll install the maybe-security-reboot.sh script used below in a moment)
    apt-get install aptitude
    crontab -l | { cat; echo '45 * * * * cd /opt/ed && ./maybe-security-reboot.sh >> cron.log 2>&1'; } | crontab -


Now we're done with the preparations. Time to install Effective Discussions:


Installation instructions
----------------

Git-clone this repo, edit config files and memory, and `run docker-compose up`. Like so:

    cd /opt/
    git clone https://github.com/debiki/ed-prod-one.git ed
    cd ed

    # Download a submodule that keeps track of the most recent Docker tag.
    git submodule update --init

    # Edit config files.
    nano play-conf/prod.conf  # edit all config values in the Required Settings section
    nano docker-compose.yml   # edit the database password

    # Depending on how much RAM your server has, choose one of these files:
    # mem/0.6g.yml, mem/1g.yml, mem/2g.yml, mem/3.6g.yml, ... and so on.
    # and copy it to ./docker-compose.override.yml. For example, if you're using
    # a Google Compute Engine micro instance, with 0.6 GB RAM:
    #
    #   cp mem/0.6g.yml docker-compose.override.yml
    #
    # ... oops but currently 0.6 GB is too little mem. Try 2G instead. 0.6 should work,
    # why not? but Play just gets OOM-killed by Linux. Perhaps I have hardcoded some
    # too-large in-memory caches?

    # Upgrade to the latest version, and start.
    # This might take one or a few minutes the first time (to download Docker images).
    ./upgrade-backup-restart.sh

    # Schedule daily backups, 10 minutes past 02:00
    crontab -l | { cat; echo '10 2 * * * cd /opt/ed && ./backup.sh daily >> cron.log 2>&1'; } | crontab -

    # Delete old backups (so the disk won't fill up).
    crontab -l | { cat; echo '10 4 * * * cd /opt/ed && ./delete-old-backups.sh >> cron.log 2>&1'; } | crontab -

    # You also need to copy backups off-site regularly. See the Backups section below.


Now point your browser to http://your-ip-address, or http:\//hostname and follow
the instructions.

(Everything will restart automatically on server reboot.)


Upgrading to newer versions
----------------

Upgrading means fetching the lates Docker images, backing up, and restarting
everything. When you do this, your forum will unavailable for a short while.

Upgrade manually like so: (this downloads, backups and restarts)

    cd /opt/ed/
    ./upgrade.sh   # TODO check if there is no new version, then do nothing

### Automatic upgrades

A cron job that runs `./upgrade.sh` randomly once a day? once per hour?


Backups
----------------

### Importing a backup

You can import a Postgres database backup like so:

    zcat /opt/ed-backups/backup-file.gz | docker exec -i edp_postgres_1 psql postgres postgres

(If you've renamed the Docker project name in the `.env` file, then change
`edp_` above to the new name.)

You can login to Postgres like so:

    docker-compose exec postgres psql postgres postgres  # as user 'postgres'
    docker-compose exec postgres psql ed ed              # as user 'ed'

### Manual backups

You should have configured automatic backups already, see the Installation
Instructions section above. In any case, you can backup manually like so:

    cd /opt/ed/
    ./backup.sh manual

### Copy backups elsewhere

This'll show you how you can copy the contents in /opt/ed-backups to a safety
backup server:

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


Troubleshooting and debugging
----------------

? save Java crash dumps in ./play-crash
+ tips about how to run jmap? or view in jvisualvm + Idea? jmap -heap PID

How to connect VisualVM

Tips about how to view logs: all logs, app specific logs.

How to jump into a Docker container.

How to connect a debugger: open Docker port, then connect via SSH tunnel (assuming a firewall blocks the port on the host).
If using Google Compute Engine, then ssh tunnel:

    gcloud compute ssh server-name --ssh-flag=-L9999:127.0.0.1:9999 --ssh-flag=-N


How to open console in Chroem, view messages & post to the E.D. help forum.

View CPU & memory usage: `./stats.sh`


License
----------------

The MIT license (and it's for the instructions and the config files in this
repository only, not for any Effective Discussions source code.)

See [LICENSE.txt](LICENSE.txt)

<!-- vim: set et ts=2 sw=2 tw=0 fo=r : -->
