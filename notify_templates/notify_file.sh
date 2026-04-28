### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_FILE_VERSION="v0.3"
#
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.

write_file_notification() {
  if [[ "$3" == "Overwrite" ]]; then
    echo "$1" > "$2"
  else
    echo "$1" >> "$2"
  fi
}

trigger_file_notification() {
  local WriteMode="Overwrite"
  local FileOutput="${MessageBody}"

  if [[ -n "$1" ]]; then
    file_channel="$1"
    UpperChannel=$(tr '[:lower:]' '[:upper:]' <<< "$file_channel")
  else
    file_channel="file"
    UpperChannel="FILE"
  fi

  FileTruncVar="${UpperChannel}_TRUNC"
  FilePathVar="${UpperChannel}_PATH"
  NotifyFile="${!FilePathVar:=${ScriptWorkDir}/updates_available.txt}"

  if [[ ${!FileTruncVar:=true} == "true" ]]; then
    declare -g ${FileTruncVar}="false"
  else
    if $jqbin empty "${NotifyFile}" 2>/dev/null; then
      FileOutput=$($jqbin --compact-output --argjson msg "${MessageBody}" '.updates += $msg.updates' "${NotifyFile}")
    else
      if ! grep -xFq "None" ${NotifyFile}; then
        WriteMode="Append"
      fi
    fi
  fi

  write_file_notification "${FileOutput}" "${NotifyFile}" "${WriteMode}"
}
