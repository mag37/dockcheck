### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_DISCORD_VERSION="v0.3"
#
# Required receiving services must already be set up.
# Leave (or place) this file in the "notify_templates" subdirectory in the same directory as your dockcheck.sh script. If you wish make your own modifications, copy it to your root folder.
# Do not modify this file directly within the "notify_templates" subdirectory. Set DISCORD_WEBHOOK_URL in your dockcheck.config file.

if [[ -z "${DISCORD_WEBHOOK_URL:-}" ]]; then
  printf "Discord notification channel enabled, but required configuration variables are missing. Discord notifications will not be sent.\n"

  remove_channel discord
fi

trigger_discord_notification() {
  DiscordWebhookUrl="${DISCORD_WEBHOOK_URL}" # e.g. DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/<token string>

  JsonData=$( jq -n \
              --arg username "$FromHost" \
              --arg body "$MessageBody" \
              '{"username": $username, "content": $body}' )

  curl -sS -o /dev/null --fail -X POST -H "Content-Type: application/json" -d "$JsonData" "$DiscordWebhookUrl"
}
