### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Required receiving services must already be set up.
# Modify to fit your setup - set MatrixServer, Room_id and AccessToken and .

send_notification() {
    Updates=("$@")
    UpdToString=$( printf "%s\n" "${Updates[@]}" )
    FromHost=$(hostname)
    
    # platform specific notification code would go here
    printf "\nSending Matrix notification\n"
    
    # Setting the MessageBody variable here.
    MessageBody="🐋 Containers on $FromHost with updates available: \n$UpdToString"
    
    # Modify to fit your setup:
    AccessToken="Your Matrix token here"
    Room_id="Enter Room_id here"
    MatrixServer="Enter Your HomeServer URL"
    MsgBody="{\"msgtype\":\"m.text\",\"body\":\"$MessageBody\"}"

    # URL Example:  https://matrix.org/_matrix/client/r0/rooms/!xxxxxx:example.com/send/m.room.message/?access_token=xxxxxxxx

    curl -sS -o /dev/null --fail -X PUT "$MatrixServer/_matrix/client/r0/rooms/$Room_id/send/m.room.message?access_token=$AccessToken" -H 'Content-Type: application/json' -d "$MsgBody"
    
}
