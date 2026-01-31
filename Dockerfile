# Use an official Alpine image as a base
FROM alpine:latest

WORKDIR /app

# Install apps
RUN apk update && apk add --no-cache bash curl docker-cli docker-cli-compose supercronic jq regclient msmtp --repository=http://dl-cdn.alpinelinux.org/alpine/edge/testing/

# Copy the script files into the container
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY dockcheck.sh /app/dockcheck.sh
COPY urls.list /app/urls.list
COPY notify_templates /app/notify_templates
COPY extras /app/extras
COPY addons /app/addons

# Create symlink, give execution rights on the script and set proper permissions
RUN ln -s /app/dockcheck.sh /usr/local/bin/dockcheck.sh
RUN chmod +x /usr/local/bin/dockcheck.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Run the cron daemon in the foreground and tail the log file to keep the container running
CMD ["supercronic", "/app/crontab"]
