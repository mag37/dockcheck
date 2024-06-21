### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
#
# Copy/rename this file to notify.sh to enable the notification snippet.
# Required receiving services must already be set up.
# Modify to fit your setup - set GotifyUrl and GotifyToken.

send_notification() {
    Updates=("$@")
    UpdToString=$( printf "%s\n" "${Updates[@]}" )
    FromHost=$(hostname)
    
    # platform specific notification code would go here
    printf "\nSending Gotify notification\n"
    
    # Setting the MessageTitle and MessageBody variable here.
    MessageTitle="${FromHost} - updates available."
    MessageBody="Containers on ${FromHost} with updates available: ${UpdToString}"
    
    # Modify to fit your setup:
    GotifyToken="Your Gotify token here"
    GotifyUrl="https://api.gotify/message?token=${GotifyToken}"   
    
    curl \
        -F "title=${MessageTitle}" \
        -F "message=${MessageBody}" \
        -F "priority=5" \
        -X POST "${GotifyUrl}" &> /dev/null

}
