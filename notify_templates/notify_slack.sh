### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_SLACK_VERSION="v0.2"
#
# Setu app and token at https://api.slack.com/tutorials/tracks/posting-messages-with-curl
# Set SLACK_ACCESS_TOKEN, and SLACK_CHANNEL_ID in your dockcheck.config file.

trigger_slack_notification() {
    AccessToken="${SLACK_ACCESS_TOKEN}" # e.g. SLACK_ACCESS_TOKEN=some-token
    ChannelID="${SLACK_CHANNEL_ID}" # e.g. CHANNEL_ID=mychannel
    SlackUrl="https://slack.com/api/chat.postMessage"

    curl -sS -o /dev/null --show-error --fail \
      -d "text=$MessageBody" -d "channel=$ChannelID" \
      -H "Authorization: Bearer $AccessToken" \
      -X POST $SlackUrl
}
