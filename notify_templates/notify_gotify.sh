### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_GOTIFY_VERSION="v0.5"
#
# Required receiving services must already be set up.
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set GOTIFY_TOKEN and GOTIFY_DOMAIN in your dockcheck.config file.

trigger_gotify_notification() {
  if [[ -n "$1" ]]; then
    gotify_channel="$1"
  else
    gotify_channel="gotify"
  fi

  UpperChannel="${gotify_channel^^}"

  GotifyTokenVar="${UpperChannel}_TOKEN"
  GotifyUrlVar="${UpperChannel}_DOMAIN"

  if [[ -z "${!GotifyTokenVar:-}" ]] || [[ -z "${!GotifyUrlVar:-}" ]]; then
    printf "The ${gotify_channel} notification channel is enabled, but required configuration variables are missing. Gotify notifications will not be sent.\n"

    remove_channel gotify
    return 0
  fi

  GotifyToken="${!GotifyTokenVar}" # e.g. GOTIFY_TOKEN=token-value
  GotifyUrl="${!GotifyUrlVar}/message?token=${GotifyToken}" # e.g. GOTIFY_URL=https://gotify.domain.tld

  if [[ "$PrintMarkdownURL" == true ]]; then
      ContentType="text/markdown"
  else
      ContentType="text/plain"
  fi

  JsonData=$( "$jqbin" -n \
                --arg body "$MessageBody" \
                --arg title "$MessageTitle" \
                --arg type "$ContentType" \
                '{message: $body, title: $title, priority: 5, extras: {"client::display": {"contentType": $type}}}' )

  curl -S -o /dev/null ${CurlArgs} --data "${JsonData}" -H 'Content-Type: application/json' -X POST "${GotifyUrl}" 1> /dev/null

  if [[ $? -gt 0 ]]; then
    NotifyError=true
  fi
}
