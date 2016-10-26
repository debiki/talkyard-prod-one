Effective Discussions (ED) — Production Installation
================

Warning 1: As of now, don't use this, unless you understand Git and Docker (or
want to take risks & learn).

Details: 1) You might run into Git edit conflicts, if you and I change the same
file.  Also 2) I'm thinking about somehow switching from Docker to CoreOS' rkt,
because rkt doesn't require you to have root permissions. — If those previous
words and phrases sound unfamiliar/confusing to you, then you'll fairly likely
run into unsurmountable problems later on.

Warning 2: Please read the license (at the end of this page): all this is
provided "as-is" without any warranty of any kind. This software is still under
development — there might be bugs, including security bugs.

Feel free to tell me about problems you find; post a Problem topic here:
http://www.effectivediscussions.org/forum/latest/support


Preparation
----------------

### Get a server

Provision an Ubuntu 16.04 server with at least 2 GB RAM. Here are two good
places to hire servers:

- Digital Ocean: https://www.digitalocean.com/
  Easy to use.

- Google Compute Engine: https://cloud.google.com/compute/
  For advanced users. You should be a company, because Google says you should pay taxes yourself.

The server should be amd64, not ARM. So you cannot use Scaleway's bare-metal
ARM servers.

### Install Docker

Ssh into the server and install Docker-Engine 1.11+ (perhaps 1.10+ will work
too, haven't tested) and Docker-Compose 1.8+ (1.6 won't work).

    # This should say "docker-compose version 1.8.0 ..." (or later):
    docker-compose -v

### Configure Ubuntu

Optimize system config, and make the ElasticSearch Docker container work:
(copy-paste this whole text block and run it as one single command. Not one line at a time.)


    cat <<EOF >> /etc/sysctl.conf

    ###################################################################
    # EffectiveDiscussions settings
    #
    vm.swappiness=1            # turn off swap, default = 60
    net.core.somaxconn=8192    # Up the max backlog queue size (num connections per port), default = 128
    vm.max_map_count=262144    # ElasticSearch requires (at least) this, default = 65530
    EOF


Then reload the system config:

    sysctl --system


Simplify troubleshooting:

    cat <<EOF >> ~/.bashrc

    ###################################################################
    export HISTCONTROL=ignoredups
    export HISTCONTROL=ignoreboth
    export HISTSIZE=10100
    export HISTFILESIZE=10100
    export HISTTIMEFORMAT='%F %T %z  '
    EOF


Configure a firewall and automatic security upgrades:

    # Configure a firewall: (not needed if you're using Google Compute Engine)
    ufw allow 22
    ufw allow 80
    ufw allow 443
    ufw enable  # will ask you to confirm

    # Make the firewall work with Docker: (not needed in Google Compute Engine)
    vi /etc/default/ufw # change forward policy to accept: DEFAULT_FORWARD_POLICY="ACCEPT"
    ufw allow 2375/tcp  # Docker needs this port
    ufw reload

    # Automatically apply OS security patches.
    apt-get install unattended-upgrades
    apt-get install update-notifier-common
    cat <<EOF > /etc/apt/apt.conf.d/20auto-upgrades
    APT::Periodic::Update-Package-Lists "1";
    APT::Periodic::Unattended-Upgrade "1";
    Unattended-Upgrade::Automatic-Reboot "true";
    EOF


And why not start using any hardware random number generator, in case the server has one:

    apt install rng-tools


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
    nano conf/app/play.conf   # edit all config values in the Required Settings section
    nano docker-compose.yml   # edit the database password

    # Depending on how much RAM your server has, choose one of these files:
    # mem/0.6g.yml, mem/1g.yml, mem/2g.yml, mem/3.6g.yml, ... and so on.
    # and copy it to ./docker-compose.override.yml. For example, if you're using
    # a Digital Ocean server with 2 GB RAM:
    #
    #   cp mem/2g.yml docker-compose.override.yml

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

Upgrade manually like so:

    cd /opt/ed/
    ./upgrade-backup-restart.sh  # TODO check if there is no new version, then do nothing


### Automatic upgrades

A cron job that runs `./upgrade-backup-restart.sh` randomly once a day? once per hour?



Backups
----------------

### Importing a backup

You can import a Postgres database backup like so:

    zcat /opt/ed-backups/backup-file.gz | docker exec -i edp_rdb_1 psql postgres postgres

(If you've renamed the Docker project name in the `.env` file, then change
`edp_` above to the new name.)

You can login to Postgres like so:

    docker-compose exec rdb psql postgres postgres  # as user 'postgres'
    docker-compose exec rdb psql ed ed              # as user 'ed'


### Manual backups

You should have configured automatic backups already, see the Installation
Instructions section above. In any case, you can backup manually like so:

    cd /opt/ed/
    ./backup.sh manual


### Copy backups elsewhere

You should copy the backups to a safety backup server, regularly. Otherwise, if your main server suddenly disappears, or someone breaks into it and ransomware-encrypts everything — then you'd lose all your data.

See docs/copy-backups-elsewhere.md.



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



Directories
----------------

- `conf/`: Container config files, mounted read-only in the containers. Can add to a Git repo.

- `data/`: Directories mounted read-write in the containers (and sometimes read-only too).
            Should probably add to any Git repo.



License
----------------

The MIT license (and it's for the instructions and the config files in this
repository only, not for any Effective Discussions source code.)

See [LICENSE.txt](LICENSE.txt)

<!-- vim: set et ts=2 sw=2 tw=0 fo=r : -->
