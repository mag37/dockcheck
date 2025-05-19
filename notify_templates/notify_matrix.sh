### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_MATRIX_VERSION="v0.2"
#
# Required receiving services must already be set up.
# Modify to fit your setup - set MatrixServer, Room_id and AccessToken
# Set MATRIX_ACCESS_TOKEN, MATRIX_ROOM_ID, and MATRIX_SERVER_URL in your dockcheck.config file.

trigger_matrix_notification() {
    AccessToken="${MATRIX_ACCESS_TOKEN}" # e.g. MATRIX_ACCESS_TOKEN=token-value
    Room_id="${MATRIX_ROOM_ID}" # e.g. MATRIX_ROOM_ID=myroom
    MatrixServer="${MATRIX_SERVER_URL}" # e.g. MATRIX_SERVER_URL=http://matrix.yourdomain.tld
    MsgBody="{\"msgtype\":\"m.text\",\"body\":\"$MessageBody\"}"

    # URL Example:  https://matrix.org/_matrix/client/r0/rooms/!xxxxxx:example.com/send/m.room.message?access_token=xxxxxxxx
    curl -sS -o /dev/null --fail -X POST "$MatrixServer/_matrix/client/r0/rooms/$Room_id/send/m.room.message?access_token=$AccessToken" -H 'Content-Type: application/json' -d "$MsgBody"
}