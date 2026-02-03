# Use an official Alpine image as a base
FROM alpine:latest

WORKDIR /app

# Install apps
RUN apk update && apk add --no-cache bash curl docker-cli docker-cli-compose supercronic jq regclient msmtp --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/

# Copy the script files into the container
COPY entrypoint.sh /app/entrypoint.sh
COPY dockcheck.sh /app/dockcheck.sh
COPY urls.list /app/urls.list
COPY notify_templates /app/notify_templates
COPY extras /app/extras
COPY addons /app/addons

# Create symlink, give execution rights on the script and set proper permissions
RUN chmod +x /app/dockcheck.sh
RUN chmod +x /app/entrypoint.sh

ENTRYPOINT ["/app/entrypoint.sh"]

# Run the cron daemon in the foreground and tail the log file to keep the container running
CMD ["supercronic", "-passthrough-logs", "-json", "/app/crontab"]
