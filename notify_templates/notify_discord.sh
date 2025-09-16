#!/usr/bin/env bash

# Discord notification template for podcheck v2
# Requires: DISCORD_WEBHOOK_URL

if [[ -z "${DISCORD_WEBHOOK_URL:-}" ]]; then
  echo "Error: DISCORD_WEBHOOK_URL not configured"
  return 1
fi

# Prepare the Discord message
if [[ -n "${NOTIFICATION_MESSAGE:-}" ]]; then
  # Format message for Discord - escape quotes and newlines
  discord_content="${NOTIFICATION_MESSAGE}"
  discord_content="${discord_content//\"/\\\"}"
  discord_content="${discord_content//$'\n'/\\n}"
  
  # Create Discord webhook payload
  discord_payload=$(cat <<EOF
{
  "content": "${discord_content}",
  "username": "Podcheck",
  "embeds": [
    {
      "title": "${NOTIFICATION_TITLE:-Podcheck Notification}",
      "description": "${discord_content}",
      "color": 3447003,
      "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
    }
  ]
}
EOF
)

  # Send to Discord
  if curl -H "Content-Type: application/json" \
          -d "$discord_payload" \
          "${DISCORD_WEBHOOK_URL}" \
          ${CurlArgs:-} &>/dev/null; then
    return 0
  else
    echo "Failed to send Discord notification"
    return 1
  fi
else
  echo "No notification message provided"
  return 1
fi

