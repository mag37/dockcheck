### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_SLACK_VERSION="v0.2"
#
# Setup app and token at https://api.slack.com/tutorials/tracks/posting-messages-with-curl
# Leave (or place) this file in the "notify_templates" subdirectory in the same directory as your dockcheck.sh script. If you wish make your own modifications, copy it to your root folder.
# Do not modify this file directly within the "notify_templates" subdirectory. Set SLACK_ACCESS_TOKEN, and SLACK_CHANNEL_ID in your dockcheck.config file.

if [[ -z "${SLACK_ACCESS_TOKEN:-}" ]] || [[ -z "${SLACK_CHANNEL_ID:-}" ]]; then
  printf "Slack notification channel enabled, but required configuration variables are missing. Slack notifications will not be sent.\n"

  remove_channel slack
fi

trigger_slack_notification() {
  AccessToken="${SLACK_ACCESS_TOKEN}" # e.g. SLACK_ACCESS_TOKEN=some-token
  ChannelID="${SLACK_CHANNEL_ID}" # e.g. CHANNEL_ID=mychannel
  SlackUrl="https://slack.com/api/chat.postMessage"

  curl -sS -o /dev/null --show-error --fail \
    -d "text=$MessageBody" -d "channel=$ChannelID" \
    -H "Authorization: Bearer $AccessToken" \
    -X POST $SlackUrl
}
