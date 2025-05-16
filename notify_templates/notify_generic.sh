### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_GENERIC_VERSION="v0.1"
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
    UpdToString=$( printf '%s\\n' "$@" )

    # platform specific notification code would go here
    printf "\n%bGeneric notification addon:%b" "$c_green" "$c_reset"
    MessageTitle="$FromHost - updates available."
    printf -v MessageBody "🐋 Containers on $FromHost with updates available:\n$UpdToString"

    trigger_notification
}

### Rename (eg. disabled_dockcheck_notification), remove or comment out the following function
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
    printf "\nGeneric dockcheck notification\n"

    MessageTitle="$FromHost - New version of dockcheck available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "Installed version: $1 \nLatest version: $2 \n\nChangenotes: $3"

    RawNotifyUrl="https://raw.githubusercontent.com/mag37/dockcheck/main/notify_templates/notify_generic.sh"
    LatestNotifyRelease="$(curl -s -r 0-150 $RawNotifyUrl | sed -n "/NOTIFY_GENERIC_VERSION/s/NOTIFY_GENERIC_VERSION=//p" | tr -d '"')"
    if [[ "$NOTIFY_GENERIC_VERSION" != "$LatestNotifyRelease" ]] ; then
        printf -v NotifyUpdate "\n\nnotify_generic.sh update avialable:\n $NOTIFY_GENERIC_VERSION -> $LatestNotifyRelease\n"
        MessageBody="${MessageBody}${NotifyUpdate}"
    fi

    trigger_notification
}
