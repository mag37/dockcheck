# copy/rename this file to notify.sh to enable email/text notifications
# generic sample, the "Hello World" of notification addons

send_notification() {

FromHost=$(hostname)

# platform specific notification code would go here
printf "\n%bGeneric notification addon:%b" "$c_green" "$c_reset"
printf "\nThe following docker packages on $FromHost need to be updated:\n$@\n"

}