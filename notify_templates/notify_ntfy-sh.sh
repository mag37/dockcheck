### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Setup app and subscription at https://ntfy.sh
# Use your unique Topic Name in the URL below.

FromHost=$(hostname)

trigger_notification() {
    # Modify to fit your setup:
    NtfyUrl="ntfy.sh/YourUniqueTopicName"

    curl -sS -o /dev/null --show-error --fail \
      -H "Title: $MessageTitle" \
      -d "$MessageBody" \
      $NtfyUrl
}

send_notification() {
    [ -s "$ScriptWorkDir"/urls.list ] && releasenotes || Updates=("$@")
    UpdToString=$( printf '%s\\n' "${Updates[@]}" )

    printf "\nSending ntfy.sh notification\n"

    MessageTitle="$FromHost - updates available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "🐋 Containers on $FromHost with updates available:\n$UpdToString"

    trigger_notification
}

### Rename (eg. disabled_dockcheck_notification), remove or comment out the following function
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
    printf "\nSending ntfy.sh dockcheck notification\n"
 
    MessageTitle="$FromHost - New version of dockcheck available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "Installed version: $1 \nLatest version: $2 \n\nChangenotes: $3"
 
    trigger_notification
}
