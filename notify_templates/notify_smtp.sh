### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_SMTP_VERSION="v0.2"
# INFO: ssmtp is depcerated - consider to use msmtp instead.
#
# mSMTP/sSMTP has to be installed and configured manually.
# Set SMTP_MAIL_FROM, SMTP_MAIL_TO, and SMTP_SUBJECT_TAG in your dockcheck.config file.

MSMTP=$(which msmtp)
SSMTP=$(which ssmtp)

if [ -n "$MSMTP" ] ; then
	MailPkg=$MSMTP
elif [ -n "$SSMTP" ] ; then
	MailPkg=$SSMTP
else
	echo "No msmtp or ssmtp binary found in PATH: $PATH" ; exit 1
fi

trigger_smtp_notification() {
SendMailFrom="${SMTP_MAIL_FROM}" # e.g. MAIL_FROM=me@mydomain.tld
SendMailTo="${SMTP_MAIL_TO}" # e.g. MAIL_TO=me@mydomain.tld
SubjectTag="${SMTP_SUBJECT_TAG}" # e.g. SUBJECT_TAG=dockcheck

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
