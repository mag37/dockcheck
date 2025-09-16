#!/usr/bin/env bash

# notify_v2.sh - Advanced notification wrapper for podcheck
# This is the main notification dispatch system

# Get hostname for notifications
# Try multiple methods to get hostname
if [[ -s "/etc/hostname" ]]; then
  HOSTNAME=$(cat /etc/hostname)
elif command -v hostname &>/dev/null; then
  HOSTNAME=$(hostname)
else
  HOSTNAME="podcheck-host"
fi

# Default notification channels if not configured
NOTIFY_CHANNELS=${NOTIFY_CHANNELS:-""}

# Check if any channels are configured
if [[ -z "${NOTIFY_CHANNELS}" ]]; then
  echo "No notification channels configured. Set NOTIFY_CHANNELS in podcheck.config"
  return 1
fi

# Function to check if a notification should be sent based on snooze
should_send_notification() {
  local notification_type="$1"
  local snooze_file="${ScriptWorkDir}/.snooze_${notification_type}"
  local current_time=$(date +%s)
  
  # If snooze is not enabled, always send
  if [[ -z "${SNOOZE_SECONDS:-}" ]]; then
    return 0
  fi
  
  # Check if snooze file exists and is recent
  if [[ -f "$snooze_file" ]]; then
    local last_notification=$(cat "$snooze_file" 2>/dev/null || echo "0")
    local time_diff=$((current_time - last_notification))
    
    if [[ $time_diff -lt ${SNOOZE_SECONDS} ]]; then
      return 1  # Don't send notification
    fi
  fi
  
  # Update snooze file
  echo "$current_time" > "$snooze_file"
  return 0  # Send notification
}

# Function to format output based on type
format_output() {
  local format="$1"
  local title="$2"
  shift 2
  local containers=("$@")
  
  case "$format" in
    "json")
      local container_json=""
      for container in "${containers[@]}"; do
        if [[ -n "$container_json" ]]; then
          container_json="${container_json},"
        fi
        container_json="${container_json}\"${container}\""
      done
      echo "{\"title\":\"${title}\",\"hostname\":\"${HOSTNAME}\",\"containers\":[${container_json}]}"
      ;;
    "csv")
      local container_csv=""
      for container in "${containers[@]}"; do
        if [[ -n "$container_csv" ]]; then
          container_csv="${container_csv},"
        fi
        container_csv="${container_csv}${container}"
      done
      echo "${title},${HOSTNAME},${container_csv}"
      ;;
    "text"|*)
      echo "${title} on ${HOSTNAME}:"
      for container in "${containers[@]}"; do
        echo "  - ${container}"
      done
      ;;
  esac
}

# Main notification function for container updates
send_notification() {
  local containers=("$@")
  
  # If no containers provided, exit early unless ALLOWEMPTY is set
  if [[ ${#containers[@]} -eq 0 ]]; then
    # Check if any channel allows empty notifications
    local send_empty=false
    for channel in ${NOTIFY_CHANNELS}; do
      local channel_upper=$(echo "$channel" | tr '[:lower:]' '[:upper:]')
      local allow_empty_var="${channel_upper}_ALLOWEMPTY"
      if [[ "${!allow_empty_var:-false}" == "true" ]]; then
        send_empty=true
        break
      fi
    done
    
    if [[ "$send_empty" == "false" ]]; then
      return 0
    fi
  fi
  
  # Check snooze for container notifications
  if ! should_send_notification "containers"; then
    echo "Container update notification snoozed"
    return 0
  fi
  
  # Send notifications to each configured channel
  for channel in ${NOTIFY_CHANNELS}; do
    local channel_upper=$(echo "$channel" | tr '[:lower:]' '[:upper:]')
    
    # Check if this channel should skip snooze
    local skip_snooze_var="${channel_upper}_SKIPSNOOZE"
    if [[ "${!skip_snooze_var:-false}" == "true" ]]; then
      # Force send by updating snooze file
      echo "$(date +%s)" > "${ScriptWorkDir}/.snooze_containers"
    fi
    
    # Check if this channel is containers only
    local containers_only_var="${channel_upper}_CONTAINERSONLY"
    if [[ "${!containers_only_var:-false}" == "true" && ${#containers[@]} -eq 0 ]]; then
      continue
    fi
    
    # Get the template to use (default to channel name)
    local template_var="${channel_upper}_TEMPLATE"
    local template="${!template_var:-$channel}"
    
    # Get output format
    local output_var="${channel_upper}_OUTPUT"
    local output_format="${!output_var:-text}"
    
    # Format the message
    local title="Containers with updates available"
    if [[ ${#containers[@]} -eq 0 ]]; then
      title="No container updates available"
    fi
    
    local message=$(format_output "$output_format" "$title" "${containers[@]}")
    
    # Source and execute the notification template
    local template_file="${ScriptWorkDir}/notify_templates/notify_${template}.sh"
    if [[ -f "$template_file" ]]; then
      # Export message for template to use
      export NOTIFICATION_MESSAGE="$message"
      export NOTIFICATION_TITLE="$title"
      export NOTIFICATION_CONTAINERS=("${containers[@]}")
      
      if source "$template_file"; then
        echo "Notification sent via $channel ($template)"
      else
        echo "Failed to send notification via $channel ($template)"
      fi
    else
      echo "Notification template not found: $template_file"
    fi
  done
}

# Function for podcheck self-update notifications
podcheck_notification() {
  local current_version="$1"
  local latest_version="$2"
  local changes="$3"
  
  # Check if podcheck notifications are disabled
  if [[ "${DISABLE_PODCHECK_NOTIFICATION:-false}" == "true" ]]; then
    return 0
  fi
  
  # Check snooze
  if ! should_send_notification "podcheck"; then
    echo "Podcheck update notification snoozed"
    return 0
  fi
  
  local title="Podcheck update available"
  local message="$title: $current_version → $latest_version"
  if [[ -n "$changes" ]]; then
    message="$message\nChanges: $changes"
  fi
  
  # Send to configured channels
  for channel in ${NOTIFY_CHANNELS}; do
    local channel_upper=$(echo "$channel" | tr '[:lower:]' '[:upper:]')
    
    # Get the template to use
    local template_var="${channel_upper}_TEMPLATE"
    local template="${!template_var:-$channel}"
    
    # Get output format
    local output_var="${channel_upper}_OUTPUT"
    local output_format="${!output_var:-text}"
    
    local formatted_message=$(format_output "$output_format" "$title" "podcheck: $current_version → $latest_version")
    
    # Source and execute the notification template
    local template_file="${ScriptWorkDir}/notify_templates/notify_${template}.sh"
    if [[ -f "$template_file" ]]; then
      export NOTIFICATION_MESSAGE="$formatted_message"
      export NOTIFICATION_TITLE="$title"
      
      if source "$template_file"; then
        echo "Podcheck update notification sent via $channel"
      else
        echo "Failed to send podcheck notification via $channel"
      fi
    fi
  done
}

# Function for notify template update notifications
notify_update_notification() {
  # Check if notify notifications are disabled
  if [[ "${DISABLE_NOTIFY_NOTIFICATION:-false}" == "true" ]]; then
    return 0
  fi
  
  # Check snooze
  if ! should_send_notification "notify"; then
    echo "Notify template update notification snoozed"
    return 0
  fi
  
  local title="Notification templates updated"
  local message="Notification templates have been updated"
  
  # Send to configured channels
  for channel in ${NOTIFY_CHANNELS}; do
    local channel_upper=$(echo "$channel" | tr '[:lower:]' '[:upper:]')
    
    local template_var="${channel_upper}_TEMPLATE"
    local template="${!template_var:-$channel}"
    
    local template_file="${ScriptWorkDir}/notify_templates/notify_${template}.sh"
    if [[ -f "$template_file" ]]; then
      export NOTIFICATION_MESSAGE="$message"
      export NOTIFICATION_TITLE="$title"
      
      if source "$template_file"; then
        echo "Notify update notification sent via $channel"
      fi
    fi
  done
}