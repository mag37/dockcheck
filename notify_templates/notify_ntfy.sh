### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_NTFYSH_VERSION="v0.5"
#
# Setup app and subscription at https://ntfy.sh
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set NTFY_DOMAIN and NTFY_TOPIC_NAME in your dockcheck.config file.

if [[ -z "${NTFY_DOMAIN:-}" ]] || [[ -z "${NTFY_TOPIC_NAME:-}" ]]; then
  printf "Ntfy notification channel enabled, but required configuration variables are missing. Ntfy notifications will not be sent.\n"

  remove_channel ntfy
fi

trigger_ntfy_notification() {
  NtfyUrl="${NTFY_DOMAIN}/${NTFY_TOPIC_NAME}"
  # e.g.
  # NTFY_DOMAIN=ntfy.sh
  # NTFY_TOPIC_NAME=YourUniqueTopicName

  if [[ "$PrintMarkdownURL" == true ]]; then
      ContentType="Markdown: yes"
  else
      ContentType="Markdown: no" #text/plain
  fi

  curl -S -o /dev/null ${CurlArgs} \
    -H "Title: $MessageTitle" \
    -H "$ContentType"      \
    -d "$MessageBody" \
    "$NtfyUrl"

  if [[ $? -gt 0 ]]; then
    NotifyError=true
  fi
}
