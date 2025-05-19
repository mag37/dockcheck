### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_DISCORD_VERSION="v0.2"
#
# Required receiving services must already be set up.
# Set DISCORD_WEBHOOK_URL in your dockcheck.config file.

trigger_discord_notification() {
    DiscordWebhookUrl="${DISCORD_WEBHOOK_URL}" # e.g. DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/<token string>

    MsgBody="{\"username\":\"$FromHost\",\"content\":\"$MessageBody\"}"
    curl -sS -o /dev/null --fail -X POST -H "Content-Type: application/json" -d "$MsgBody" "$DiscordWebhookUrl"
}
