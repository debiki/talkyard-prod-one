

Talkyrad v1 is a major-major new version of Talkyard, that is, a new epoch.
Previous versions have been v0.YYYY.NNN (e.g. v0.2025.001), newer versions will
be v1.YYYY.NNN (e.g. v1.2025.001).

To upgrade, you'll install Talkyrad v1 side-by-side with v0, take a backup of v0,
shut down v0 (but don't uninstall it). Then, import the backup to v1 and start v1.
— Details further down below.

Why upgrade?
-------------------------

Talkyard v1.2025.001 doesn't add any new features — it only upgrades all components
to more recent versions (upgrades to PostgreSQL 18, ElasticSearch 9, Redis 8,
Debian 12 or 13).
This is good to do, so you'll be using supported versions of the software.

Talkyard >= v1.2025.002 will add new features and bug fixes though (only 001
is a upgrade-all-components but-no-new-features release).

Talkyard v0 will stop getting new features, only bug fixes.

There's also changes to the installation and maintenance scripts,
e.g. optionally encrypted backups.
And we'll start using Docker named volumes by default, instead of bind mounts.


How to upgrade
-------------------------

Upgrade your Operating System to Debian 12 or 13
(Ubuntu 22 or 24 LTS should work too — they're based on Debian 12 and 13).


Backup your existing Talkyard installation, let's name the backup 'beforeV1Upgrade':

```
cd /opt/talkyard
./scripts/backup.sh beforeV1Upgrade
```

Then, shut down Talkyrad v0 — but don't delete anything! Just leave it as-is:
(Note: This uses Docker-Compose v1.)

```
# in /opt/talkyard:
docker-compose down   # using Docker-Compose v1
```


Install Talkyard v1, as per the installation instructions in ../README.md .

Copy configuration files from your v0 installation to v1 — but you'll need to make
some changes:



Restore the backup into Talkyrad v1. Start Talkyrad v1.

Reconfigure the off-site backup script so it backups `/var/opt/backups/`
(instead of `/opt/talkyard-backups/`).

Wait a month or two. All fine? You can delete old v0.


