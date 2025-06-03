### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_DISCORD_VERSION="v0.4"
#
# Required receiving services must already be set up.
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set DISCORD_WEBHOOK_URL in your dockcheck.config file.

if [[ -z "${DISCORD_WEBHOOK_URL:-}" ]]; then
  printf "Discord notification channel enabled, but required configuration variables are missing. Discord notifications will not be sent.\n"

  remove_channel discord
fi

trigger_discord_notification() {
  DiscordWebhookUrl="${DISCORD_WEBHOOK_URL}" # e.g. DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/<token string>

  JsonData=$( "$jqbin" -n \
              --arg username "$FromHost" \
              --arg body "$MessageBody" \
              '{"username": $username, "content": $body}' )

  curl -sSf -o /dev/null ${CurlArgs} -X POST -H "Content-Type: application/json" -d "$JsonData" "$DiscordWebhookUrl"

  if [[ $? -gt 0 ]]; then
    NotifyError=true
  fi
}
