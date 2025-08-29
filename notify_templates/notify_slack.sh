### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_SLACK_VERSION="v0.4"
#
# Setup app and token at https://api.slack.com/tutorials/tracks/posting-messages-with-curl
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set SLACK_ACCESS_TOKEN, and SLACK_CHANNEL_ID in your dockcheck.config file.

trigger_slack_notification() {
  if [[ -n "$1" ]]; then
    slack_channel="$1"
  else
    slack_channel="slack"
  fi

  UpperChannel="${slack_channel^^}"

  AccessTokenVar="${UpperChannel}_ACCESS_TOKEN"
  ChannelIDVar="${UpperChannel}_CHANNEL_ID"

  if [[ -z "${!AccessTokenVar:-}" ]] || [[ -z "${!ChannelIDVar:-}" ]]; then
    printf "The ${slack_channel} notification channel is enabled, but required configuration variables are missing. Slack notifications will not be sent.\n"

    remove_channel slack
    return 0
  fi

  AccessToken="${!AccessTokenVar}" # e.g. SLACK_ACCESS_TOKEN=some-token
  ChannelID="${!ChannelIDVar}" # e.g. CHANNEL_ID=mychannel
  SlackUrl="https://slack.com/api/chat.postMessage"

  curl -S -o /dev/null ${CurlArgs} \
    -d "text=$MessageBody" -d "channel=$ChannelID" \
    -H "Authorization: Bearer $AccessToken" \
    -X POST $SlackUrl

  if [[ $? -gt 0 ]]; then
    NotifyError=true
  fi
}
