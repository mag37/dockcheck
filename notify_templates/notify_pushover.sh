### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_PUSHOVER_VERSION="v0.2"
#
# Required receiving services must already be set up.
# Requires jq installed and in PATH.
# Do not modify this file directly. Set PUSHOVER_USER_KEY, PUSHOVER_TOKEN, and PUSHOVER_URL in your dockcheck.config file.

if [[ -z "${PUSHOVER_URL:-}" ]] || [[ -z "${PUSHOVER_USER_KEY:-}" ]] || [[ -z "${PUSHOVER_TOKEN:-}" ]]; then
  printf "Pushover notification channel enabled, but required configuration variables are missing. Pushover notifications will not be sent.\n"

  remove_channel pushover
fi

trigger_pushover_notification() {
  PushoverUrl="${PUSHOVER_URL}" # e.g. PUSHOVER_URL=https://api.pushover.net/1/messages.json
  PushoverUserKey="${PUSHOVER_USER_KEY}" # e.g. PUSHOVER_USER_KEY=userkey
  PushoverToken="${PUSHOVER_TOKEN}" # e.g. PUSHOVER_TOKEN=token-value

  # Sending the notification via Pushover
  curl -sS -o /dev/null --show-error --fail -X POST \
      -F "token=$PushoverToken" \
      -F "user=$PushoverUserKey" \
      -F "title=$MessageTitle" \
      -F "message=$MessageBody" \
      $PushoverUrl
}