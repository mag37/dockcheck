### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_HA_VERSION="v0.3"
#
# This is an integration that makes it possible to send notifications via Home Assistant (https://www.home-assistant.io/)
# It uses a REST API (https://developers.home-assistant.io/docs/api/rest/) call to
# the notify (https://www.home-assistant.io/integrations/notify/)
# or event (https://www.home-assistant.io/integrations/event/) integration.
# You need to generate a long-lived access token in Home Assistant to be used here (https://developers.home-assistant.io/docs/auth_api/#long-lived-access-token)
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish to make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set HA_URL and HA_TOKEN in your dockcheck.config file,
# the optional HA_INTEGRATION to 'notify' or 'event', and the optional HA_ENTITY to the notify service or event type.
# If unset, HA_INTEGRATION defaults to 'notify' and HA_ENTITY defaults to 'persistent_notification' (notify) or 'dockcheck' (event).
#
# Home Assistant event automation example:
# ----------------------------------------
# alias: dockcheck
# description: Handles dockcheck update notifications, replacing previous notifications per hostname.
# triggers:
#   - event_type: dockcheck
#     trigger: event
# conditions: []
# actions:
#   - variables:
#       hostname: "{{ trigger.event.data.hostname }}"
#       message: "{{ trigger.event.data.message }}"
#   - action: persistent_notification.dismiss
#     data:
#       notification_id: dockcheck_{{ hostname }}
#   - action: persistent_notification.create
#     data:
#       notification_id: dockcheck_{{ hostname }}
#       title: Docker updates on {{ hostname }}
#       message: "{{ message }}"
# mode: queued
# max: 10

trigger_HA_notification() {
  if [[ -n "$1" ]]; then
    HA_channel="$1"
  else
    HA_channel="HA"
  fi

  UpperChannel="${HA_channel^^}"

  HAUrlVar="${UpperChannel}_URL"
  HATokenVar="${UpperChannel}_TOKEN"
  HAIntegrationVar="${UpperChannel}_INTEGRATION"
  HAEntityVar="${UpperChannel}_ENTITY"

  if [[ -z "${!HAUrlVar:-}" ]] || [[ -z "${!HATokenVar:-}" ]]; then
    printf "The ${HA_channel} notification channel is enabled, but required configuration variables are missing. Home assistant notifications will not be sent.\n"
    remove_channel HA
    return 0
  fi

  AccessToken="${!HATokenVar}"
  if [[ "${!HAIntegrationVar:-notify}" = "notify" ]]; then
    Url="${!HAUrlVar}/api/services/notify/${!HAEntityVar:-persistent_notification}"
    JsonData=$( "$jqbin" -n \
                --arg body "$MessageBody" \
                '{"title": "dockcheck update", "message": $body}' )
  elif [[ "${!HAIntegrationVar:-}" = "event" ]]; then
    Url="${!HAUrlVar}/api/events/${!HAEntityVar:-dockcheck}"
    JsonData=$( "$jqbin" -n \
                --arg host "$FromHost" \
                --arg body "$MessageBody" \
                '{"hostname": $host, "message": $body}' )
  else
    printf "The ${HA_channel} notification channel is enabled, but the integration configuration variable is invalid. Home assistant notifications will not be sent.\n"
    remove_channel HA
    return 0
  fi

  curl -S -o /dev/null ${CurlArgs} \
    -H "Authorization: Bearer $AccessToken" \
    -H "Content-Type: application/json" \
    -d "$JsonData" -X POST $Url

  if [[ $? -gt 0 ]]; then
    NotifyError=true
  fi
}
