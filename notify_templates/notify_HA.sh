### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_HA_VERSION="v0.2"
#
# This is an integration that makes it possible to send notifications via Home Assistant (https://www.home-assistant.io/integrations/notify/)
# You need to generate a long-lived access token in Home Sssistant to be used here (https://developers.home-assistant.io/docs/auth_api/#long-lived-access-token)
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set HA_ENTITY, HA_URL and HA_TOKEN in your dockcheck.config file.

trigger_HA_notification() {
  if [[ -n "$1" ]]; then
    HA_channel="$1"
    UpperChannel=$(tr '[:lower:]' '[:upper:]' <<< "$HA_channel")
  else
    HA_channel="HA"
    UpperChannel="HA"
  fi

  HAEntityVar="${UpperChannel}_ENTITY"
  HAUrlVar="${UpperChannel}_URL"
  HATokenVar="${UpperChannel}_TOKEN"

  if [[ -z "${!HAEntityVar:-}" ]] || [[ -z "${!HAUrlVar:-}" ]] || [[ -z "${!HATokenVar:-}" ]]; then
    printf "The ${HA_channel} notification channel is enabled, but required configuration variables are missing. Home assistant notifications will not be sent.\n"

    remove_channel HA
    return 1
  fi

  AccessToken="${!HATokenVar}"
  Url="${!HAUrlVar}/api/services/notify/${!HAEntityVar}"
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
