NOTIFY_V2_VERSION="v0.2"
#
# If migrating from an older notify template, remove your existing notify.sh file.
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Enable and configure all required notification variables in your dockcheck.config file, e.g.:
# NOTIFY_CHANNELS=apprise gotify slack
# SLACK_TOKEN=xoxb-some-token-value
# GOTIFY_TOKEN=some.token

enabled_notify_channels=( ${NOTIFY_CHANNELS:-} )

FromHost=$(hostname)

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

send_notification() {
  [[ -s "$ScriptWorkDir"/urls.list ]] && releasenotes || Updates=("$@")
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
}

### Set DISABLE_DOCKCHECK_NOTIFICATION=false in dockcheck.config
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
  if [[ ! "${DISABLE_DOCKCHECK_NOTIFICATION:-}" = "true" ]]; then
    MessageTitle="$FromHost - New version of dockcheck available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "Installed version: $1\nLatest version: $2\n\nChangenotes: $3\n"

    if [[ ${#enabled_notify_channels[@]} -gt 0 ]]; then printf "\n"; fi
    for channel in "${enabled_notify_channels[@]}"; do
      printf "Sending dockcheck update notification - ${channel}\n"
      exec_if_exists_or_fail trigger_${channel}_notification || \
      printf "Attempted to send notification to channel ${channel}, but the function was not found. Make sure notify_${channel}.sh is available in the ${ScriptWorkDir} directory or notify_templates subdirectory.\n"
    done
  fi
}

### Set DISABLE_NOTIFY_UPDATE_NOTIFICATION=false in dockcheck.config
### to not send notifications when notify scripts themselves have updates.
notify_update_notification() {
  if [[ ! "${DISABLE_NOTIFY_UPDATE_NOTIFICATION:-}" = "true" ]]; then
    update_channels=( "${enabled_notify_channels[@]}" "v2" )

    for notify_script in "${update_channels[@]}"; do
      upper_channel=$(tr '[:lower:]' '[:upper:]' <<< "$notify_script")
      VersionVar="NOTIFY_${upper_channel}_VERSION"
      if [[ -n "${!VersionVar:-}" ]]; then
        RawNotifyUrl="https://raw.githubusercontent.com/mag37/dockcheck/main/notify_templates/notify_${notify_script}.sh"
        LatestNotifyRelease="$(curl -s -r 0-150 $RawNotifyUrl | sed -n "/NOTIFY_${upper_channel}_VERSION/s/NOTIFY_${upper_channel}_VERSION=//p" | tr -d '"')"
        LatestNotifyRelease=${LatestNotifyRelease:-undefined}
        if [[ ! "${LatestNotifyRelease}" = "undefined" ]]; then
          if [[ "${!VersionVar}" != "$LatestNotifyRelease" ]] ; then
            MessageTitle="$FromHost - New version of notify_${notify_script}.sh available."

            printf -v MessageBody "notify_${notify_script}.sh update available:\n ${!VersionVar} -> $LatestNotifyRelease\n"

            for channel in "${enabled_notify_channels[@]}"; do
              printf "Sending notify_${notify_script}.sh update notification - ${channel}\n"
              exec_if_exists_or_fail trigger_${channel}_notification || \
              printf "Attempted to send notification to channel ${channel}, but the function was not found. Make sure notify_${channel}.sh is available in the ${ScriptWorkDir} directory or notify_templates subdirectory.\n"
            done
          fi
        fi
      fi
    done
  fi
}
