### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_APPRISE_VERSION="v0.2"
#
# Required receiving services must already be set up.
# Leave (or place) this file in the "notify_templates" subdirectory in the same directory as your dockcheck.sh script. If you wish make your own modifications, copy it to your root folder.
# Do not modify this file directly within the "notify_templates" subdirectory. Set APPRISE_PAYLOAD in your dockcheck.config file.
# If API, set APPRISE_URL instead.

if [[ -z "${APPRISE_PAYLOAD:-}" ]] && [[ -z "${APPRISE_URL:-}" ]]; then
  printf "Apprise notification channel enabled, but required configuration variables are missing. Apprise notifications will not be sent.\n"

  remove_channel apprise
fi

trigger_apprise_notification() {

  if [[ -n "${APPRISE_PAYLOAD:-}" ]]; then
    apprise -vv -t "$MessageTitle" -b "$MessageBody" \
      ${APPRISE_PAYLOAD}
  fi

  # e.g. APPRISE_PAYLOAD='mailto://myemail:mypass@gmail.com
  #                      mastodons://{token}@{host}
  #                      pbul://o.gn5kj6nfhv736I7jC3cj3QLRiyhgl98b
  #                      tgram://{bot_token}/{chat_id}/'

  if [[ -n "${APPRISE_URL:-}" ]]; then
    AppriseURL="${APPRISE_URL}"
    curl -X POST -F "title=$MessageTitle" -F "body=$MessageBody" -F "tags=all" $AppriseURL # e.g. APPRISE_URL=http://apprise.mydomain.tld:1234/notify/apprise
  fi
}