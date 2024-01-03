### DISCLAIMER: This is a third party addition to dockcheck - best effort testing.
# Copy/rename this file to notify.sh to enable email/text notifications
# generic sample, the "Hello World" of notification addons

send_notification() {
  Updates=("$@")
  UpdToString=$( printf "%s\n" "${Updates[@]}" )
  FromHost=$(hostname)

  # platform specific notification code would go here
  printf "\n%bGeneric notification addon:%b" "$c_green" "$c_reset"
  printf "\nThe following docker containers on %s need to be updated:\n%s\n" "$FromHost" "$UpdToString"
}
