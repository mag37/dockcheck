### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_APPRISE_VERSION="v0.1"
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Required receiving services must already be set up.
# Modify to fit your setup - if API, set AppriseURL to your Apprise ip/domain.

FromHost=$(hostname)

trigger_notification() {

   ### Modify to fit your setup:
   apprise -vv -t "$MessageTitle" -b "$MessageBody" \
      mailto://myemail:mypass@gmail.com \
      mastodons://{token}@{host} \
      pbul://o.gn5kj6nfhv736I7jC3cj3QLRiyhgl98b \
      tgram://{bot_token}/{chat_id}/

   ### If you use the Apprise-API - Comment out the apprise command above.
   ### Uncomment the AppriseURL and the curl-line below:
   # AppriseURL="http://apprise.mydomain.tld:1234/notify/apprise"
   # curl -X POST -F "title=$MessageTitle" -F "body=$MessageBody" -F "tags=all" $AppriseURL
}

send_notification() {
    [ -s "$ScriptWorkDir"/urls.list ] && releasenotes || Updates=("$@")
    UpdToString=$( printf '%s\\n' "${Updates[@]}" )

    printf "\nSending Apprise notification\n"

    MessageTitle="$FromHost - updates available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "🐋 Containers on $FromHost with updates available:\n$UpdToString"

    trigger_notification
}

### Rename (eg. disabled_dockcheck_notification), remove or comment out the following function
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
    printf "\nSending Apprise dockcheck notification\n"

    MessageTitle="$FromHost - New version of dockcheck available."
    # Setting the MessageBody variable here.
    printf -v MessageBody "Installed version: $1 \nLatest version: $2 \n\nChangenotes: $3"

    RawNotifyUrl="https://raw.githubusercontent.com/mag37/dockcheck/main/notify_templates/notify_apprise.sh"
    LatestNotifyRelease="$(curl -s -r 0-150 $RawNotifyUrl | sed -n "/NOTIFY_APPRISE_VERSION/s/NOTIFY_APPRISE_VERSION=//p" | tr -d '"')"
    if [[ "$NOTIFY_APPRISE_VERSION" != "$LatestNotifyRelease" ]] ; then
        printf -v NotifyUpdate "\n\nnotify_apprise.sh update avialable:\n $NOTIFY_APPRISE_VERSION -> $LatestNotifyRelease\n"
        MessageBody="${MessageBody}${NotifyUpdate}"
    fi

    trigger_notification
}
