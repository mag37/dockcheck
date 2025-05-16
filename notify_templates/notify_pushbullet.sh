### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_PUSHBULLET_VERSION="v0.1"
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Required receiving services must already be set up.
# Requires jq installed and in PATH.
# Modify to fit your setup - set Url and Token.

FromHost=$(hostname)

trigger_notification() {
    # Modify to fit your setup:
    PushUrl="https://api.pushbullet.com/v2/pushes"
    PushToken="Your Pushbullet token here"

    # Requires jq to process json data
    jq -n --arg title "$MessageTitle" --arg body "$MessageBody" '{body: $body, title: $title, type: "note"}' | curl -sS -o /dev/null --show-error --fail -X POST -H "Access-Token: $PushToken" -H "Content-type: application/json" $PushUrl -d @-
}

send_notification() {
    UpdToString=$( printf '%s\\n' "$@" )

    # platform specific notification code would go here
    printf "\nSending pushbullet notification\n"

    MessageTitle="$FromHost - updates available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "🐋 Containers on $FromHost with updates available:\n$UpdToString"

    trigger_notification
}

### Rename (eg. disabled_dockcheck_notification), remove or comment out the following function
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
    printf "\nSending pushbullet dockcheck notification\n"

    MessageTitle="$FromHost - New version of dockcheck available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "Installed version: $1 \nLatest version: $2 \n\nChangenotes: $3"

    RawNotifyUrl="https://raw.githubusercontent.com/mag37/dockcheck/main/notify_templates/notify_pushbullet.sh"
    LatestNotifyRelease="$(curl -s -r 0-150 $RawNotifyUrl | sed -n "/NOTIFY_PUSHBULLET_VERSION/s/NOTIFY_PUSHBULLET_VERSION=//p" | tr -d '"')"
    if [[ "$NOTIFY_PUSHBULLET_VERSION" != "$LatestNotifyRelease" ]] ; then
        printf -v NotifyUpdate "\n\nnotify_pushbullet.sh update avialable:\n $NOTIFY_PUSHBULLET_VERSION -> $LatestNotifyRelease\n"
        MessageBody="${MessageBody}${NotifyUpdate}"
    fi

    trigger_notification
}
