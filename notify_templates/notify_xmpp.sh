### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_XMPP_VERSION="v0.1"
#
# Requires the package "go-sendxmpp" to be installed and in $PATH.
#
# Leave (or place) this file in the "notify_templates" subdirectory within the same directory as the main dockcheck.sh script.
# If you instead wish make your own modifications, make a copy in the same directory as the main dockcheck.sh script.
# Do not modify this file directly within the "notify_templates" subdirectory. 
# Set XMPP_SOURCE_ID, XMPP_SOURCE_PWD and XMPP_DEST_JID in your dockcheck.config file.

trigger_xmpp_notification() {
    if [[ -n "$1" ]]; then
      xmpp_channel="$1"
    else
      xmpp_channel="xmpp"
    fi

    if ! command -v go-sendxmpp &>/dev/null; then
        printf "\nRequired binary go-sendxmpp missing. XMPP notification will not be sent.\n"
        remove_channel xmpp
        return 0
    fi
  
    UpperChannel="${xmpp_channel^^}"

    SourceJidVar="${UpperChannel}_SOURCE_JID"
    SourcePwdVar="${UpperChannel}_SOURCE_PWD"
    DestJidVar="${UpperChannel}_DEST_JID"


    if [[ -z "${!SourceJidVar:-}" ]] || [[ -z "${!DestJidVar:-}" ]] || [[ -z "${!SourcePwdVar:-}" ]]; then
        printf "\nRequired configuration variables are missing. XMPP notifications will not be sent.\n"
        remove_channel xmpp
        return 0
    fi

    SourceJid="${!SourceJidVar}" # E.g `mybotaccount@mydomain.tld`
    SourcePwd="${!SourcePwdVar}" # The password for the account `mybotaccount@mydomain.tld`
    DestJid="${!DestJidVar}" # E.g `myusername@mydomain.tld`

    echo "$MessageBody" | go-sendxmpp --suppress-root-warning -u "$SourceJid" -p "$SourcePwd" "$DestJid"

    if [[ $? -gt 0 ]]; then
      NotifyError=true
    fi

}