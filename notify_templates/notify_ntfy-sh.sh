### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_NTFYSH_VERSION="v0.2"
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Setup app and subscription at https://ntfy.sh
# Use your unique Topic Name in the URL below.

FromHost=$(hostname)

trigger_notification() {
    # Modify to fit your setup:
    NtfyUrl="ntfy.sh/YourUniqueTopicName"

    if [[ "$PrintMarkdownURL" == true ]]; then
        ContentType="Markdown: yes"
    else
        ContentType="Markdown: no" #text/plain
    fi

    curl -sS -o /dev/null --show-error --fail \
      -H "Title: $MessageTitle" \
      -H "$ContentType"      \
      -d "$MessageBody" \
      "$NtfyUrl"
}

send_notification() {
    UpdToString=$( printf '%s\\n' "$@" )

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

    RawNotifyUrl="https://raw.githubusercontent.com/mag37/dockcheck/main/notify_templates/notify_ntfy-sh.sh"
    LatestNotifyRelease="$(curl -s -r 0-150 $RawNotifyUrl | sed -n "/NOTIFY_NTFYSH_VERSION/s/NOTIFY_NTFYSH_VERSION=//p" | tr -d '"')"
    if [[ "$NOTIFY_NTFYSH_VERSION" != "$LatestNotifyRelease" ]] ; then
        printf -v NotifyUpdate "\n\nnotify_ntfy-sh.sh update avialable:\n $NOTIFY_NTFYSH_VERSION -> $LatestNotifyRelease\n"
        MessageBody="${MessageBody}${NotifyUpdate}"
    fi

    trigger_notification
}
