(Ignore this document; it's not completed and hard to understand.)


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


How to open console in Chrome, view messages & post to the E.D. help forum.

View CPU & memory usage: `./scripts/stats.sh`


