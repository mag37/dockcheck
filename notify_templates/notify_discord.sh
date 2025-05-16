### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_DISCORD_VERSION="v0.1"
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
    UpdToString=$( printf '%s\\n' "$@" )

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

    RawNotifyUrl="https://raw.githubusercontent.com/mag37/dockcheck/main/notify_templates/notify_discord.sh"
    LatestNotifyRelease="$(curl -s -r 0-150 $RawNotifyUrl | sed -n "/NOTIFY_DISCORD_VERSION/s/NOTIFY_DISCORD_VERSION=//p" | tr -d '"')"
    if [[ "$NOTIFY_DISCORD_VERSION" != "$LatestNotifyRelease" ]] ; then
        printf -v NotifyUpdate "\n\nnotify_discord.sh update avialable:\n $NOTIFY_DISCORD_VERSION -> $LatestNotifyRelease\n"
        MessageBody="${MessageBody}${NotifyUpdate}"
    fi

    trigger_notification
}
