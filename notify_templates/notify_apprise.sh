### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_APPRISE_VERSION="v0.4"
#
# Required receiving services must already be set up.
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set APPRISE_PAYLOAD in your dockcheck.config file.
# If API, set APPRISE_URL instead.

trigger_apprise_notification() {
  if [[ -n "$1" ]]; then
    apprise_channel="$1"
    UpperChannel=$(tr '[:lower:]' '[:upper:]' <<< "$apprise_channel")
  else
    apprise_channel="apprise"
    UpperChannel="APPRISE"
  fi

  ApprisePayloadVar="${UpperChannel}_PAYLOAD"
  AppriseUrlVar="${UpperChannel}_URL"

  if [[ -z "${!ApprisePayloadVar:-}" ]] && [[ -z "${!AppriseUrlVar:-}" ]]; then
    printf "The ${apprise_channel} notification channel is enabled, but required configuration variables are missing. Apprise notifications will not be sent.\n"

    remove_channel apprise
    return 1
  fi

  if [[ -n "${!ApprisePayloadVar:-}" ]]; then
    apprise -vv -t "$MessageTitle" -b "$MessageBody" \
      ${!ApprisePayloadVar}

    if [[ $? -gt 0 ]]; then
      NotifyError=true
    fi
  fi

  # e.g. APPRISE_PAYLOAD='mailto://myemail:mypass@gmail.com
  #                      mastodons://{token}@{host}
  #                      pbul://o.gn5kj6nfhv736I7jC3cj3QLRiyhgl98b
  #                      tgram://{bot_token}/{chat_id}/'

  if [[ -n "${!AppriseUrlVar:-}" ]]; then
    AppriseURL="${!AppriseUrlVar}"
    curl -S -o /dev/null ${CurlArgs} -X POST -F "title=$MessageTitle" -F "body=$MessageBody" -F "tags=all" $AppriseURL # e.g. APPRISE_URL=http://apprise.mydomain.tld:1234/notify/apprise

    if [[ $? -gt 0 ]]; then
      NotifyError=true
    fi
  fi
}