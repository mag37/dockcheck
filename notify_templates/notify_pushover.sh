### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_PUSHOVER_VERSION="v0.1"
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Required receiving services must already be set up.
# Requires jq installed and in PATH.
# Modify to fit your setup - set Url and Token.

FromHost=$(hostname)

trigger_notification() {
    # Modify to fit your setup:
    PushoverUrl="https://api.pushover.net/1/messages.json"
    PushoverUserKey="Your Pushover User Key Here"
    PushoverToken="Your Pushover API Token Here"

    # Sending the notification via Pushover
    curl -sS -o /dev/null --show-error --fail -X POST \
        -F "token=$PushoverToken" \
        -F "user=$PushoverUserKey" \
        -F "title=$MessageTitle" \
        -F "message=$MessageBody" \
        $PushoverUrl
}

send_notification() {
    UpdToString=$( printf '%s\\n' "$@" )

    # platform specific notification code would go here
    printf "\nSending pushover notification\n"

    MessageTitle="$FromHost - updates available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "🐋 Containers on $FromHost with updates available:\n$UpdToString"

    trigger_notification
}

### Rename (eg. disabled_dockcheck_notification), remove or comment out the following function
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
    printf "\nSending pushover dockcheck notification\n"

    MessageTitle="$FromHost - New version of dockcheck available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "Installed version: $1 \nLatest version: $2 \n\nChangenotes: $3"

    RawNotifyUrl="https://raw.githubusercontent.com/mag37/dockcheck/main/notify_templates/notify_pushover.sh"
    LatestNotifyRelease="$(curl -s -r 0-150 $RawNotifyUrl | sed -n "/NOTIFY_PUSHOVER_VERSION/s/NOTIFY_PUSHOVER_VERSION=//p" | tr -d '"')"
    if [[ "$NOTIFY_PUSHOVER_VERSION" != "$LatestNotifyRelease" ]] ; then
        printf -v NotifyUpdate "\n\nnotify_pushover.sh update avialable:\n $NOTIFY_PUSHOVER_VERSION -> $LatestNotifyRelease\n"
        MessageBody="${MessageBody}${NotifyUpdate}"
    fi

    trigger_notification
}
