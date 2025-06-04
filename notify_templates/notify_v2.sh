NOTIFY_V2_VERSION="v0.3"
#
# If migrating from an older notify template, remove your existing notify.sh file.
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Enable and configure all required notification variables in your dockcheck.config file, e.g.:
# NOTIFY_CHANNELS=apprise gotify slack
# SLACK_TOKEN=xoxb-some-token-value
# GOTIFY_TOKEN=some.token

# Number of seconds to snooze identical update notifications based on local image name
# or dockcheck.sh/notify.sh template file updates.
# Actual snooze will be 60 seconds less to avoid the chance of missed notifications due to minor scheduling or script run time issues.
snooze="${SNOOZE_SECONDS:-}"
SnoozeFile="${ScriptWorkDir}/snooze.list"

enabled_notify_channels=( ${NOTIFY_CHANNELS:-} )

FromHost=$(cat /etc/hostname)

CurrentEpochTime=$(date +"%Y-%m-%dT%H:%M:%S")
CurrentEpochSeconds=$(date +%s)

NotifyError=false

remove_channel() {
  local temp_array=()
  for channel in "${enabled_notify_channels[@]}"; do
    [[ "${channel}" != "$1" ]] && temp_array+=("${channel}")
  done
  enabled_notify_channels=( "${temp_array[@]}" )
}

for channel in "${enabled_notify_channels[@]}"; do
  source_if_exists_or_fail "${ScriptWorkDir}/notify_${channel}.sh" || \
  source_if_exists_or_fail "${ScriptWorkDir}/notify_templates/notify_${channel}.sh" || \
  printf "The notification channel ${channel} is enabled, but notify_${channel}.sh was not found. Check the ${ScriptWorkDir} directory or the notify_templates subdirectory.\n"
done

notify_containers_count() {
  unset NotifyContainers
  NotifyContainers=()

  [[ ! -f "${SnoozeFile}" ]] && touch "${SnoozeFile}"

  for update in "$@"
  do
    read -a container <<< "${update}"
    found=$(grep -w "${container[0]}" "${SnoozeFile}" || printf "")

    if [[ -n "${found}" ]]; then
      read -a arr <<< "${found}"
      CheckEpochSeconds=$(( $(date -d "${arr[1]}" +%s 2>/dev/null) + ${snooze} - 60 )) || CheckEpochSeconds=$(( $(date -f "%Y-%m-%d" -j "${arr[1]}" +%s) + ${snooze} - 60 ))
      if [[ "${CurrentEpochSeconds}" -gt "${CheckEpochSeconds}" ]]; then
        NotifyContainers+=("${update}")
      fi
    else
      NotifyContainers+=("${update}")
    fi
  done

  printf "${#NotifyContainers[@]}"
}

update_snooze() {

  [[ ! -f "${SnoozeFile}" ]] && touch "${SnoozeFile}"

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

  [[ ! -f "${SnoozeFile}" ]] && touch "${SnoozeFile}"

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
  done <<< "$(cat ${SnoozeFile} | grep ${switch} '\.sh ')"
}

send_notification() {
  [[ -s "$ScriptWorkDir"/urls.list ]] && releasenotes || Updates=("$@")

  if [[ -n "${snooze}" ]] && [[ -f "${SnoozeFile}" ]]; then
    UpdNotifyCount=$(notify_containers_count "${Updates[@]}")
  else
    UpdNotifyCount="${#Updates[@]}"
  fi

  NotifyError=false

  if [[ "${UpdNotifyCount}" -gt 0 ]]; then
    UpdToString=$( printf '%s\\n' "${Updates[@]}" )
    UpdToString=${UpdToString%\\n}

    for channel in "${enabled_notify_channels[@]}"; do
      printf "\nSending ${channel} notification\n"

      # To be added in the MessageBody if "-d X" was used
      # leading space is left intentionally for clean output
      [[ -n "$DaysOld" ]] && msgdaysold="with images ${DaysOld}+ days old " || msgdaysold=""

      MessageTitle="$FromHost - updates ${msgdaysold}available."
      # Setting the MessageBody variable here.
      printf -v MessageBody "🐋 Containers on $FromHost with updates available:\n${UpdToString}\n"

      exec_if_exists_or_fail trigger_${channel}_notification || \
      printf "Attempted to send notification to channel ${channel}, but the function was not found. Make sure notify_${channel}.sh is available in the ${ScriptWorkDir} directory or notify_templates subdirectory.\n"
    done

    [[ -n "${snooze}" ]] && [[ "${NotifyError}" == "false" ]] && update_snooze "${Updates[@]}"
  fi

  [[ -n "${snooze}" ]] && cleanup_snooze "${Updates[@]}"
}

### Set DISABLE_DOCKCHECK_NOTIFICATION=false in dockcheck.config
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
  if [[ ! "${DISABLE_DOCKCHECK_NOTIFICATION:-}" == "true" ]]; then
    DockcheckNotify=false
    NotifyError=false

    if [[ -n "${snooze}" ]] && [[ -f "${SnoozeFile}" ]]; then
      found=$(grep -w "dockcheck\.sh" "${SnoozeFile}" || printf "")
      if [[ -n "${found}" ]]; then
        read -a arr <<< "${found}"
        CheckEpochSeconds=$(( $(date -d "${arr[1]}" +%s 2>/dev/null) + ${snooze} - 60 )) || CheckEpochSeconds=$(( $(date -f "%Y-%m-%d" -j "${arr[1]}" +%s) + ${snooze} - 60 ))
        if [[ "${CurrentEpochSeconds}" -gt "${CheckEpochSeconds}" ]]; then
          DockcheckNotify=true
        fi
      else
        DockcheckNotify=true
      fi
    else
      DockcheckNotify=true
    fi

    if [[ "${DockcheckNotify}" == "true" ]]; then
      MessageTitle="$FromHost - New version of dockcheck available."
      # Setting the MessageBody variable here.
      printf -v MessageBody "Installed version: $1\nLatest version: $2\n\nChangenotes: $3\n"

      if [[ ${#enabled_notify_channels[@]} -gt 0 ]]; then printf "\n"; fi
      for channel in "${enabled_notify_channels[@]}"; do
        printf "Sending dockcheck update notification - ${channel}\n"
        exec_if_exists_or_fail trigger_${channel}_notification || \
        printf "Attempted to send notification to channel ${channel}, but the function was not found. Make sure notify_${channel}.sh is available in the ${ScriptWorkDir} directory or notify_templates subdirectory.\n"
      done

      if [[ -n "${snooze}" ]] && [[ -f "${SnoozeFile}" ]]; then
        if [[ "${NotifyError}" == "false" ]]; then
          if [[ -n "${found}" ]]; then
            sed -e "s/dockcheck\.sh.*/dockcheck\.sh ${CurrentEpochTime}/" "${SnoozeFile}" > "${SnoozeFile}.new"
            mv "${SnoozeFile}.new" "${SnoozeFile}"
          else
            printf "dockcheck.sh ${CurrentEpochTime}\n" >> "${SnoozeFile}"
          fi
        fi
      fi
    fi
  fi
}

### Set DISABLE_NOTIFY_UPDATE_NOTIFICATION=false in dockcheck.config
### to not send notifications when notify scripts themselves have updates.
notify_update_notification() {
  if [[ ! "${DISABLE_NOTIFY_UPDATE_NOTIFICATION:-}" == "true" ]]; then
    NotifyUpdateNotify=false
    NotifyError=false

    UpdateChannels=( "${enabled_notify_channels[@]}" "v2" )

    for NotifyScript in "${UpdateChannels[@]}"; do
      UpperChannel=$(tr '[:lower:]' '[:upper:]' <<< "$NotifyScript")
      VersionVar="NOTIFY_${UpperChannel}_VERSION"
      if [[ -n "${!VersionVar:-}" ]]; then
        RawNotifyUrl="https://raw.githubusercontent.com/mag37/dockcheck/main/notify_templates/notify_${NotifyScript}.sh"
        LatestNotifySnippet="$(curl ${CurlArgs} -r 0-150 "$RawNotifyUrl" || printf "undefined")"
        LatestNotifyRelease="$(echo "$LatestNotifySnippet" | sed -n "/${VersionVar}/s/${VersionVar}=//p" | tr -d '"')"
        if [[ ! "${LatestNotifyRelease}" == "undefined" ]]; then
          if [[ "${!VersionVar}" != "${LatestNotifyRelease}" ]] ; then
            Updates+=("${NotifyScript}.sh ${!VersionVar} -> ${LatestNotifyRelease}")
          fi
        fi
      fi
    done

    if [[ -n "${snooze}" ]] && [[ -f "${SnoozeFile}" ]]; then
      for update in "${Updates[@]}"; do
        read -a NotifyScript <<< "${update}"
        found=$(grep -w "${NotifyScript}" "${SnoozeFile}" || printf "")
        if [[ -n "${found}" ]]; then
          read -a arr <<< "${found}"
          CheckEpochSeconds=$(( $(date -d "${arr[1]}" +%s 2>/dev/null) + ${snooze} - 60 )) || CheckEpochSeconds=$(( $(date -f "%Y-%m-%d" -j "${arr[1]}" +%s) + ${snooze} - 60 ))
          if [[ "${CurrentEpochSeconds}" -gt "${CheckEpochSeconds}" ]]; then
            NotifyUpdateNotify=true
          fi
        else
          NotifyUpdateNotify=true
        fi
      done
    else
      NotifyUpdateNotify=true
    fi

    if [[ "${NotifyUpdateNotify}" == "true" ]]; then
      if [[ "${#Updates[@]}" -gt 0 ]]; then
        UpdToString=$( printf '%s\\n' "${Updates[@]}" )
        UpdToString=${UpdToString%\\n}
        NotifyError=false

        MessageTitle="$FromHost - New version of notify templates available."

        printf -v MessageBody "Notify templates on $FromHost with updates available:\n${UpdToString}\n"

        for channel in "${enabled_notify_channels[@]}"; do
          printf "Sending notify template update notification - ${channel}\n"
          exec_if_exists_or_fail trigger_${channel}_notification || \
          printf "Attempted to send notification to channel ${channel}, but the function was not found. Make sure notify_${channel}.sh is available in the ${ScriptWorkDir} directory or notify_templates subdirectory.\n"
        done

        [[ -n "${snooze}" ]] && [[ "${NotifyError}" == "false" ]] && update_snooze "${Updates[@]}"
      fi
    fi

    UpdatesPlusDockcheck=("${Updates[@]}")
    UpdatesPlusDockcheck+=("dockcheck.sh")
    [[ -n "${snooze}" ]] && cleanup_snooze "${UpdatesPlusDockcheck[@]}"
  fi
}
