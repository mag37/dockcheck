### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_TELEGRAM_VERSION="v0.4"
#
# Required receiving services must already be set up.
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set TELEGRAM_CHAT_ID and TELEGRAM_TOKEN in your dockcheck.config file.

if [[ -z "${TELEGRAM_CHAT_ID:-}" ]] || [[ -z "${TELEGRAM_TOKEN:-}" ]]; then
  printf "Telegram notification channel enabled, but required configuration variables are missing. Telegram notifications will not be sent.\n"

  remove_channel telegram
fi

trigger_telegram_notification() {
  if [[ "$PrintMarkdownURL" == true ]]; then
      ParseMode="Markdown"
  else
      ParseMode="HTML"
  fi

  TelegramToken="${TELEGRAM_TOKEN}" # e.g. TELEGRAM_TOKEN=token-value
  TelegramChatId="${TELEGRAM_CHAT_ID}" # e.g. TELEGRAM_CHAT_ID=mychatid
  TelegramUrl="https://api.telegram.org/bot$TelegramToken"
  TelegramTopicID=${TELEGRAM_TOPIC_ID:="0"}

  JsonData=$( "$jqbin" -n \
              --arg chatid "$TelegramChatId" \
              --arg text "$MessageBody" \
              --arg thread "$TelegramTopicID" \
              --arg parse_mode "$ParseMode" \
              '{"chat_id": $chatid, "text": $text, "message_thread_id": $thread, "disable_notification": false, "parse_mode": $parse_mode, "disable_web_page_preview": true}' )

  curl -sSf -o /dev/null ${CurlArgs} -X POST "$TelegramUrl/sendMessage" -H 'Content-Type: application/json' -d "$JsonData"

  if [[ $? -gt 0 ]]; then
    NotifyError=true
  fi
}
