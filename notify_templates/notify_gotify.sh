#!/usr/bin/env bash

# Gotify notification template for podcheck v2
# Requires: GOTIFY_DOMAIN, GOTIFY_TOKEN

if [[ -z "${GOTIFY_DOMAIN:-}" ]] || [[ -z "${GOTIFY_TOKEN:-}" ]]; then
  echo "Error: GOTIFY_DOMAIN and GOTIFY_TOKEN must be configured"
  return 1
fi

# Prepare the Gotify message
if [[ -n "${NOTIFICATION_MESSAGE:-}" ]]; then
  # Build Gotify URL
  gotify_url="${GOTIFY_DOMAIN}/message?token=${GOTIFY_TOKEN}"
  
  # Send to Gotify
  if curl -F "title=${NOTIFICATION_TITLE:-Podcheck Notification}" \
          -F "message=${NOTIFICATION_MESSAGE}" \
          -F "priority=5" \
          -X POST "${gotify_url}" \
          ${CurlArgs:-} &>/dev/null; then
    return 0
  else
    echo "Failed to send Gotify notification"
    return 1
  fi
else
  echo "No notification message provided"
  return 1
fi
