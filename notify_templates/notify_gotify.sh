### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_GOTIFY_VERSION="v0.1"
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Required receiving services must already be set up.
# Modify to fit your setup - set GotifyUrl and GotifyToken.

FromHost=$(hostname)

trigger_notification() {
    # Modify to fit your setup:
    GotifyToken="Your Gotify token here"
    GotifyUrl="https://api.gotify/message?token=${GotifyToken}"

    curl \
        -F "title=${MessageTitle}" \
        -F "message=${MessageBody}" \
        -F "priority=5" \
        -X POST "${GotifyUrl}" 1> /dev/null
}

send_notification() {
    [ -s "$ScriptWorkDir"/urls.list ] && releasenotes || Updates=("$@")
    UpdToString=$( printf '%s\\n' "${Updates[@]}" )

    # platform specific notification code would go here
    printf "\nSending Gotify notification\n"

    # Setting the MessageTitle and MessageBody variable here.
    MessageTitle="${FromHost} - updates available."
    printf -v MessageBody "Containers on $FromHost with updates available:\n$UpdToString"

    trigger_notification
}

### Rename (eg. disabled_dockcheck_notification), remove or comment out the following function
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
    printf "\nSending Gotify dockcheck notification\n"

    MessageTitle="$FromHost - New version of dockcheck available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "Installed version: $1 \nLatest version: $2 \n\nChangenotes: $3"

    RawNotifyUrl="https://raw.githubusercontent.com/mag37/dockcheck/main/notify_templates/notify_gotify.sh"
    LatestNotifyRelease="$(curl -s -r 0-150 $RawNotifyUrl | sed -n "/NOTIFY_GOTIFY_VERSION/s/NOTIFY_GOTIFY_VERSION=//p" | tr -d '"')"
    if [[ "$NOTIFY_GOTIFY_VERSION" != "$LatestNotifyRelease" ]] ; then
        printf -v NotifyUpdate "\n\nnotify_gotify.sh update avialable:\n $NOTIFY_GOTIFY_VERSION -> $LatestNotifyRelease\n"
        MessageBody="${MessageBody}${NotifyUpdate}"
    fi

    trigger_notification
}
