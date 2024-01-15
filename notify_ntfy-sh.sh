### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Setup app and subscription at https://ntfy.sh
# Use your unique Topic Name in the URL below.

send_notification() {
Updates=("$@")
UpdToString=$( printf "%s\n" "${Updates[@]}" )
FromHost=$(hostname)

printf "\nSending Apprise notification\n"

MessageTitle="$FromHost - updates available."
# Setting the MessageBody variable here.
read -d '\n' MessageBody << __EOF
Containers on $FromHost with updates available:

$UpdToString

__EOF

# Modify to fit your setup:
NtfyUrl="ntfy.sh/YourUniqueTopicName"

curl \
  -H "Title: $MessageTitle" \
  -d "$MessageBody" \
  $NtfyUrl

}
