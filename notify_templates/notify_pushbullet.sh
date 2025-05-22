### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_PUSHBULLET_VERSION="v0.2"
#
# Required receiving services must already be set up.
# Requires jq installed and in PATH.
# Do not modify this file directly. Set PUSHBULLET_TOKEN and PUSHBULLET_URL in your dockcheck.config file.

if [[ -z "${PUSHBULLET_URL:-}" ]] || [[ -z "${PUSHBULLET_TOKEN:-}" ]]; then
  printf "Pushbullet notification channel enabled, but required configuration variables are missing. Pushbullet notifications will not be sent.\n"

  remove_channel pushbullet
fi

trigger_pushbullet_notification() {
  PushUrl="${PUSHBULLET_URL}" # e.g. PUSHBULLET_URL=https://api.pushbullet.com/v2/pushes
  PushToken="${PUSHBULLET_TOKEN}" # e.g. PUSHBULLET_TOKEN=token-value

  # Requires jq to process json data
  jq -n --arg title "$MessageTitle" --arg body "$MessageBody" '{body: $body, title: $title, type: "note"}' | curl -sS -o /dev/null --show-error --fail -X POST -H "Access-Token: $PushToken" -H "Content-type: application/json" $PushUrl -d @-
}