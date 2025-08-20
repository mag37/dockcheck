### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_DISCORD_VERSION="v0.5"
#
# Required receiving services must already be set up.
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set DISCORD_WEBHOOK_URL in your dockcheck.config file.

trigger_discord_notification() {
  if [[ -n "$1" ]]; then
    discord_channel="$1"
    UpperChannel=$(tr '[:lower:]' '[:upper:]' <<< "$discord_channel")
  else
    discord_channel="discord"
    UpperChannel="DISCORD"
  fi

  DiscordWebhookUrlVar="${UpperChannel}_WEBHOOK_URL"

  if [[ -z "${!DiscordWebhookUrlVar:-}" ]]; then
    printf "The ${discord_channel} notification channel is enabled, but required configuration variables are missing. Discord notifications will not be sent.\n"

    remove_channel discord
    return 1
  fi

  DiscordWebhookUrl="${!DiscordWebhookUrlVar}" # e.g. DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/<token string>

  JsonData=$( "$jqbin" -n \
              --arg username "$FromHost" \
              --arg body "$MessageBody" \
              '{"username": $username, "content": $body}' )

  curl -S -o /dev/null ${CurlArgs} -X POST -H "Content-Type: application/json" -d "$JsonData" "$DiscordWebhookUrl"

  if [[ $? -gt 0 ]]; then
    NotifyError=true
  fi
}
