### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Setup app and subscription at https://ntfy.sh
# Use your unique Topic Name in the URL below.

send_notification() {
[ -s "$ScriptWorkDir"/urls.list ] && releasenotes || Updates=("$@")
UpdToString=$( printf '%s\\n' "${Updates[@]}" )
FromHost=$(hostname)

printf "\nSending ntfy.sh notification\n"

MessageTitle="$FromHost - updates available."
# Setting the MessageBody variable here.
printf -v MessageBody "🐋 Containers on $FromHost with updates available:\n$UpdToString"

# Modify to fit your setup:
NtfyUrl="ntfy.sh/YourUniqueTopicName"

curl -sS -o /dev/null --show-error --fail \
  -H "Title: $MessageTitle" \
  -d "$MessageBody" \
  $NtfyUrl

}
