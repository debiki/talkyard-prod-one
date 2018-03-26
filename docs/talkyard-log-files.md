Talkyard log files
==================

Here you'll learn where you'll find the Talkyard log files and how old logs get deleted.

The Logrotate config mentioned below, is installed by `../scripts/schedule-logrotate.sh`.
It also tells Cron to run `../scripts/delete-old-logs.sh` once a day because Logrotate isn't
a good fit for all logs.


- Docker's json logs with output from all containers.
  Here: `/var/lib/docker/containers/*/*json.log`.
  Deleted by logrotate.

- The Web container: Nginx.
  Here: `/var/log/nginx/access.log` and `error.log`.
  Deleted by logrotate.

- The App container, with Play Framework, deletes its own logs.
  Here: `/var/log/talkyard/`. Configured here:
  `(talkyard-dev-repo)/conf/logback.xml`, embedded in the Docker image.

- The Cache and RDB containers, with Redis and PostgreSQL,
  save their logs here: `/var/log/redis/` and here: `/var/log/postgresql/`.
  Deleted by a cron job that runs ./scripts/delete-old-logs.sh.

- The Search container, with ElasticSearch, deletes its own logs. Configured here:
  `(talkyard-dev-repo)/docker/search/log4j2.properties` and embedded in the Docker image.

- The Certgen container, with Let'sEncrypt: Hasn't yet been created.
  Later: Will store logs here: `/var/log/letsencrypt/`?


