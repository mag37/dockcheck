### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Required receiving services must already be set up.
# Modify to fit your setup - set MatrixServer, Room_id and AccessToken

FromHost=$(hostname)

trigger_notification() {
    # Modify to fit your setup:
    AccessToken="Your Matrix token here"
    Room_id="Enter Room_id here"
    MatrixServer="Enter Your HomeServer URL"
    MsgBody="{\"msgtype\":\"m.text\",\"body\":\"$MessageBody\"}"

    # URL Example:  https://matrix.org/_matrix/client/r0/rooms/!xxxxxx:example.com/send/m.room.message?access_token=xxxxxxxx
    curl -sS -o /dev/null --fail -X POST "$MatrixServer/_matrix/client/r0/rooms/$Room_id/send/m.room.message?access_token=$AccessToken" -H 'Content-Type: application/json' -d "$MsgBody"
}

send_notification() {
    [ -s "$ScriptWorkDir"/urls.list ] && releasenotes || Updates=("$@")
    UpdToString=$( printf '%s\\n' "${Updates[@]}" )

    # platform specific notification code would go here
    printf "\nSending Matrix notification\n"

    # Setting the MessageBody variable here.
    MessageBody="🐋 Containers on $FromHost with updates available: \n$UpdToString"

    trigger_notification
}

### Rename (eg. disabled_dockcheck_notification), remove or comment out the following function
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
    printf "\nSending Matrix dockcheck notification\n"
 
    MessageTitle="$FromHost - New version of dockcheck available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "Installed version: $1 \nLatest version: $2 \n\nChangenotes: $3"
 
    trigger_notification
}
