### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_TELEGRAM_VERSION="v0.5"
#
# Required receiving services must already be set up.
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set TELEGRAM_CHAT_ID and TELEGRAM_TOKEN in your dockcheck.config file.

trigger_telegram_notification() {
  if [[ -n "$1" ]]; then
    telegram_channel="$1"
  else
    telegram_channel="telegram"
  fi

  UpperChannel="${telegram_channel^^}"

  TelegramTokenVar="${UpperChannel}_TOKEN"
  TelegramChatIdVar="${UpperChannel}_CHAT_ID"
  TelegramTopicIdVar="${UpperChannel}_TOPIC_ID"

  if [[ -z "${!TelegramChatIdVar:-}" ]] || [[ -z "${!TelegramTokenVar:-}" ]]; then
    printf "The ${telegram_channel} notification channel is enabled, but required configuration variables are missing. Telegram notifications will not be sent.\n"

    remove_channel telegram
    return 1
  fi

  if [[ "$PrintMarkdownURL" == true ]]; then
      ParseMode="Markdown"
  else
      ParseMode="HTML"
  fi

  TelegramToken="${!TelegramTokenVar}" # e.g. TELEGRAM_TOKEN=token-value
  TelegramChatId="${!TelegramChatIdVar}" # e.g. TELEGRAM_CHAT_ID=mychatid
  TelegramUrl="https://api.telegram.org/bot$TelegramToken"
  TelegramTopicID=${!TelegramTopicIdVar:="0"}

  JsonData=$( "$jqbin" -n \
              --arg chatid "$TelegramChatId" \
              --arg text "$MessageBody" \
              --arg thread "$TelegramTopicID" \
              --arg parse_mode "$ParseMode" \
              '{"chat_id": $chatid, "text": $text, "message_thread_id": $thread, "disable_notification": false, "parse_mode": $parse_mode, "disable_web_page_preview": true}' )

  curl -S -o /dev/null ${CurlArgs} -X POST "$TelegramUrl/sendMessage" -H 'Content-Type: application/json' -d "$JsonData"

  if [[ $? -gt 0 ]]; then
    NotifyError=true
  fi
}
