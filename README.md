Talkyard production installation
================

For one single server.

You should be familiar with Linux, Bash and Git. Otherwise you might run into
problems. For example, there might be Git edit conflicts, if you and we change
the same file — then you need to know how to resolve those edit conflicts.
Also, knowing a bit about Docker containers can be good.

This is beta software; there might be bugs.
You can report problems and ask questions in [our support forum](http://www.talkyard.io/forum/latest/support).

If you'd like to test install on your laptop, there's
[a Vagrantfile here](scripts/Vagrantfile) — open it in a text editor, and read,
for details.

Installation overview: You'll rent a virtual private server (VPS) somewhere, then download
and install Talkyard, then sign up for a send-emails service and configure email settings.
Then optionally configure OpenAuth login for Google, Facebook, Twitter, GitHub.
And off-site backups.

Dockerfiles, build scripts and source code are in another repo: https://github.com/debiki/talkyard.
Have a look in `./docker-compose.yml` for details and links.


Get a server
----------------

Provision an Ubuntu 16.04 server with at least 2 GB RAM. Here are three
places to hire servers:

- Digital Ocean: https://www.digitalocean.com/ — easy to use.

- Google Compute Engine: https://cloud.google.com/compute/
  — for advanced users. You should be a company, because Google says you should pay taxes yourself.

- Scaleway, https://www.scaleway.com/ — inexpensive, just €3, but risky, not so good backups.
  The server should be X86-64, not ARM (so don't use the BareMetal ARM servers).


Installation instructions
----------------

1. Become root and install Git:

        sudo -i
        apt-get update
        apt-get -y install git

1. Download installation scripts: (you need to install in
   `/opt/talkyard/` for the backup scripts to work)

        cd /opt/
        git clone https://github.com/debiki/talkyard-prod-one.git talkyard
        cd talkyard

1. Prepare Ubuntu: install tools, enable automatic security updates, simplify troubleshooting,
   and make ElasticSearch work:

        ./scripts/prepare-ubuntu.sh 2>&1 | tee -a talkyard-maint.log

   (If you don't want to run all stuff in this script, you at least need to copy the
   sysctl `net.core.somaxconn` and `vm.max_map_count` settings in the script to your
   `/etc/sysctl.conf` config file — otherwise, the full-text-search-engine (ElasticSearch)
   won't work. Afterwards, run `sysctl --system` to reload the system configuration.)

   Also do this, to avoid harmless but annoying language-missing warnings:

        export LC_ALL=en_US.UTF-8

1. Install Docker:

        ./scripts/install-docker-compose.sh 2>&1 | tee -a talkyard-maint.log

1. Start a firewall: (and answer Yes to the question you'll get. You can skip this if
   you use Google Cloud Engine; GCE already has a firewall)

        ./scripts/start-firewall.sh 2>&1 | tee -a talkyard-maint.log

1. Edit config files:

        nano conf/app/play.conf   # edit all config values in the Required Settings section
        nano .env                 # edit the database password

   Note:
   - If you don't edit `play.http.secret.key` in file `play.conf`, the server won't start.
   - If you're using a non-standard port, say 8080 (which you do if you're using **Vagrant**),
     then add `talkyard.port=8080` to `play.conf`.

1. Depending on how much RAM your server has (run `free -mh` to find out), choose one of these files:
   mem/1g.yml, mem/2g.yml, mem/3.6g.yml, ... and so on,
   and copy it to ./docker-compose.override.yml. For example, for
   a server with 2 GB RAM:

        cp mem/2g.yml docker-compose.override.yml

1. Install and start the latest version. This might take a few minutes
   the first time (to download Docker images).

        # This script also installs, although named "upgrade–...".
        ./scripts/upgrade-if-needed.sh 2>&1 | tee -a talkyard-maint.log

1. Schedule deletion of old log files, daily backups and deletion old backups,
   and automatic upgrades:

        ./scripts/schedule-logrotate.sh 2>&1 | tee -a talkyard-maint.log
        ./scripts/schedule-daily-backups.sh 2>&1 | tee -a talkyard-maint.log
        ./scripts/schedule-automatic-upgrades.sh 2>&1 | tee -a talkyard-maint.log

1. Point a browser to the server address, e.g. <http://your-ip-addresss> or <http://www.example.com>
   or <http://localhost>. Or <http://localhost:8080> if you're testing with Vagrant.

   In the browser, click _Continue_ and create an admin account
   with the email address you specified when you edited `play.conf` earlier (see above).
   Follow the getting-started guide.

Everything will restart automatically on server reboot.

Next steps:

- Sign up for a send-email-service — see the section just below.
- Send an email to `hello at talkyard.io` so we get your address, and can
  inform you about security issues and major software
  upgrades that might require you to do something manually.
- Copy backups off-site, regularly. See the Backups section below.
- Configure Gmail, Facebook, Twitter, GitHub login,
    by creating OpenAuth apps over at their sites, and adding API keys and secrets
    to `play.conf`. See below, just after the next section, about email.


Configuring email
----------------

If you don't have a mail server already, then sign up for a transactional email
service, for example Mailgun, Elastic Email, SendGrid, Mailjet or Amazon SES.
(Signing up, and verifying your sender email address and domain, is a bit complicated
— nothing you do in five minutes.)

Then, configure email settings in `/opt/talkyard/conf/app/play.conf`, that is, fill in these values:

```
talkyard.smtp.host="..."
talkyard.smtp.port="587"
talkyard.smtp.requireStartTls=true
#talkyard.smtp.tlsPort="465"
#talkyard.smtp.connectWithTls=true
talkyard.smtp.checkServerIdentity=true
talkyard.smtp.user="..."
talkyard.smtp.password="..."
talkyard.smtp.fromAddress="support@your-organization.com"
```

(Google Cloud Engine blocks outgoing ports 587 and 465 (at least it did in the past).
Probably you email provider has made other ports available for you to use,
e.g. Amazon SES: ports 2587 and 2465.)


OpenAuth login
----------------

Probably you want login with Facebook, Gmail and maybe Twitter and GitHub to work. Here's how.

However, we haven't written easy to follow instructions for this yet.
Send us an email: `hello at talkyard.io`, mention OpenAuth, and we'll hurry up.

<small>(There are very very brief instructions in this the markdown source but they might be out of date,
or there might be typos,
so they're hidden unless you are a tech person who knows how to view the source.)</small>

<!-- The "hidden" instructons.
You can try to follow the instructions below, and maybe won't be easy.

The login callbacks that you will need to fill in, are
`http(s)://your.website.com/-/login-auth-callback/NAME` where *NAME* is
one of `google`, `twitter`, `facebook`, `github`.

The "copy-paste" instructions below are for `/opt/talkyard/conf/app/play.conf`,
at the end of the file.

Facebook:

 - Go to https://developers.facebook.com, and sign up or log in
 - Select the **My Apps** menu to the upper right
 - Click **Add New App**
 - Create a *Products | Facebook Login* app. (We should write more about this and
   add screenshots.)
 - Copy-paste the Facebook app id into `#facebook.clientID="..."` and `#facebook.clientSecret="..."`
   (instead of the `...`), and activate ("comment in") each line by removing the `#`.

Gmail:

 - Go to https://console.developers.google.com
 - Click API & Services
 - Click Credentials, create an OAuth app for websites
 - Click Libraries, enable Google+ (not Google+ Domains, don't know what that is)
 - Copy-paste your client ID and secret into `#google.clientID="..."` and `#google.clientSecret="..."`,
   and remove the `#`.

Twitter:
 - Go to https://apps.twitter.com, sign up or log in.
 - Click **Create New App**
 - As callback URL, specify: `https://your.website.com/-/login-auth-callback/twitter`
 - Copy-paste your key and secret into `#twitter.consumerKey="..."` and `#twitter.consumerSecret="..."`,
   and remove the `#`.

GitHub:
 - Log in to GitHub. Click your avatar menu. Then Settings, then Developer Settings, OAuth Apps.
 - Copy-paste your client ID and secret into `#github.clientID="..."` and `#github.clientSecret="..."`,
   and remove the `#`.
-->


Viewing log files
----------------

Change directory to `/opt/talkyard/`.

Then, view the application server logs like so: `./view-logs app`
or `./view-logs -f --tail 30 app`.  
The web server: `tail -f /var/log/nginx/{access,error}.log` (mounted on the Docker host in docker-compose.yml)  
The database: `less /var/log/postgres/LOG_FILE_NAME`  
The search engine: `./view-logs search`.


Upgrading to newer versions
----------------

If you followed the instructions above — that is, if you ran these scripts:
`./scripts/configure-ubuntu.sh` and `./scripts/schedule-automatic-upgrades.sh`
— then your server should keep itself up-to-date, and ought to require no maintenance.

In a few cases you might have to do something manually, when upgrading.
Like, running `git pull` and editing config files, maybe running a shell script.
For us to be able to tell you about this, please send us an email at
`hello at talkyard.io`.

If you didn't run `./scripts/schedule-automatic-upgrades.sh`, you can upgrade
manually like so:

    sudo -i
    cd /opt/talkyard/
    ./scripts/upgrade-if-needed.sh 2>&1 | tee -a talkyard-maint.log



Backups
----------------

### Importing a backup

You can import a Postgres database backup like so: (you need to stop the 'app'
container, otherwise the import will fail because of active database
connections)

    sudo -i
    docker-compose stop app
    zcat /opt/talkyard-backups/BACKUP_FILE.gz \
      | docker exec -i $(docker-compose ps -q rdb) psql postgres postgres \
      | tee -a talkyard-maint.log
    docker-compose start app

Replace `BACKUP_FILE` above with the actual file name.

TODO: Explain how to import the uploaded-files backup archive...

You can login to Postgres like so:

    sudo docker-compose exec rdb psql postgres postgres  # as user 'postgres'
    sudo docker-compose exec rdb psql talkyard talkyard  # as user 'talkyard'


### Backing up, manually

You should have configured automatic backups already, see the Installation
Instructions section above. In any case, you can backup manually like so:

    sudo -i
    cd /opt/talkyard/
    ./scripts/backup.sh manual 2>&1 | tee -a talkyard-maint.log


### Copy backups elsewhere

You should copy the backups to a safety backup server, regularly. Otherwise, if your main server suddenly disappears, or someone breaks into it and ransomware-encrypts everything — then you'd lose all your data.

See [docs/copy-backups-elsewhere.md](./docs/copy-backups-elsewhere.md).



Tips
----------------

If you'll start running out of disk, one reason can be old patches for automatic operating system security updates.
You can delete them to free up disk:

```
sudo apt autoremove --purge
```


Docker mounted directories
----------------

- `conf/`: Container config files, mounted read-only in the containers. Can add to a Git repo.
- `data/`: Directories mounted read-write in the containers (and sometimes read-only too). Not for Git.



License (GPLv2)
----------------

The GNU General Public License, version 2 — and it's for the instructions and
scripts etcetera in this repository only, not for any Talkyard
source code or stuff in other repositories.

    Copyright (c) 2016-2018 Kaj Magnus Lindberg

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
