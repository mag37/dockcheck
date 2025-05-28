### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_NTFYSH_VERSION="v0.4"
#
# Setup app and subscription at https://ntfy.sh
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set NTFY_DOMAIN and NTFY_TOPIC_NAME in your dockcheck.config file.

if [[ -z "${NTFY_DOMAIN:-}" ]] || [[ -z "${NTFY_TOPIC_NAME:-}" ]]; then
  printf "Ntfy.sh notification channel enabled, but required configuration variables are missing. Ntfy.sh notifications will not be sent.\n"

  remove_channel ntfy-sh
fi

trigger_ntfy-sh_notification() {
  NtfyUrl="${NTFY_DOMAIN}/${NTFY_TOPIC_NAME}"
  # e.g.
  # NTFY_DOMAIN=ntfy.sh
  # NTFY_TOPIC_NAME=YourUniqueTopicName

  if [[ "$PrintMarkdownURL" == true ]]; then
      ContentType="Markdown: yes"
  else
      ContentType="Markdown: no" #text/plain
  fi

  curl -sS -o /dev/null --show-error --fail \
    -H "Title: $MessageTitle" \
    -H "$ContentType"      \
    -d "$MessageBody" \
    "$NtfyUrl"
}
