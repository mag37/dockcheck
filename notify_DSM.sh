### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
# INFO: ssmtp is depcerated - consider to use msmtp instead.
#
# Copy/rename this file to notify.sh to enable the notification snipppet.
# mSMTP/sSMTP has to be installed and configured manually.
# The existing DSM Notification Email configuration will be used automatically.
# Modify to your liking - changing SendMailTo and Subject and content.

MSMTP=$(which msmtp)
SSMTP=$(which ssmtp)

if [ -n $MSMPT ] ; then
	MAIL=$MSMTP
elif [ -n $SSMTP ] && [ -z $MAIL ] ; then
	MAIL=$SSMTP
else
	echo "No msmtp or ssmtp binary found in PATH: $PATH" ; exit 1
fi

send_notification() {
Updates=("$@")
UpdToString=$( printf "%s\n" "${Updates[@]}" )
FromHost=$(hostname)
CfgFile="/usr/syno/etc/synosmtp.conf"

# User variables:
# Automatically sends to your usual destination for synology DSM notification emails.
# You can also manually override by assigning something else to SendMailTo below.
SendMailTo=$(grep 'eventmail1' $CfgFile | sed -n 's/.*"\([^"]*\)".*/\1/p')
#SendMailTo="me@mydomain.com"

SubjectTag=$(grep 'eventsubjectprefix' $CfgFile | sed -n 's/.*"\([^"]*\)".*/\1/p')
SenderName=$(grep 'smtp_from_name' $CfgFile | sed -n 's/.*"\([^"]*\)".*/\1/p')
SenderMail=$(grep 'smtp_from_mail' $CfgFile | sed -n 's/.*"\([^"]*\)".*/\1/p')
SenderMail=${SenderMail:-$(grep 'eventmail1' $CfgFile | sed -n 's/.*"\([^"]*\)".*/\1/p')}

printf "\nSending email notification.\n"

$MAIL $SendMailTo << __EOF
From: "$SenderName" <$SenderMail>
date:$(date -R)
To: <$SendMailTo>
Subject: $SubjectTag Updates available on $FromHost
Content-Type: text/plain; charset=UTF-8; format=flowed
Content-Transfer-Encoding: 7bit

The following containers on $FromHost have updates available:

$UpdToString

 From $SenderName
__EOF
}
