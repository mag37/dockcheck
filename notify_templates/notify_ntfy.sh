### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_NTFYSH_VERSION="v0.7"
#
# Setup app and subscription at https://ntfy.sh
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set NTFY_DOMAIN and NTFY_TOPIC_NAME in your dockcheck.config file.

trigger_ntfy_notification() {
  if [[ -n "$1" ]]; then
    ntfy_channel="$1"
    UpperChannel=$(tr '[:lower:]' '[:upper:]' <<< "$ntfy_channel")
  else
    ntfy_channel="ntfy"
    UpperChannel="NTFY"
  fi

  NtfyDomainVar="${UpperChannel}_DOMAIN"
  NtfyTopicNameVar="${UpperChannel}_TOPIC_NAME"
  NtfyAuthVar="${UpperChannel}_AUTH"

  if [[ -z "${!GotifyTokenVar:-}" ]] || [[ -z "${!GotifyUrlVar:-}" ]]; then
    printf "The ${ntfy_channel} notification channel is enabled, but required configuration variables are missing. Ntfy notifications will not be sent.\n"

    remove_channel ntfy
    return 1
  fi

  NtfyUrl="${!NtfyDomainVar}/${!NtfyTopicNameVar}"
  # e.g.
  # NTFY_DOMAIN=ntfy.sh
  # NTFY_TOPIC_NAME=YourUniqueTopicName

  if [[ "$PrintMarkdownURL" == true ]]; then
      ContentType="Markdown: yes"
  else
      ContentType="Markdown: no" #text/plain
  fi

  if [[ -n "${!NtfyAuthVar:-}" ]]; then
    NtfyAuth="-u ${!NtfyAuthVar}"
  else
    NtfyAuth=""
  fi

  curl -S -o /dev/null ${CurlArgs} \
    -H "Title: $MessageTitle" \
    -H "$ContentType"      \
    -d "$MessageBody" \
    $NtfyAuth \
    -L "$NtfyUrl"

  if [[ $? -gt 0 ]]; then
    NotifyError=true
  fi
}
