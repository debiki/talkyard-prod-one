
Troubleshooting Talkyard
========================

Installation Problems
---------------------


### Error: talkyard_web_1, Read timed out

If, when you run:

    /scripts/upgrade-if-needed.sh 2>&1 | tee -a talkyard-maint.log

you're getting this error:

    Creating talkyard_web_1    ...

    ERROR: for talkyard_web_1  UnixHTTPConnectionPool(host='localhost', port=None): Read timed out. (read timeout=...)

    ERROR: for web  UnixHTTPConnectionPool(host='localhost', port=None): Read timed out. (read timeout=...)
    An HTTP request took too long to complete. Retry with --verbose to obtain debug information.
    If you encounter this issue regularly because of slow network conditions, consider setting COMPOSE_HTTP_TIMEOUT to a higher value (current value: 240).

then the reason can be that the server has too little memory — which apparently can cause
Nginx (OpenResty) to run out of memory and crash. Now you might wonder, why would Nginx use
that much memory? — I think it's OpenResty (an Nginx distribution) that just-in-time compiles
lots of Lua code, and then uses lots of memory.



Old: Troubleshooting and debugging
----------------

(Ignore this section; it's not completed and hard to understand.)

? save Java crash dumps in ./play-crash
+ tips about how to run jmap? or view in jvisualvm + Idea? jmap -heap PID

How to connect VisualVM

Tips about how to view logs: all logs, app specific logs.

How to jump into a Docker container.

How to connect a debugger: open Docker port, then connect via SSH tunnel (assuming a firewall blocks the port on the host).
If using Google Compute Engine, then ssh tunnel:

    gcloud compute ssh server-name --ssh-flag=-L9999:127.0.0.1:9999 --ssh-flag=-N


How to open console in Chrome, view messages & post to the E.D. help forum.

View CPU & memory usage: `./scripts/stats.sh`


