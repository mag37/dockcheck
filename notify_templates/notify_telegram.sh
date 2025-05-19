### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_TELEGRAM_VERSION="v0.2"
#
# Required receiving services must already be set up.
# Set TELEGRAM_CHAT_ID and TELEGRAM_TOKEN in your dockcheck.config file.

trigger_telegram_notification() {

    if [[ "$PrintMarkdownURL" == true ]]; then
        ParseMode="Markdown"
    else
        ParseMode="HTML"
    fi

    TelegramToken="${TELEGRAM_TOKEN}" # e.g. TELEGRAM_TOKEN=token-value
    TelegramChatId="${TELEGRAM_CHAT_ID}" # e.g. TELEGRAM_CHAT_ID=mychatid
    TelegramUrl="https://api.telegram.org/bot$TelegramToken"
    TelegramTopicID=12345678 ## Set to 0 if not using specific topic within chat
    TelegramData="{\"chat_id\":\"$TelegramChatId\",\"text\":\"$MessageBody\",\"message_thread_id\":\"$TelegramTopicID\",\"disable_notification\": false}"

    curl -sS -o /dev/null --fail -X POST "$TelegramUrl/sendMessage" -H 'Content-Type: application/json' -d "$TelegramData"
}
