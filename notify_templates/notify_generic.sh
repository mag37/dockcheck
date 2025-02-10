### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# generic sample, the "Hello World" of notification addons

FromHost=$(hostname)

trigger_notification()  {
    # Modify to fit your setup:
    printf "\n$MessageTitle\n"
    printf "\n$MessageBody\n"
}

send_notification() {
    [ -s "$ScriptWorkDir"/urls.list ] && releasenotes || Updates=("$@")
    UpdToString=$( printf '%s\\n' "${Updates[@]}" )
  
    # platform specific notification code would go here
    printf "\n%bGeneric notification addon:%b" "$c_green" "$c_reset"
    MessageTitle="$FromHost - updates available."
    printf -v MessageBody "🐋 Containers on $FromHost with updates available:\n$UpdToString"
  
    trigger_notification
}

### Remove or comment out the following function
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
    printf "\nGeneric dockcheck notification\n"
  
    MessageTitle="$FromHost - New version of dockcheck available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "Installed version: $1 \nLatest version: $2 \n\nChangenotes: $3"
  
    trigger_notification
}
