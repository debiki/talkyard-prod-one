Effective Discussions production installation
================

For one single server.

<u>Warning 1:</u> As of now, only use this, if you understand Git and Docker (or
want to take risks & learn).

Details: You might run into Git edit conflicts, if you and I change the same
files. Also I'm thinking about somehow switching from Docker to CoreOS' rkt,
because rkt doesn't require you to have root permissions. — If you find
Docker complicated to use, things might get worse, later.

<u>Warning 2:</u> Please read the license (at the end of this page): all this is
provided "as-is" without any warranty of any kind. This software is still under
development — there might be bugs, including security bugs.

Feel free to report problems and ask questions in [our support forum](http://www.effectivediscussions.org/forum/latest/support).

If you'd like to test install on your laptop / desktop just to test, there's
[a Vagrantfile here](scripts/Vagrantfile), open it in a text editor, and read,
for details.


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

        sudo -i
        cd /opt/
        git clone https://github.com/debiki/ed-prod-one.git ed
        cd ed

1. Install Docker

        ./scripts/install-docker-compose.sh 2>&1 | tee -a ed-maint.log

        # Afterwards, this should say "docker-compose version 1.8.0 ..." (or later):
        docker-compose -v

1. Configure Ubuntu: enable automatic security updates, simplify troubleshooting,
   and make ElasticSearch work:

        ./scripts/configure-ubuntu.sh 2>&1 | tee -a ed-maint.log


1. Start a firewall: (you can skip this if you use Google Cloud Engine; GCE already has a firewall)

        ./scripts/start-firewall.sh 2>&1 | tee -a ed-maint.log


1. Download a submodule that keeps track of the most recent Docker image tag.

        git submodule update --init 2>&1 | tee -a ed-maint.log

1. Edit config files:

        nano conf/app/play.conf   # edit all config values in the Required Settings section
        nano .env                 # edit the database password

   (If you're using a non-standard port, say 8080, then add `ed.port=8080` to `play.conf`.)

1. Depending on how much RAM your server has, choose one of these files:
   mem/1g.yml, mem/2g.yml, mem/3.6g.yml, ... and so on,
   and copy it to ./docker-compose.override.yml. For example, for
   a Digital Ocean server with 2 GB RAM:

        cp mem/2g.yml docker-compose.override.yml

1. Install and start the latest version. This might take a few minutes
   the first time (to download Docker images).

        # This script also installs, although named "upgrade–...".
        ./scripts/upgrade-if-needed.sh 2>&1 | tee -a ed-maint.log

1. Schedule daily backups (including deletion old backups) and automatic upgrades:

        ./scripts/schedule-daily-backups.sh 2>&1 | tee -a ed-maint.log
        ./scripts/schedule-automatic-upgrades.sh 2>&1 | tee -a ed-maint.log

1. Point a browser to the server address, e.g. <http://your-ip-addresss> or <http://www.example.com>
   or <http://localhost>.  In the browser, click _Continue_ and create an admin account
   with the email address you specified when you edited `play.conf` earlier (see above).

   If you didn't configure any email server (in `play.conf`), no
   email-address-verification-email will be sent to you. However, you'll find
   an address verification URL in the server's log file, which you can view
   like so: `sudo docker-compose logs app`. Copy-paste the URL into the
   browser.  You can [send an email again] / [write the URL to the log file
   again] by clicking the _Send email again_ button.


Now you're done. Everything will restart automatically on server reboot.

Next things for you to do:

- Copy backups off-site, regularly. See the Backups section below.
- In the browser, follow the getting-started guide.



Upgrading to newer versions
----------------

If you followed the instructions above — that is, if you ran these scripts:
`./scripts/configure-ubuntu.sh` and `./scripts/schedule-automatic-upgrades.sh`
— then your server should keep itself up-to-date, and ought to require no maintenance,
_until_ ...


... _Until_ one day when I do some unusual tech stack changes, like changing from
Docker to CoreOS rkt, or upgrading PostgreSQL.
Then, you will likely need to do things like `git stash save ; git pull origin ;
git stash pop` and resolve Git edit conflicts, and perhaps run some script.

If you didn't run `./scripts/schedule-automatic-upgrades.sh`, you can upgrade
manually like so:

    sudo -i
    cd /opt/ed/
    ./scripts/upgrade-if-needed.sh 2>&1 | tee -a ed-maint.log



Backups
----------------

### Importing a backup

You can import a Postgres database backup like so: (you need to stop the 'app'
container, otherwise the import will fail because of active database
connections)

    sudo -i
    docker-compose stop app
    zcat /opt/ed-backups/backup-file.gz | docker exec -i edp_rdb_1 psql postgres postgres
    # todo: tee -a ed-maint.log — can I just append that and it'll work??
    docker-compose start app

(If you've renamed the Docker project name in the `.env` file, then change
`edp_` above to the new name.)

You can login to Postgres like so:

    sudo docker-compose exec rdb psql postgres postgres  # as user 'postgres'
    sudo docker-compose exec rdb psql ed ed              # as user 'ed'


### Manual backups

You should have configured automatic backups already, see the Installation
Instructions section above. In any case, you can backup manually like so:

    sudo -i
    cd /opt/ed/
    ./scripts/backup.sh manual 2>&1 | tee -a ed-maint.log


### Copy backups elsewhere

You should copy the backups to a safety backup server, regularly. Otherwise, if your main server suddenly disappears, or someone breaks into it and ransomware-encrypts everything — then you'd lose all your data.

See [docs/copy-backups-elsewhere.md](./docs/copy-backups-elsewhere.md).



Docker mounted directories
----------------

- `conf/`: Container config files, mounted read-only in the containers. Can add to a Git repo.

- `data/`: Directories mounted read-write in the containers (and sometimes read-only too).
            Should probably not add to any Git repo.



License (GPLv2)
----------------

The GNU General Public License, version 2 — and it's for the instructions and
scripts etcetera in this repository only, not for any Effective Discussions
source code or stuff in other repositories.

    Copyright (C) 2016 Kaj Magnus Lindberg

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, version 2 of the License.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

Here's the full license text: [LICENSE-GPLv2.txt](./LICENSE-GPLv2.txt).


<!-- vim: set et ts=2 sw=2 tw=0 fo=r list : -->
