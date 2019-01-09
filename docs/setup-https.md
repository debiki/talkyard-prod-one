Setting up HTTPS for your Talkyard server
-----

**Edit:** You can skip all this. Nowadays, HTTPS certs are generated automatically (we added
Traefik to the tech stack). However, in case you want to remove Traefik and configure
things yourself instead, then, you can continue reading below.  **/Edit**

These instructions will:  (**Edit:** As mentioned above, you can skip all this. **/Edit**)
 
 - Generate a free HTTPS cert (using Let'sEncrypt)
 - Start using the cert
 - Redirect HTTP to HTTPS
 - Auto renew the cert
 
 Do as follows: (takes maybe 25 minutes, if DNS server already configured)

1. Update your DNS server, so your community hostname, say, `forum.example.com`, points to your Talkyard server's IP address. You might need to wait for a few hours, for the DNS changes to take effect.

1. On the Talkyard server, as root (`sudo -i`), install Certbot: (that's a Let'sEncrypt client)

   ```
   apt install certbot
   ```

1. Generate a HTTPS cert. Edit the below command: type your email address and forum hostname. Then test it once, with `--dry-run`. Then remove `--dry-run` and run it for real — now, a cert should be generated.

   ```
   cd /opt/talkyard/
   certbot certonly --dry-run --config-dir /opt/talkyard/data/certbot/ --email you@yoursite.com --webroot -w /opt/talkyard/data/certbot-challenges/ -d forum.yoursite.com
   ```

   Afterwards, you should see the cert here: `/opt/talkyard/data/certbot/live/`

1. In file `/opt/talkyard/conf/sites-enabled-manual/talkyard-servers.conf`, replace `forum.example.com` with your forum's hostname, in the  HTTPS Server Nr 1 `server { ... }` block, at 3 places. Then comment in that server block.

1. Test that the Nginx config is okay:

   ```
   cd /opt/talkyard/
   docker-compose exec web nginx -t
   ```

   That should print two lines, ending with: *"syntax is ok"* and *"test is successful"*. If instead there's an error message, read it and try to fix the config error — maybe you accidentally removed a `;` or a `/` when you edited the file? Or there's a DNS server hostname config error?

1. Start using the new Nginx config with the HTTPS cert:
 
   ```
   docker-compose exec web nginx -s reload 
   ```

1. Go to `https://your-forum-hostname`. You should see a blank page. Check that the browser shows the cert in green ok status (to the upper left, in the address bar).

1. Configure the application server to use HTTPS. In file `/opt/talkyard/conf/play-framework.conf`, set `talkyard.secure` to *true*:

   ```
   # Read in docs/setup-https.md about how to generate a HTTPS certificate.
   # Once done, set this to true:
   talkyard.secure=true
   ```

1. Restart the application server:

   ```
   docker-compose restart app   # takes maybe 20 seconds
   ```

1. In the browser, at `https://your-forum-hostname`, reload the page, until the Talkyard user interface & widgets appear — now in HTTPS.

1. Let's redirect HTTP to HTTPS:
 
   Once again, edit `/opt/talkyard/conf/sites-enabled-manual/talkyard-servers.conf` — this time, in the HTTP server block, comment out the two `include ...` lines and comment in `return 302 https://...`.

   Thereafter:

   ```
   docker-compose exec web nginx -t         # is config ok?
   docker-compose exec web nginx -s reload  # reload config
   ```

1. Go to `http://your-forum-hostname` (note: `http` not `https`). This should now redirect to `https`.

1. Enable automatic renewal of HTTPS certificates: *(this is a bit untested, as of August 11, 2018)*

   ```
   cd /opt/talkyard/
   ./scripts/schedule-cert-renewal.sh  2>&1 | tee -a talkyard-maint.log
   ```

   Then look at the list of scheduled jobs: `crontab -l`. Now, you should see *"... renew-https-certs ..."* there.

All done.

You can ask questions here: <https://www.talkyard.io/forum/>

