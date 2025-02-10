### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
# INFO: ssmtp is depcerated - consider to use msmtp instead.
#
# Copy/rename this file to notify.sh to enable the notification snipppet.
# mSMTP/sSMTP has to be installed and configured manually.
# Modify to fit your setup - changing SendMailFrom, SendMailTo, SubjectTag

MSMTP=$(which msmtp)
SSMTP=$(which ssmtp)

if [ -n "$MSMTP" ] ; then
	MailPkg=$MSMTP
elif [ -n "$SSMTP" ] ; then
	MailPkg=$SSMTP
else
	echo "No msmtp or ssmtp binary found in PATH: $PATH" ; exit 1
fi

FromHost=$(hostname)

trigger_notification() {
# User variables:
SendMailFrom="me@mydomain.tld"
SendMailTo="me@mydomain.tld"
SubjectTag="dockcheck"

$MailPkg $SendMailTo << __EOF
From: "$FromHost" <$SendMailFrom>
date:$(date -R)
To: <$SendMailTo>
Subject: [$SubjectTag] $MessageTitle $FromHost
Content-Type: text/plain; charset=UTF-8; format=flowed
Content-Transfer-Encoding: 7bit

$MessageBody

__EOF
}

send_notification() {
		[ -s "$ScriptWorkDir"/urls.list ] && releasenotes || Updates=("$@")
		UpdToString=$( printf '%s\\n' "${Updates[@]}" )

		printf "\nSending email notification.\n"

		MessageTitle="Updates available on"
		# Setting the MessageBody variable here.
		printf -v MessageBody "🐋 Containers on $FromHost with updates available:\n\n$UpdToString"

		trigger_notification
}

### Remove or comment out the following function
### to not send notifications when dockcheck itself has updates.
dockcheck_notification() {
		printf "\nSending email dockcheck notification.\n"

		MessageTitle="New version of dockcheck available on"
		# Setting the MessageBody variable here.
		printf -v MessageBody "Installed version: $1 \nLatest version: $2 \n\nChangenotes: $3"

		trigger_notification
}
