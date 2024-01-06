### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
#
# Copy/rename this file to notify.sh to enable email notifications on Synology DSM
# DSM Notification Email has to be configured manually.
# Modify to your liking - changing SendMailTo and Subject and content.

send_notification() {
Updates=("$@")
UpdToString=$( printf "%s\n" "${Updates[@]}" )
FromHost=$(hostname)

# User variables:
# change this to your usual destination for synology DSM notification emails
SendMailTo=me@mydomain.com
SubjectTag="diskstation"

printf "\nSending email notification\n"

ssmtp $SendMailTo << __EOF
From: "$FromHost" <$SendMailTo>
date:$(date -R)
To: <$SendMailTo>
Subject: [$SubjectTag] Updates available on $FromHost
Content-Type: text/plain; charset=UTF-8; format=flowed
Content-Transfer-Encoding: 7bit

The following containers on $FromHost have updates available:

$UpdToString

 From $FromHost

__EOF
}
