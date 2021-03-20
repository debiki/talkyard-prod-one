Setting up HTTPS for your Talkyard server
-----

You can skip this. Nowadays (Mars 2021) Talkyard automatically generates
HTTPS certificates for you, as long as you access Talkyard via a domain name
(but not an IP addresss).

(This is done using LetsEncrypt, OpenResty and a certain *lua-resty-acme* plugin.)

If for some reason you want to run Certbot manually instead, read on:

These instructions will:
 
 - Generate a free HTTPS cert (using Let'sEncrypt)
 - Start using the cert
 - Redirect HTTP to HTTPS
 - Auto renew the cert

### Port 80 and a reverse proxy?

Your Talkyard server needs to listen on port 80, HTTP. (And 443, HTTPS.)
Otherwise LetsEncrypt cannot verify that you own the domain name. [1]

If you have some other thing listening on port 80 on the same server, then:
You'll need to add a reverse proxy in front of Talkyard and that other thing.
This proxy would then listen on port 80 on behalf of both Talkyard and that
other thing. The proxy should look at the HOST header and send the traffic
to the correct destination (i.e. to Talkyard or to the other thing).

You can use for example Apache or Nginx as a revese proxy.
With Apache, you'd configure `<vhost>` blocks — one for Talkyard, and one for
that other thing.
With Nginx, you'd configure `server { ... }` blocks.


### Instructions

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

1. Enable automatic renewal of HTTPS certificates:

   ```
   cd /opt/talkyard/
   ./scripts/schedule-cert-renewal.sh  2>&1 | tee -a talkyard-maint.log
   ```

   Then look at the list of scheduled jobs: `crontab -l`. Now, you should see *"... renew-https-certs ..."* there.

All done.

You can ask questions here: <https://www.talkyard.io/forum/>


<br><br>
[1]:
If you're curious about why LetsEncrypt needs your server to listen on port 80,
have a look here:
https://community.letsencrypt.org/t/renew-certificate-using-https-port-443-or-alternative-port-eg-8000/66981/6.
In short, some sharing hosting providers (unrelated to Talkyard) might,
if using HTTPS for verification (instead of HTTP port 80), allow one customer
to reply to a LetsEncrypt challenge for another customer’s domain name,
and pretend to be the owner of that other domain name.