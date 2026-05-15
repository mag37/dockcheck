### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_APPRISE_VERSION="v0.5"
#
# Required receiving services must already be set up.
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set APPRISE_PAYLOAD in your dockcheck.config file.
# If API, set APPRISE_URL instead.

trigger_apprise_notification() {
  if [[ -n "$1" ]]; then
    apprise_channel="$1"
  else
    apprise_channel="apprise"
  fi

  UpperChannel="${apprise_channel^^}"

  ApprisePayloadVar="${UpperChannel}_PAYLOAD"
  AppriseUrlVar="${UpperChannel}_URL"

  if [[ -z "${!ApprisePayloadVar:-}" ]] && [[ -z "${!AppriseUrlVar:-}" ]]; then
    printf "The ${apprise_channel} notification channel is enabled, but required configuration variables are missing. Apprise notifications will not be sent.\n"

    remove_channel apprise
    return 0
  fi

  if [[ -n "${!ApprisePayloadVar:-}" ]]; then
    apprise -vv -t "$MessageTitle" -b "$MessageBody" \
      ${!ApprisePayloadVar}

    if [[ $? -gt 0 ]]; then
      NotifyError=true
    fi
  fi

  if [[ -n "${!AppriseUrlVar:-}" ]]; then
    AppriseURL="${!AppriseUrlVar}"
    curl -S -o /dev/null ${CurlArgs} -X POST -F "title=$MessageTitle" -F "body=$MessageBody" -F "tags=${APPRISE_TAG:-all}" "$AppriseURL"

    if [[ $? -gt 0 ]]; then
      NotifyError=true
    fi
  fi
}
