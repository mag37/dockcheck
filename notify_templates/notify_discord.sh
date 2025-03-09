### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Required receiving services must already be set up.
# Modify to fit your setup - set DiscordWebhookUrl

FromHost=$(hostname)

trigger_notification() {
    # Modify to fit your setup:
    DiscordWebhookUrl="PasteYourFullDiscordWebhookURL"

    MsgBody="{\"username\":\"$FromHost\",\"content\":\"$MessageBody\"}"
    curl -sS -o /dev/null --fail -X POST -H "Content-Type: application/json" -d "$MsgBody" "$DiscordWebhookUrl"
}

send_notification() {
    [ -s "$ScriptWorkDir"/urls.list ] && releasenotes || Updates=("$@")
    UpdToString=$( printf '%s\\n' "${Updates[@]}" )

    printf "\nSending Discord notification\n"
    # Setting the MessageBody variable here.
    MessageBody="🐋 Containers on $FromHost with updates available: \n$UpdToString"

    trigger_notification
}

### Rename (eg. disabled_dockcheck_notification), remove or comment out the following function
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
    printf "\nSending Discord dockcheck notification\n"
    MessageBody="$FromHost - New version of dockcheck available: \n Installed version: $1 \nLatest version: $2 \n\nChangenotes: $3"

    trigger_notification
}
