### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Required receiving services must already be set up.
# Modify to fit your setup - set AppriseURL to your Apprise ip/domain.

send_notification() {
Updates=("$@")
UpdToString=$( printf "%s\n" "${Updates[@]}" )
FromHost=$(hostname)
AppriseURL="http://apprise.mydomain.tld:1234/notify/apprise"

printf "\nSending Apprise notification\n"

MessageTitle="$FromHost - updates available."
# Setting the MessageBody variable here.
read -d '\n' MessageBody << EOF
Containers on $FromHost with updates available:

$UpdToString

EOF

curl -X POST -F "title=$MessageTitle" -F "body=$MessageBody" -F "tags=all" $AppriseURL
}


# If you run apprise bare metal on the same machine as dockcheck
# you can just comment out the AppriseURL and swap the curl line
# with something ike this:
#
# apprise -vv -t "$MessageTitle" -b "$MessageBody" \
#    'mailto://myemail:mypass@gmail.com' \
#    'pbul://o.gn5kj6nfhv736I7jC3cj3QLRiyhgl98b'
