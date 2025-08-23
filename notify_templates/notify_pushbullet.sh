### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_PUSHBULLET_VERSION="v0.4"
#
# Required receiving services must already be set up.
# Requires jq installed and in PATH.
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set PUSHBULLET_TOKEN and PUSHBULLET_URL in your dockcheck.config file.

trigger_pushbullet_notification() {
  if [[ -n "$1" ]]; then
    pushbullet_channel="$1"
  else
    pushbullet_channel="pushbullet"
  fi

  UpperChannel="${pushbullet_channel^^}"

  PushUrlVar="${UpperChannel}_URL"
  PushTokenVar="${UpperChannel}_TOKEN"

  if [[ -z "${!PushUrlVar:-}" ]] || [[ -z "${!PushTokenVar:-}" ]]; then
    printf "The ${pushbullet_channel} notification channel is enabled, but required configuration variables are missing. Pushbullet notifications will not be sent.\n"

    remove_channel pushbullet
    return 1
  fi

  PushUrl="${!PushUrlVar}" # e.g. PUSHBULLET_URL=https://api.pushbullet.com/v2/pushes
  PushToken="${!PushTokenVar}" # e.g. PUSHBULLET_TOKEN=token-value

  # Requires jq to process json data
  "$jqbin" -n --arg title "$MessageTitle" --arg body "$MessageBody" '{body: $body, title: $title, type: "note"}' | curl -S -o /dev/null ${CurlArgs} -X POST -H "Access-Token: $PushToken" -H "Content-type: application/json" $PushUrl -d @-

  if [[ $? -gt 0 ]]; then
    NotifyError=true
  fi
}
