Risk-Free Upgrades (Blue-Green, Google Cloud)
=========================

You can use this method for major OS upgrades or major Talkyard migrations, e.g. v0 to v1.

For routine updates, we recommend just following the installation instructions,
that is, a daily cron job that calls `scripts/upgrade-if-needed.sh`.

**Important:** Read/skim all steps before you start.
Especially read the **Make backups work again**
and **Rolling back** sections at the end.

<!--
If you use Google Cloud or Amazon AWS, you can upgrade your Talkyard server without any downtime.
It'll be read-only during the upgrade.
This works for other software too, not just Talkyard. For example, to upgrade the
server OS from Debian 11 to 12.
-->


<!--  Wow so much text I wrote!
Not needed
-------------------------

We don't recommend doing this, because usually it's not worth the trouble.
It's simpler to just let `scripts/upgrade-if-needed.sh` run once a day,
and accept one or two minutes downtime once a month or something like that.

(After all, Amazon and CloudFlare have had many hours or almost a day's downtime recently.)

But if you're migrating from Talkyard v0 to v1, or you're upgrading the Operating System,
then this zero-downtime approach makes more sense, because if there's any problem,
you can just _not_ point the IP address to the new server (or point it back to the old),
and your end users won't notice anything. (See below.)

How does it work?
-------------------------

This makes use of multi-disk crash-consistent machine images, which apparently
no other cloud providers than Google Cloud and AWS supports.
-->


Prerequisites
-------------------------

<!-- Need not mention: A Talkyard forum, and a public static IP — too obvious,
otherwise there's nothing to upgrade and they wouldn't be reading this.  -->

- These docs are for Google Cloud. (No docs written for AWS or anything else.)

- Familiarity with Google Cloud, e.g. how to SSH into a VM.

- SSH access to your off-site backup server, if any.

- Know how to edit your hosts file (on your laptop).

- Know how to open your browser's Dev Tools and switch to the Network tab to check
  IP addresses.


Instructions
-------------------------

Note: If you're on Talkyard v0, then, `cd` to `/opt/talkyard` instead of `/opt/talkyard-v1`,
and use `docker-compose` instead of `docker compose`
(the former is Compose v1, the latter Compose v2).


1. **Before**

   1. **Enable Maintenance Mode** which also makes the server read-only.
      SSH into your server, and:

      ```
      cd /opt/talkyard-v1
      sudo docker compose exec rdb psql talkyard talkyard -c \
            'update system_settings_t set maintenance_until_unix_secs_c = 1;'
      ```

      Now the forum should show an Under Maintenance message:

      (screenshot)

1. **Clone the server**

   1. In Google Cloud, go to **Virtual Machines > VM Instances**, and find your VM.

   1. Click the three dots **⋮** next to your VM, then click **Create new machine image**.

       (screenshot)

   1. Once created, go to **Machine Images**, find the new image,
      click **⋮** then click **Create instance**.

   1. Launch the VM in same region and zone as the old VM, with the same machine type.

1. **Verify & Upgrade**

   1. Let's see if the new VM works. Find the IP of the new VM, and
      add it to your laptop's `/etc/hosts`:

      ```
      11.22.33.44  your-forum.example.com
      ```

   1. In a browser, go to `https://your-forum.example.com`
      and open Dev Tools. Switch to the Network tab. Verify that you're
      hitting the IP of the new VM (and not the _old_ VM).

   1. **Upgrade.** SSH into the new VM. Upgrade the forum or the OS.

   1. Do you use a **CDN**? (Content Delivery Network). If so, disable it,
      since it's still configured to access your *old* server.
      Comment out the `talkyard.cdn.origin=...` line in
      `/opt/talkyard-v1/conf/app/play-framework.conf` (in the new VM).

   1. Do some manual testing in the browser, including:
      - Visit: `your-forum.example.com/-/build-info`
        do you see the new (upgraded) Talkyard version number?
      - Post a test topic in a hidden category (e.g. staff-only).
      - Visit:  `your-forum.example.com/-/last-errors` — you see any errors?

1. **Switch Traffic**

   1. Move your forum's IP address from the old VM to the new VM:
      Go to **VPC Network > IP addresses**, find the forum's public IP,
      click **⋮** and **Reassign to another resource**, select the new VM.

   1. Remove the `/etc/hosts` entry (on your laptop).
      Reload web page, look in Dev Tools, the Network tab, and verify you're
      hitting the public IP address of the forum — which now points to the _new_ VM.

   1. Reenable any CDN: comment in `talkyard.cdn.origin=...` — now the CDN works,
      since it'll access your new server (you've moved the IP).

1. **Afterwards**

   1. **Disable Maintenance Mode.** On the new VM:

      ```
      cd /opt/talkyard-v1
      sudo docker compose exec rdb psql talkyard talkyard -c \
            'update system_settings_t set maintenance_until_unix_secs_c = null;'
      ```

      Reload the web page. Did the maintenance message disappear?

   1. **Shut down** the old VM, but don't delete it (wait a month).

      Reload the web page — still works?

   <!-- Network tags like  https-server,  http-server  should carry over,
   Gemini 3 Fast says. Don't think it's worth mentioning, since will just work,
   and organizations with any complex firewall network should have their
   own routines & knowledge anyway.  -->

1. **Make backups work again**

   If you copy backups off-site using rsync (as described in `copy-backups-elsewhere.md`),
   this now fails with a _"REMOTE HOST IDENTIFICATION HAS CHANGED"_ warning,
   because Google Cloud will have given the new VM a different SSH host key
   (even though it's a machine image of the old). Therefore:

   1. SSH into the remote backup server. Remove the old key, accept the new:

      ```
      ssh-keygen -R your-forum.example.com  # removes old key
      ssh your-forum.example.com            # accepts new. Type 'yes' when prompted
      ```

   1. Type `crontab -l` to list cron jobs (on the remote backup server).
      Copy-paste the line that `rsync`s the Talkyard backups,
      and run it manually, verify works fine.

   Also, make sure you've configured Google Cloud to backup the new VM regularly
   (if you want to do that in addition to Talkyard's own backups).

### Rolling back

If there's any problem, either don't reassign the IP, or move it back to the old VM.
Disable Maintenance Mode on the **old** VM using the SQL command from the
_Disable Maintenance Mode_ step above.

You can figure out what went wrong on the new VM without any stress.
(Unless, of course, something bad happens _after_ you've completely migrated to
the new VM. That's why it's good to run some tests before switching over.)


Related reading
-------------------------

- About machine images:
    https://cloud.google.com/compute/docs/machine-images#disk-backup
- Reassigning external IP addresses:
    https://cloud.google.com/compute/docs/ip-addresses/reserve-static-external-ip-address#IP_assign
- Reassigning an external IP programatically:
    - https://cloud.google.com/sdk/gcloud/reference/compute/instances/delete-access-config
    - https://cloud.google.com/sdk/gcloud/reference/compute/instances/add-access-config

