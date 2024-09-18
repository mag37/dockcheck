### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Required receiving services must already be set up.
# Requires jq installed and in PATH.
# Modify to fit your setup - set Url and Token.

send_notification() {
Updates=("$@")
UpdToString=$( printf "%s\n" "${Updates[@]}" )
FromHost=$(hostname)

# platform specific notification code would go here
printf "\nSending pushbullet notification\n"

MessageTitle="$FromHost - updates available."
# Setting the MessageBody variable here.
MessageBody="Containers on $FromHost with updates available: $UpdToString"

# Modify to fit your setup:
PushUrl="https://api.pushbullet.com/v2/pushes"
PushToken="Your Pushbullet token here"

# Requires jq to process json data
jq -n --arg title "$MessageTitle" --arg body "$MessageBody" '{body: $body, title: $title, type: "note"}' | curl -sS -o /dev/null --show-error --fail -X POST -H "Access-Token: $PushToken" -H "Content-type: application/json" $PushUrl -d @-

}
