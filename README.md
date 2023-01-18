# dockcheck
A repo containing scripts and functions to check for docker updates for images, without the need of pulling. With the help of [`regctl`](https://github.com/regclient/regclient).
This is just for fun and inspiration, use with care.
___

## Dependencies:
Running docker (duh) and compose, either standalone or plugin.   
`regctl` by [regclient](https://github.com/regclient/regclient)
___

## `dockcheck_function.sh`
Brief function to check a single contianer (by name) if there's any available updates or not without the need of pulling.   
`dockcheck nginx`

## `dockcheck.sh`
A script to check all currently running containers if they've got updates without pulling images, list them and give the option to update.

[![asciicast](https://asciinema.org/a/Bt3UXSoDHIRSn0GbvfZmB0tV2.svg)](https://asciinema.org/a/Bt3UXSoDHIRSn0GbvfZmB0tV2)
