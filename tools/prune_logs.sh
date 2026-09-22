#!/usr/bin/env bash
# Delete rotated server logs older than seven days. The world and auth
# servers cap each live log (Appender.* sixth argument) and rename the full
# file to <name>.<timestamp> when the cap is hit; those copies would
# otherwise accumulate forever. Installed as a daily root cron job.
find /root/classic/logs -type f -name '*.log.*' -mtime +7 -delete
