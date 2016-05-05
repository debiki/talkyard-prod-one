Effective Discussions — Production Installation
================

Please read the license (at the end of this page): all this is provided "as-is"
without any warranty of any kind. The software is rather untested and the risk
that something will break and that you'll lose data, is relatively high. Also,
these instructions and config files have not been so very tested. They might be
wrong or misleading.

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
    curl -L https://github.com/docker/compose/releases/download/1.7.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # This should say "docker-compose version 1.7.0 ..." (or later):
    docker-compose -v

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

Now we're done with the preparations. Time to install Effective Discussions:


Installation instructions
----------------

Git-clone this repo, edit config files and memory, and `run docker-compose up`. Like so:

    cd /opt/
    git clone https://github.com/debiki/ed-prod-one.git ed
    cd ed

    nano play-conf/prod.conf  # edit all config values in the Required Settings section
    nano docker-compose.yml   # edit the database password

    # Depending on how much RAM your server has, choose one of these files:
    # mem/0.6g.yml, mem/1g.yml, mem/2g.yml, mem/3.6g.yml, ... and so on.
    # and copy it to ./docker-compose.override.yml.
    #
    # For example, if you're using a Google Compute Engine micro instance, with 0.6 GB RAM:
    # cp mem/0.6g.yml docker-compose.override.yml
    #
    # ... oops but currently 0.6 GB is too little mem. Try 2G instead. 0.6 should work,
    # why not? but Play just gets OOM-killed by Linux. Perhaps I have hardcoded some
    # too-large in-memory caches?

    # Then start Effective Discussions: (it'll restart on reboot)
    # This might take one or a few minutes (to download Docker images).
    docker-compose up -d

And point your browser to http://your-ip-address, or http:\//hostname.


Importing a backup
----------------

You can import a Postgres database backup like so:

    zcat /opt/ed-backups/backup-file.gz | docker exec -i edp_postgres_1 psql postgres postgres

(If you've renamed the Docker project name in the `.env` file, then change
`edp_` above to the new name.)

You can login to Postgres like so:

    docker-compose exec postgres psql postgres postgres  # as user 'postgres'
    docker-compose exec postgres psql ed ed              # as user 'ed'


Backups and upgrades
----------------

Upgrading means fetching the lates Docker images, and restarting. When you do
this, your forum will unavailable for a short while (when the backup script runs).

    cd /opt/ed/
    docker-compose pull      # downloads the latest version
    docker-compose down      # shut down the old version...
    #./backup-everything.sh /opt/ed-backups  # todo
    docker-compose up -d     # ...start the new version.

And copy the contents in /opt/ed-backups elsewhere, regularly:

todo: crontab & rsync instructions


Automatic upgrades
----------------

? a script that checks for new images, pulls, backs up & restarts, automatically ?


Troubleshooting and debugging
----------------

? save Java crash dumps in ./play-crash
+ tips about how to run jmap? or view in jvisualvm + Idea? jmap -heap PID

How to connect VisualVM

Tips about how to view logs: all logs, app specific logs.

How to jump into a Docker container.

How to connect a debugger: open Docker port, then connect via SSH tunnel (assuming a firewall blocks the port on the host)

How to open console in Chroem, view messages & post to the E.D. help forum.

View CPU & memory usage: `./stats.sh`


License
----------------

The MIT license (and it's for the instructions and the config files in this
repository only, not for any Effective Discussions source code.)

See [LICENSE.txt](LICENSE.txt)
