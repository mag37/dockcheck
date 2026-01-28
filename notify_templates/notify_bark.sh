#!/bin/bash

# NOTIFY_BARK_VERSION="v1.0"

trigger_bark_notification() {
    local channel="$1"

    if [[ -z "$jqbin" ]]; then
        for path in "$jqbin" "jq" "./jq" "../jq" "./jq-linux-TEMP" "../jq-linux-TEMP"; do
            if command -v "$path" &>/dev/null; then jqbin="$path"; break; fi
        done
    fi
    [[ -z "$jqbin" ]] && { echo "Error: jq missing"; return 1; }

    [[ -z "$BARK_KEY" ]] && { echo "Error: Key not set"; return 1; }

    local sound="${BARK_SOUND:-hello}"
    local group="${BARK_GROUP:-Dockcheck}"
    local icon_url="${BARK_ICON_URL:-https://raw.githubusercontent.com/mag37/dockcheck/main/logo.png}"
    

    local title="${MessageTitle%.}"
    local newline=$'\n'
    local formatted_body="## $title${newline}${newline}---${newline}${newline}$MessageBody"

    local json_payload=$( "$jqbin" -n \
        --arg title "$title" \
        --arg body "$formatted_body" \
        --arg group "$group" \
        --arg sound "$sound" \
        --arg icon "$icon_url" \
        '{
            "title": $title,
            "markdown": $body,
            "group": $group,
            "sound": $sound,
            "icon": $icon,
        }' )


    if curl -s -f -X POST "https://api.day.app/$BARK_KEY" \
        -H "Content-Type: application/json; charset=utf-8" \
        -d "$json_payload" > /dev/null 2>&1; then
        echo "Bark notification sent successfully (Markdown): $title"
    fi
}