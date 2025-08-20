### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_PUSHOVER_VERSION="v0.4"
#
# Required receiving services must already be set up.
# Requires jq installed and in PATH.
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set PUSHOVER_USER_KEY, PUSHOVER_TOKEN, and PUSHOVER_URL in your dockcheck.config file.

trigger_pushover_notification() {
  if [[ -n "$1" ]]; then
    pushover_channel="$1"
    UpperChannel=$(tr '[:lower:]' '[:upper:]' <<< "$pushover_channel")
  else
    pushover_channel="pushover"
    UpperChannel="PUSHOVER"
  fi

  PushoverUrlVar="${UpperChannel}_URL"
  PushoverUserKeyVar="${UpperChannel}_USER_KEY"
  PushoverTokenVar="${UpperChannel}_TOKEN"

  if [[ -z "${!PushoverUrlVar:-}" ]] || [[ -z "${!PushoverUserKeyVar:-}" ]] || [[ -z "${!PushoverTokenVar:-}" ]]; then
    printf "The ${pushover_channel} notification channel is enabled, but required configuration variables are missing. Pushover notifications will not be sent.\n"

    remove_channel pushover
    return 1
  fi

  PushoverUrl="${!PushoverUrlVar}" # e.g. PUSHOVER_URL=https://api.pushover.net/1/messages.json
  PushoverUserKey="${!PushoverUserKeyVar}" # e.g. PUSHOVER_USER_KEY=userkey
  PushoverToken="${!PushoverTokenVar}" # e.g. PUSHOVER_TOKEN=token-value

  # Sending the notification via Pushover
  curl -S -o /dev/null ${CurlArgs} -X POST \
      -F "token=$PushoverToken" \
      -F "user=$PushoverUserKey" \
      -F "title=$MessageTitle" \
      -F "message=$MessageBody" \
      $PushoverUrl

  if [[ $? -gt 0 ]]; then
    NotifyError=true
  fi
}