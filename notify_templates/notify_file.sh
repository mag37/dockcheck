### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_FILE_VERSION="v0.1"
#
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.

trigger_file_notification() {
  NotifyFile="${ScriptWorkDir}/updates_available.txt"

  echo "${MessageBody}" > ${NotifyFile}

}
