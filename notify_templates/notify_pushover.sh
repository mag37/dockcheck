### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Required receiving services must already be set up.
# Requires jq installed and in PATH.
# Modify to fit your setup - set Url and Token.

send_notification() {
    [ -s "$ScriptWorkDir"/urls.list ] && releasenotes || Updates=("$@")
    UpdToString=$( printf '%s\\n' "${Updates[@]}" )
    FromHost=$(hostname)

    # platform specific notification code would go here
    printf "\nSending pushover notification\n"

    MessageTitle="$FromHost - updates available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "🐋 Containers on $FromHost with updates available:\n$UpdToString"

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
