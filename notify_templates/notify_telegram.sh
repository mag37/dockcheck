### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_TELEGRAM_VERSION="v0.1"
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Required receiving services must already be set up.
# Modify to fit your setup - set TelegramChatId and TelegramToken.

FromHost=$(hostname)

trigger_notification() {

    if [[ "$PrintMarkdownURL" == true ]]; then
        ParseMode="Markdown"
    else
        ParseMode="HTML"
    fi

    # Modify to fit your setup:
    TelegramToken="Your Telegram token here"
    TelegramChatId="Your Telegram ChatId here"
    TelegramUrl="https://api.telegram.org/bot$TelegramToken"
    TelegramTopicID=12345678 ## Set to 0 if not using specific topic within chat
    TelegramData="{\"chat_id\":\"$TelegramChatId\",\"text\":\"$MessageBody\",\"message_thread_id\":\"$TelegramTopicID\",\"disable_notification\": false}"

    curl -sS -o /dev/null --fail -X POST "$TelegramUrl/sendMessage" -H 'Content-Type: application/json' -d "$TelegramData"
}

send_notification() {
    [ -s "$ScriptWorkDir"/urls.list ] && releasenotes || Updates=("$@")
    UpdToString=$( printf '%s\\n' "${Updates[@]}" )

    # platform specific notification code would go here
    printf "\nSending Telegram notification\n"

    # Setting the MessageBody variable here.
    MessageBody="🐋 Containers on $FromHost with updates available: \n$UpdToString"

    trigger_notification
}

### Rename (eg. disabled_dockcheck_notification), remove or comment out the following function
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
    printf "\nSending Telegram dockcheck notification\n"

    MessageTitle="$FromHost - New version of dockcheck available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "$FromHost - New version of dockcheck available.\n\nInstalled version: $1 \nLatest version: $2 \n\nChangenotes: $3"

    RawNotifyUrl="https://raw.githubusercontent.com/mag37/dockcheck/main/notify_templates/notify_telegram.sh"
    LatestNotifyRelease="$(curl -s -r 0-150 $RawNotifyUrl | sed -n "/NOTIFY_TELEGRAM_VERSION/s/NOTIFY_TELEGRAM_VERSION=//p" | tr -d '"')"
    if [[ "$NOTIFY_TELEGRAM_VERSION" != "$LatestNotifyRelease" ]] ; then
        printf -v NotifyUpdate "\n\nnotify_telegram.sh update avialable:\n $NOTIFY_TELEGRAM_VERSION -> $LatestNotifyRelease\n"
        MessageBody="${MessageBody}${NotifyUpdate}"
    fi

    trigger_notification
}
