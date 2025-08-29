### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_SMTP_VERSION="v0.5"
# INFO: ssmtp is depcerated - consider to use msmtp instead.
#
# mSMTP/sSMTP has to be installed and configured manually.
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. Set SMTP_MAIL_FROM, SMTP_MAIL_TO, and SMTP_SUBJECT_TAG in your dockcheck.config file.

MSMTP=$(which msmtp)
SSMTP=$(which ssmtp)
SENDMAIL=$(which sendmail)

if [ -n "$MSMTP" ] ; then
	MailPkg=$MSMTP
elif [ -n "$SSMTP" ] ; then
	MailPkg=$SSMTP
elif [ -n "$SENDMAIL" ] ; then
	MailPkg=$SENDMAIL
else
	echo "No msmtp, ssmtp or sendmail binary found in PATH: $PATH" ; exit 1
fi

trigger_smtp_notification() {
  if [[ -n "$1" ]]; then
    smtp_channel="$1"
  else
    smtp_channel="smtp"
  fi

  UpperChannel="${smtp_channel^^}"

  SendMailFromVar="${UpperChannel}_MAIL_FROM"
  SendMailToVar="${UpperChannel}_MAIL_TO"
  SubjectTagVar="${UpperChannel}_SUBJECT_TAG"

  if [[ -z "${!SendMailFromVar:-}" ]] || [[ -z "${!SendMailToVar:-}" ]] || [[ -z "${!SubjectTagVar:-}" ]]; then
    printf "The ${smtp_channel} notification channel is enabled, but required configuration variables are missing. SMTP notifications will not be sent.\n"

    remove_channel smtp
    return 0
  fi

  SendMailFrom="${!SendMailFromVar}" # e.g. MAIL_FROM=me@mydomain.tld
  SendMailTo="${!SendMailToVar}" # e.g. MAIL_TO=me@mydomain.tld
  SubjectTag="${!SubjectTagVar}" # e.g. SUBJECT_TAG=dockcheck

$MailPkg $SendMailTo << __EOF
From: "$FromHost" <$SendMailFrom>
date:$(date -R)
To: <$SendMailTo>
Subject: [$SubjectTag] $MessageTitle $FromHost
Content-Type: text/plain; charset=UTF-8; format=flowed
Content-Transfer-Encoding: 7bit

$MessageBody

__EOF

if [[ $? -gt 0 ]]; then
  NotifyError=true
fi
}
