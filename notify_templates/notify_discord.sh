### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Required receiving services must already be set up.
# Modify to fit your setup - set DiscordWebhookUrl

send_notification() {
    [ -s "$ScriptWorkDir"/urls.list ] && releasenotes || Updates=("$@")
    UpdToString=$( printf '%s\\n' "${Updates[@]}" )

    echo "$UpdToString"
    FromHost=$(hostname)

    # platform specific notification code would go here
    printf "\nSending Discord notification\n"

    # Setting the MessageBody variable here.
    MessageBody="🐋 Containers on $FromHost with updates available: \n$UpdToString"

    # Modify to fit your setup:
    DiscordWebhookUrl="PasteYourFullDiscordWebhookURL"

    MsgBody="{\"username\":\"$FromHost\",\"content\":\"$MessageBody\"}"

    curl -sS -o /dev/null --fail -X POST -H "Content-Type: application/json" -d "$MsgBody" "$DiscordWebhookUrl"

}

