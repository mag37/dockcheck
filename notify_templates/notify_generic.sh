### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
NOTIFY_GENERIC_VERSION="v0.2"
#
# generic sample, the "Hello World" of notification addons

trigger_generic_notification()  {
    # Modify to fit your setup:
    printf "\n$MessageTitle\n"
    printf "\n$MessageBody\n"
}