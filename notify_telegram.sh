### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Required receiving services must already be set up.
# Modify to fit your setup - set TelegramChatId and TelegramToken.

send_notification() {
    Updates=("$@")
    UpdToString=$( printf "%s\n" "${Updates[@]}" )
    FromHost=$(hostname)
    
    # platform specific notification code would go here
    printf "\nSending Telegram notification\n"
    
    # Setting the MessageBody variable here.
    MessageBody="🐋 Containers on $FromHost with updates available: \n$UpdToString"
    
    # Modify to fit your setup:
    TelegramToken="Your Telegram token here"
    TelegramChatId="Your Telegram ChatId here"
    TelegramUrl="https://api.telegram.org/bot$TelegramToken"
    TelegramTopicID=12345678 ## Set to 0 if not using specific topic within chat
    TelegramData="{\"chat_id\":\"$TelegramChatId\",\"text\":\"$MessageBody\",\"message_thread_id\":\"$TelegramTopicID\",\"disable_notification\": false}"
    
    curl -sS -o /dev/null --fail -X POST "$TelegramUrl/sendMessage" -H 'Content-Type: application/json' -d "$TelegramData"
    
}
