NOTIFY_V2_VERSION="v0.6"
#
# If migrating from an older notify template, remove your existing notify.sh file.
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script and rename to notify.sh.
# Enable and configure all required notification variables in your dockcheck.config file, e.g.:
# NOTIFY_CHANNELS=apprise gotify slack
# SLACK_TOKEN=xoxb-some-token-value
# GOTIFY_TOKEN=some.token

# Number of seconds to snooze identical update notifications based on local image name
# or dockcheck.sh/notify.sh template file updates.
# Actual snooze will be 60 seconds less to avoid the chance of missed notifications due to minor scheduling or script run time issues.
snooze="${SNOOZE_SECONDS:-}"
SnoozeFile="${ScriptWorkDir}/snooze.list"
[[ ! -f "${SnoozeFile}" ]] && touch "${SnoozeFile}"

enabled_notify_channels=( ${NOTIFY_CHANNELS:-} )

# Global output string variable for modification by functions
UpdToString=""
FormattedOutput=""

get_channel_template() {
  local UpperChannel="${1^^}"
  local TemplateVar="${UpperChannel}_TEMPLATE"
  if [[ -n "${!TemplateVar:-}" ]]; then
    printf "${!TemplateVar}"
  else
    printf "$1"
  fi
}

declare -A unique_templates

for channel in "${enabled_notify_channels[@]}"; do
  template=$(get_channel_template "${channel}")
  unique_templates["${template}"]=1
done

enabled_notify_templates=( "${!unique_templates[@]}" )

FromHost=$(cat /etc/hostname)

CurrentEpochTime=$(date +"%Y-%m-%dT%H:%M:%S")
CurrentEpochSeconds=$(date +%s)

NotifyError=false

for template in "${enabled_notify_templates[@]}"; do
  source_if_exists_or_fail "${ScriptWorkDir}/notify_${template}.sh" || \
  source_if_exists_or_fail "${ScriptWorkDir}/notify_templates/notify_${template}.sh" || \
  printf "The notification channel template ${template} is enabled, but notify_${template}.sh was not found. Check the ${ScriptWorkDir} directory or the notify_templates subdirectory.\n"
done

skip_snooze() {
  local UpperChannel="${1^^}"
  local SkipSnoozeVar="${UpperChannel}_SKIPSNOOZE"
  if [[ "${!SkipSnoozeVar:-}" == "true" ]]; then
    printf "true"
  else
    printf "false"
  fi
}

allow_empty() {
  local UpperChannel="${1^^}"
  local AllowEmptyVar="${UpperChannel}_ALLOWEMPTY"
  if [[ "${!AllowEmptyVar:-}" == "true" ]]; then
    printf "true"
  else
    printf "false"
  fi
}

containers_only() {
  local UpperChannel="${1^^}"
  local ContainersOnlyVar="${UpperChannel}_CONTAINERSONLY"
  if [[ "${!ContainersOnlyVar:-}" == "true" ]]; then
    printf "true"
  else
    printf "false"
  fi
}

output_format() {
  local UpperChannel="${1^^}"
  local OutputFormatVar="${UpperChannel}_OUTPUT"
  if [[ -z "${!OutputFormatVar:-}" ]]; then
    printf "text"
  else
    printf "${!OutputFormatVar:-}"
  fi
}

remove_channel() {
  local temp_array=()
  for channel in "${enabled_notify_channels[@]}"; do
    local channel_template=$(get_channel_template "${channel}")
    [[ "${channel_template}" != "$1" ]] && temp_array+=("${channel}")
  done
  enabled_notify_channels=( "${temp_array[@]}" )
}

is_snoozed() {
  if [[ -n "${snooze}" ]] && [[ -f "${SnoozeFile}" ]]; then
    local found=$(grep -w "$1" "${SnoozeFile}" || printf "")
    if [[ -n "${found}" ]]; then
      read -a arr <<< "${found}"
      CheckEpochSeconds=$(( $(date -d "${arr[1]}" +%s 2>/dev/null) + ${snooze} - 60 )) || CheckEpochSeconds=$(( $(date -f "%Y-%m-%d" -j "${arr[1]}" +%s) + ${snooze} - 60 ))
      if [[ "${CurrentEpochSeconds}" -le "${CheckEpochSeconds}" ]]; then
        printf "true"
      else
        printf "false"
      fi
    else
      printf "false"
    fi
  else
    printf "false"
  fi
}

unsnoozed_count() {
  unset Unsnoozed
  Unsnoozed=()

  for element in "$@"
  do
    read -a item <<< "${element}"
    if [[ $(is_snoozed "${item[0]}") == "false" ]]; then
      Unsnoozed+=("${element}")
    fi
  done

  printf "${#Unsnoozed[@]}"
}

update_snooze() {
  for arg in "$@"
  do
    read -a entry <<< "${arg}"
    found=$(grep -w "${entry[0]}" "${SnoozeFile}" || printf "")

    if [[ -n "${found}" ]]; then
      sed -e "s/${entry[0]}.*/${entry[0]} ${CurrentEpochTime}/" "${SnoozeFile}" > "${SnoozeFile}.new"
      mv "${SnoozeFile}.new" "${SnoozeFile}"
    else
      printf "${entry[0]} ${CurrentEpochTime}\n" >> "${SnoozeFile}"
    fi
  done
}

cleanup_snooze() {
  unset NotifyEntries
  NotifyEntries=()
  switch=""

  for arg in "$@"
  do
    read -a entry <<< "${arg}"
    NotifyEntries+=("${entry[0]}")
  done

  if [[ ! "${NotifyEntries[@]}" == *".sh"* ]]; then
    switch="-v"
  fi

  while read -r entry datestamp; do
    if [[ ! "${NotifyEntries[@]}" == *"$entry"* ]]; then
      sed -e "/${entry}/d" "${SnoozeFile}" > "${SnoozeFile}.new"
      mv "${SnoozeFile}.new" "${SnoozeFile}"
    fi
  done <<< "$(grep ${switch} '\.sh ' ${SnoozeFile})"
}

format_output() {
  local UpdateType="$1"
  local OutputFormat="$2"
  local FormattedTextTemplate="$3"
  local tempcsv=""

  if [[ ! "${UpdateType}" == "dockcheck_update" ]]; then
    tempcsv="${UpdToString//  ->  /,}"
    tempcsv="${tempcsv//.sh /.sh,}"
  else
    tempcsv="${UpdToString}"
  fi

  if [[ "${OutputFormat}" == "csv" ]]; then
    if [[ -z "${UpdToString}" ]]; then
      FormattedOutput="None"
    else
      FormattedOutput="${tempcsv}"
    fi
  elif [[ "${OutputFormat}" == "json" ]]; then
    if [[ -z "${UpdToString}" ]]; then
      FormattedOutput='{"updates": []}'
    else
      if [[ "${UpdateType}" == "container_update" ]]; then
        # container updates case
        FormattedOutput=$(jq --compact-output --null-input --arg updates "${tempcsv}" '($updates | split("\\n")) | map(split(",")) | {"updates": map({"container_name": .[0], "release_notes": .[1]})} | del(..|nulls)')
      elif [[ "${UpdateType}" == "notify_update" ]]; then
        # script updates case
        FormattedOutput=$(jq --compact-output --null-input --arg updates "${tempcsv}" '($updates | split("\\n")) | map(split(",")) | {"updates": map({"script_name": .[0], "installed_version": .[1], "latest_version": .[2]})}')
      elif [[ "${UpdateType}" == "dockcheck_update" ]]; then
        # dockcheck update case
        FormattedOutput=$(jq --compact-output --null-input --arg updates "${tempcsv}" '($updates | split("\\n")) | map(split(",")) | {"updates": map({"script_name": .[0], "installed_version": .[1], "latest_version": .[2], "release_notes": (.[3:] | join(","))})}')
      else
        FormattedOutput="Invalid input"
      fi
    fi
  else
    if [[ -z "${UpdToString}" ]]; then
      FormattedOutput="None"
    else
      if [[ "${UpdateType}" == "container_update" ]]; then
        FormattedOutput="${FormattedTextTemplate/<insert_text_cu>/${UpdToString}}"
      elif [[ "${UpdateType}" == "notify_update" ]]; then
        FormattedOutput="${FormattedTextTemplate/<insert_text_nu>/${UpdToString}}"
      elif [[ "${UpdateType}" == "dockcheck_update" ]]; then
        FormattedOutput="${FormattedTextTemplate/<insert_text_iv>/$4}"
        FormattedOutput="${FormattedOutput/<insert_text_lv>/$5}"
        FormattedOutput="${FormattedOutput/<insert_text_rn>/$6}"
      else
        FormattedOutput="Invalid input"
      fi
    fi
  fi
}

send_notification() {
  [[ -s "$ScriptWorkDir"/urls.list ]] && releasenotes || Updates=("$@")

  UnsnoozedContainers=$(unsnoozed_count "${Updates[@]}")
  NotifyError=false
  Notified="false"

  # To be added in the MessageBody if "-d X" was used
  # Trailing space is left intentionally for clean output
  [[ -n "$DaysOld" ]] && msgdaysold="with images ${DaysOld}+ days old " || msgdaysold=""
  MessageTitle="$FromHost - updates ${msgdaysold}available."

  UpdToString=$( printf '%s\\n' "${Updates[@]}" )
  UpdToString="${UpdToString%, }"
  UpdToString=${UpdToString%\\n}

  for channel in "${enabled_notify_channels[@]}"; do
    local template=$(get_channel_template "${channel}")

    # Formats UpdToString variable per channel settings
    format_output "container_update" "$(output_format "${channel}")" "🐋 Containers on $FromHost with updates available:\n<insert_text_cu>\n"

    # Setting the MessageBody variable here.
    printf -v MessageBody "${FormattedOutput}"

    if { { [[ "${MessageBody}" == "None" ]] || [[ "${MessageBody}" == '{"updates": []}' ]]; } && [[ $(allow_empty "${channel}") == "true" ]]; } || { [[ $(skip_snooze "${channel}") == "true" ]] || [[ ${UnsnoozedContainers} -gt 0 ]]; }; then
      printf "\nSending ${channel} notification"
      exec_if_exists_or_fail trigger_${template}_notification "${channel}" || \
      printf "\nAttempted to send notification to channel ${channel}, but the function was not found. Make sure notify_${template}.sh is available in the ${ScriptWorkDir} directory or notify_templates subdirectory."
      Notified="true"
    fi
  done

  if [[ "${Notified}" == "true" ]]; then
    [[ -n "${snooze}" ]] && [[ "${NotifyError}" == "false" ]] && [[ "${FormattedOutput}" != "None" ]] && [[ "${Notified}" == "true" ]] && update_snooze "${Updates[@]}"
    printf "\n"
  fi
  [[ -n "${snooze}" ]] && [[ "${FormattedOutput}" != "None" ]] && cleanup_snooze "${Updates[@]}"

  return 0
}

### Set DISABLE_DOCKCHECK_NOTIFICATION=false in dockcheck.config
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
  if [[ ! "${DISABLE_DOCKCHECK_NOTIFICATION:-}" == "true" ]]; then
    NotifyError=false
    Notified=false

    MessageTitle="$FromHost - New version of dockcheck available."
    UpdToString="dockcheck.sh,$1,$2,\"$3\""

    for channel in "${enabled_notify_channels[@]}"; do
      local template=$(get_channel_template "${channel}")

      # Formats UpdToString variable per channel settings
      format_output "dockcheck_update" "$(output_format "${channel}")" "Installed version: <insert_text_iv>\nLatest version: <insert_text_lv>\n\nChangenotes: <insert_text_rn>\n" "$1" "$2" "$3"

      # Setting the MessageBody variable here.
      printf -v MessageBody "${FormattedOutput}"

      if { { [[ "${MessageBody}" == "None" ]] || [[ "${MessageBody}" == '{"updates": []}' ]]; } && [[ $(allow_empty "${channel}") == "true" ]]; } && { [[ $(skip_snooze "${channel}") == "true" ]] || [[ $(is_snoozed "dockcheck\.sh") == "false" ]]; } && [[ $(containers_only "${channel}") == "false" ]]; then
        printf "\nSending dockcheck update notification - ${channel}"
        exec_if_exists_or_fail trigger_${template}_notification "${channel}" || \
        printf "\nAttempted to send notification to channel ${channel}, but the function was not found. Make sure notify_${template}.sh is available in the ${ScriptWorkDir} directory or notify_templates subdirectory."
        Notified="true"
      fi
    done

    if [[ "${Notified}" == "true" ]]; then
      [[ -n "${snooze}" ]] && [[ "${NotifyError}" == "false" ]] && update_snooze "dockcheck.sh"
      printf "\n"
    fi
  fi

  return 0
}

### Set DISABLE_NOTIFY_NOTIFICATION=false in dockcheck.config
### to not send notifications when notify scripts themselves have updates.
notify_update_notification() {
  if [[ ! "${DISABLE_NOTIFY_NOTIFICATION:-}" == "true" ]]; then
    NotifyError=false
    NotifyUpdates=()
    Notified=false

    UpdateChannels=( "${enabled_notify_templates[@]}" "v2" )

    for NotifyScript in "${UpdateChannels[@]}"; do
      UpperChannel="${NotifyScript^^}"
      VersionVar="NOTIFY_${UpperChannel}_VERSION"
      if [[ -n "${!VersionVar:-}" ]]; then
        RawNotifyUrl="https://raw.githubusercontent.com/mag37/dockcheck/main/notify_templates/notify_${NotifyScript}.sh"
        LatestNotifySnippet="$(curl ${CurlArgs} -r 0-150 "$RawNotifyUrl" || printf "undefined")"
        if [[ ! "${LatestNotifySnippet}" == "undefined" ]]; then
          LatestNotifyRelease="$(echo "$LatestNotifySnippet" | sed -n "/${VersionVar}/s/${VersionVar}=//p" | tr -d '"')"

          if [[ "${!VersionVar}" != "${LatestNotifyRelease}" ]] ; then
            NotifyUpdates+=("${NotifyScript}.sh ${!VersionVar}  ->  ${LatestNotifyRelease}")
          fi
        fi
      fi
    done

    UnsnoozedTemplates=$(unsnoozed_count "${NotifyUpdates[@]}")

    MessageTitle="$FromHost - New version of notify templates available."

    UpdToString=$( printf '%s\\n' "${NotifyUpdates[@]}" )
    UpdToString="${UpdToString%, }"
    UpdToString=${UpdToString%\\n}

    for channel in "${enabled_notify_channels[@]}"; do
      local template=$(get_channel_template "${channel}")

      # Formats UpdToString variable per channel settings
      format_output "notify_update" "$(output_format "${channel}")" "Notify templates on $FromHost with updates available:\n<insert_text_nu>\n"

      # Setting the MessageBody variable here.
      printf -v MessageBody "${FormattedOutput}"

      if { { [[ "${MessageBody}" == "None" ]] || [[ "${MessageBody}" == '{"updates": []}' ]]; } && [[ $(allow_empty "${channel}") == "true" ]]; } && { [[ $(skip_snooze "${channel}") == "true" ]] || [[ ${UnsnoozedTemplates} -gt 0 ]]; } && [[ $(containers_only "${channel}") == "false" ]]; then
        printf "\nSending notify template update notification - ${channel}"
        exec_if_exists_or_fail trigger_${template}_notification "${channel}" || \
        printf "\nAttempted to send notification to channel ${channel}, but the function was not found. Make sure notify_${template}.sh is available in the ${ScriptWorkDir} directory or notify_templates subdirectory."
        Notified="true"
      fi
    done

    if [[ "${Notified}" == "true" ]]; then
      [[ -n "${snooze}" ]] && [[ "${NotifyError}" == "false" ]] && [[ "${FormattedOutput}" != "None" ]] && [[ "${Notified}" == "true" ]] && update_snooze "${NotifyUpdates[@]}"
      printf "\n"
    fi

    UpdatesPlusDockcheck=("${NotifyUpdates[@]}")
    UpdatesPlusDockcheck+=("dockcheck.sh")
    [[ -n "${snooze}" ]] && [[ "${FormattedOutput}" != "None" ]] && cleanup_snooze "${UpdatesPlusDockcheck[@]}"
  fi

  return 0
}
