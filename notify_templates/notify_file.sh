### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_FILE_VERSION="v0.2"
#
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.

trigger_file_notification() {
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

  if [[ ${!FileTruncVar:=0} -eq 0 ]]; then
    echo "${MessageBody}" > ${NotifyFile}
    declare -g ${FileTruncVar}=1
  else
    echo "${MessageBody}" >> ${NotifyFile}
  fi
}
