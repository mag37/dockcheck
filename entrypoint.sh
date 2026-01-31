#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# If the CRON_SCHEDULE and DOCKCHECK_ARGS environment variables are set, create the crontab entry for the dockcheck user
if [ -n "$CRON_SCHEDULE" ] && [ -n "$DOCKCHECK_ARGS" ]; then
  # Write the environment variable content to a temporary file, ensuring a newline at the end
  echo "$CRON_SCHEDULE" /app/dockcheck.sh "$DOCKCHECK_ARGS" > /app/crontab

  # Support additional schedule variables
  for schedule_var in "${!CRON_SCHEDULE_@}"; do
    suffix="${schedule_var#CRON_SCHEDULE_}"
    schedule_value="${!schedule_var}"
    args_var="DOCKCHECK_ARGS_${suffix}"
    args_value="${!args_var}"
    echo "$schedule_value" /app/dockcheck.sh "$args_value" >> /app/crontab
  done

  echo "Crontab created."
else
  echo "No CRON_SCHEDULE or DOCKCHECK_ARGS environment variable(s) found. No crontab created."
fi

# Pass control to the CMD command specified in the Dockerfile
exec "$@"
