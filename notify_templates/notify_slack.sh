### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_SLACK_VERSION="v0.3"
#
# Setup app and token at https://api.slack.com/tutorials/tracks/posting-messages-with-curl
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set SLACK_ACCESS_TOKEN, and SLACK_CHANNEL_ID in your dockcheck.config file.

if [[ -z "${SLACK_ACCESS_TOKEN:-}" ]] || [[ -z "${SLACK_CHANNEL_ID:-}" ]]; then
  printf "Slack notification channel enabled, but required configuration variables are missing. Slack notifications will not be sent.\n"

  remove_channel slack
fi

trigger_slack_notification() {
  AccessToken="${SLACK_ACCESS_TOKEN}" # e.g. SLACK_ACCESS_TOKEN=some-token
  ChannelID="${SLACK_CHANNEL_ID}" # e.g. CHANNEL_ID=mychannel
  SlackUrl="https://slack.com/api/chat.postMessage"

  curl -sSf -o /dev/null ${CurlArgs} \
    -d "text=$MessageBody" -d "channel=$ChannelID" \
    -H "Authorization: Bearer $AccessToken" \
    -X POST $SlackUrl

  if [[ $? -gt 0 ]]; then
    NotifyError=true
  fi
}
