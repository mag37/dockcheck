### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
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
    [ -s "$ScriptWorkDir"/urls.list ] && releasenotes || Updates=("$@")
    UpdToString=$( printf '%s\\n' "${Updates[@]}" )

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
    printf "\nSending Apprise dockcheck notification\n"
 
    MessageTitle="$FromHost - New version of dockcheck available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "Installed version: $1 \nLatest version: $2 \n\nChangenotes: $3"
 
    trigger_notification
}
