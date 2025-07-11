### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_HA_VERSION="v0.1"
#
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set HA_ENTITY, HA_URL and HA_TOKEN in your dockcheck.config file.

if [[ -z "${HA_ENTITY:-}" ]] || [[ -z "${HA_URL:-}" ]] || [[ -z "${HA_TOKEN:-}" ]]; then
  printf "Home Assistant notification channel enabled, but required configuration variables are missing. Home assistant notifications will not be sent.\n"

  remove_channel HA
fi

trigger_HA_notification() {
  AccessToken="${HA_TOKEN}"
  Url="${HA_URL}/api/services/notify/${HA_ENTITY}"
  JsonData=$( "$jqbin" -n \
              --arg body "$MessageBody" \
              '{"title": "dockcheck update", "message": $body}' )

  curl -S -o /dev/null ${CurlArgs} \
    -H "Authorization: Bearer $AccessToken" \
    -H "Content-Type: application/json" \
    -d "$JsonData" -X POST $Url

  if [[ $? -gt 0 ]]; then
    NotifyError=true
  fi
}
