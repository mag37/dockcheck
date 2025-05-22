### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_MATRIX_VERSION="v0.2"
#
# Required receiving services must already be set up.
# Do not modify this file directly. Set MATRIX_ACCESS_TOKEN, MATRIX_ROOM_ID, and MATRIX_SERVER_URL in your dockcheck.config file.

if [[ -z "${MATRIX_ACCESS_TOKEN:-}" ]] || [[ -z "${MATRIX_ROOM_ID}:-" ]] || [[ -z "${MATRIX_SERVER_URL}:-" ]]; then
  printf "Matrix notification channel enabled, but required configuration variables are missing. Matrix notifications will not be sent.\n"

  remove_channel matrix
fi

trigger_matrix_notification() {
  AccessToken="${MATRIX_ACCESS_TOKEN}" # e.g. MATRIX_ACCESS_TOKEN=token-value
  Room_id="${MATRIX_ROOM_ID}" # e.g. MATRIX_ROOM_ID=myroom
  MatrixServer="${MATRIX_SERVER_URL}" # e.g. MATRIX_SERVER_URL=http://matrix.yourdomain.tld
  MsgBody="{\"msgtype\":\"m.text\",\"body\":\"$MessageBody\"}"

  # URL Example:  https://matrix.org/_matrix/client/r0/rooms/!xxxxxx:example.com/send/m.room.message?access_token=xxxxxxxx
  curl -sS -o /dev/null --fail -X POST "$MatrixServer/_matrix/client/r0/rooms/$Room_id/send/m.room.message?access_token=$AccessToken" -H 'Content-Type: application/json' -d "$MsgBody"
}