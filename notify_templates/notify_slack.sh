### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_SLACK_VERSION="v0.1"
#
# Copy/rename this file to notify.sh in the same directory as dockcheck.sh to enable the notification snippet.
# Setu app and token at https://api.slack.com/tutorials/tracks/posting-messages-with-curl
# Add your AccessToken and ChannelID below

FromHost=$(hostname)

trigger_notification() {
    # Modify to fit your setup:
    AccessToken="xoxb-not-a-real-token-this-will-not-work"
    ChannelID="C123456"
    SlackUrl="https://slack.com/api/chat.postMessage"

    curl -sS -o /dev/null --show-error --fail \
      -d "text=$MessageBody" -d "channel=$ChannelID" \
      -H "Authorization: Bearer $AccessToken" \
      -X POST $SlackUrl
}

send_notification() {
    UpdToString=$( printf '%s\\n' "$@" )

    printf "\nSending Slack notification\n"

    MessageTitle="$FromHost - updates available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "🐋 Containers on $FromHost with updates available:\n$UpdToString"

    trigger_notification
}

### Rename (eg. disabled_dockcheck_notification), remove or comment out the following function
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
    printf "\nSending Slack dockcheck notification\n"

    MessageTitle="$FromHost - New version of dockcheck available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "Installed version: $1 \nLatest version: $2 \n\nChangenotes: $3"

    RawNotifyUrl="https://raw.githubusercontent.com/mag37/dockcheck/main/notify_templates/notify_slack.sh"
    LatestNotifyRelease="$(curl -s -r 0-150 $RawNotifyUrl | sed -n "/NOTIFY_SLACK_VERSION/s/NOTIFY_SLACK_VERSION=//p" | tr -d '"')"
    if [[ "$NOTIFY_SLACK_VERSION" != "$LatestNotifyRelease" ]] ; then
        printf -v NotifyUpdate "\n\nnotify_slack.sh update avialable:\n $NOTIFY_SLACK_VERSION -> $LatestNotifyRelease\n"
        MessageBody="${MessageBody}${NotifyUpdate}"
    fi

    trigger_notification
}
