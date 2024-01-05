### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
#
# Copy/rename this file to notify.sh to enable the notification snipppet.
# Required receiving services must already be set up.
# Modify to fit your setup - changing SendMailFrom, SendMailTo

send_notification() {
Updates=("$@")
UpdToString=$( printf "%s\n" "${Updates[@]}" )
SendMailFrom=me@mydomain.tld
SendMailTo=me@mydomain.tld
FromHost=$(hostname)

printf "\nSending email notification\n"

ssmtp $SendMailTo << __EOF
From: "$FromHost" <$SendMailFrom>
date:$(date -R)
To: <$SendMailTo>
Subject: [dockcheck] Updates available on $FromHost
Content-Type: text/plain; charset=UTF-8; format=flowed
Content-Transfer-Encoding: 7bit

The following containers on $FromHost have updates available:

$UpdToString

__EOF
}
