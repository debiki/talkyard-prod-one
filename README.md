Effective Discussions (ED) — Production Installation
================

Warning 1: As of now, only use this, if you understand Git and Docker (or
want to take risks & learn).

Details: You might run into Git edit conflicts, if you and I change the same
files. Also I'm thinking about somehow switching from Docker to CoreOS' rkt,
because rkt doesn't require you to have root permissions. — If those previous
words and phrases sound unfamiliar/confusing to you, then you will likely
run into problems later on. Perhaps not today, but half a year later.

Warning 2: Please read the license (at the end of this page): all this is
provided "as-is" without any warranty of any kind. This software is still under
development — there might be bugs, including security bugs.

Feel free to tell me about problems you find; post a Problem topic here:
http://www.effectivediscussions.org/forum/latest/support



Get a server
----------------

Provision an Ubuntu 16.04 server with at least 2 GB RAM. Here are two good
places to hire servers:

- Digital Ocean: https://www.digitalocean.com/ — easy to use.

- Google Compute Engine: https://cloud.google.com/compute/
  — for advanced users. You should be a company, because Google says you should pay taxes yourself.

(The server should be amd64, not ARM. So you cannot use Scaleway's bare-metal
ARM servers.)


Installation instructions
----------------

1. Git-clone this repo: (you need to do like this for the backup scripts to work)

        cd /opt/
        sudo git clone https://github.com/debiki/ed-prod-one.git ed
        cd ed

1. Install Docker

        sudo ./scripts/install-docker-compose.sh

        # Afterwards, this should say "docker-compose version 1.8.0 ..." (or later):
        docker-compose -v

1. Configure Ubuntu: enable automatic security updates, simplify troubleshooting,
   and make ElasticSearch work:

        sudo ./scripts/configure-ubuntu.sh


1. Start a firewall: (you can skip this if you use Google Cloud Engine; GCE already has a firewall)

        sudo ./scripts/start-firewall.sh


1. Download a submodule that keeps track of the most recent Docker image tag.

        sudo git submodule update --init

1. Edit config files:

        sudo nano conf/app/play.conf   # edit all config values in the Required Settings section
        sudo nano .env                 # edit the database password

1. Depending on how much RAM your server has, choose one of these files:
   mem/1g.yml, mem/2g.yml, mem/3.6g.yml, ... and so on,
   and copy it to ./docker-compose.override.yml. For example, for
   a Digital Ocean server with 2 GB RAM:

        sudo cp mem/2g.yml docker-compose.override.yml

1. Upgrade to the latest version, and start. This might take a few minutes
   the first time (to download Docker images).

        sudo ./scripts/upgrade-backup-restart.sh

1. Schedule daily backups, and deletion old backups:

        sudo ./scripts/schedule-daily-backups.sh

1. Open a browser, go to the website, e.g. http://localhost, or http://www.example.com.
   Sign up with the email address you specified when you edited `play.conf` earlier (see above).

   If you haven't yet configured any email server, no email-address-verification-email was sent to
   you. However, you'll find an address verification URL in the server's log file:
   `sudo docker-compose logs app`. Copy-paste it into the browser.


Now point your browser to <http://your-ip-address> or <http://your.hostname> and follow
the instructions.

Everything will restart automatically on server reboot.


Afterwards: You also need to copy backups off-site regularly. See the Backups section below.


Upgrading to newer versions
----------------

Upgrading means fetching the lates Docker images, backing up, and restarting
everything. When you do this, your forum will unavailable for a short while.

Upgrade manually like so:

    cd /opt/ed/
    ./scripts/upgrade-backup-restart.sh  # TODO check if there is no new version, then do nothing


### Automatic upgrades

A cron job that runs `./scripts/upgrade-backup-restart.sh` randomly once a day? once per hour?



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



Directories
----------------

- `scripts/`: Installation, backup, and upgrade scripts.

- `conf/`: Container config files, mounted read-only in the containers. Can add to a Git repo.

- `data/`: Directories mounted read-write in the containers (and sometimes read-only too).
            Should probably _not_ add to any Git repo.



License
----------------

The MIT license (and it's for the instructions and the config files in this
repository only, not for any Effective Discussions source code.)

See [LICENSE.txt](LICENSE.txt)

<!-- vim: set et ts=2 sw=2 tw=0 fo=r : -->
