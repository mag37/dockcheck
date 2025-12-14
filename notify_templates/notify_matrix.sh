### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_MATRIX_VERSION="v0.5"
#
# Required receiving services must already be set up.
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set MATRIX_ACCESS_TOKEN, MATRIX_ROOM_ID, and MATRIX_SERVER_URL in your dockcheck.config file.

trigger_matrix_notification() {
  if [[ -n "$1" ]]; then
    matrix_channel="$1"
  else
    matrix_channel="matrix"
  fi

  UpperChannel="${matrix_channel^^}"

  AccessTokenVar="${UpperChannel}_ACCESS_TOKEN"
  RoomIdVar="${UpperChannel}_ROOM_ID"
  MatrixServerVar="${UpperChannel}_SERVER_URL"

  if [[ -z "${!AccessTokenVar:-}" ]] || [[ -z "${!RoomIdVar:-}" ]] || [[ -z "${!MatrixServerVar:-}" ]]; then
    printf "The ${matrix_channel} notification channel is enabled, but required configuration variables are missing. Matrix notifications will not be sent.\n"

    remove_channel matrix
    return 0
  fi

  AccessToken="${!AccessTokenVar}" # e.g. MATRIX_ACCESS_TOKEN=token-value
  RoomId="${!RoomIdVar}" # e.g. MATRIX_ROOM_ID=myroom
  MatrixServer="${!MatrixServerVar}" # e.g. MATRIX_SERVER_URL=http://matrix.yourdomain.tld
  MsgBody=$($jqbin -Rn --arg body "$MessageBody" '{msgtype:"m.text", body:$body}')

  # URL Example:  https://matrix.org/_matrix/client/r0/rooms/!xxxxxx:example.com/send/m.room.message?access_token=xxxxxxxx
  curl -S -o /dev/null ${CurlArgs} -X POST "$MatrixServer/_matrix/client/r0/rooms/$RoomId/send/m.room.message?access_token=$AccessToken" -H 'Content-Type: application/json' -d "$MsgBody"

  if [[ $? -gt 0 ]]; then
    NotifyError=true
  fi
}
