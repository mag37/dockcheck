### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
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

### Remove or comment out the following function
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
    printf "\nSending Apprise dockcheck notification\n"

    MessageTitle="$FromHost - New version of dockcheck available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "Installed version: $1 \nLatest version: $2 \n\nChangenotes: $3"

    trigger_notification
}
