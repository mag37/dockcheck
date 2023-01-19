# dockcheck
Scripts and functions to check for docker updates for images, **without the need of pulling**. With the help of [`regctl`](https://github.com/regclient/regclient).
This is just a concept for fun and inspiration, use with care.
___

## Dependencies:
Running docker (duh) and compose, either standalone or plugin.   
`regctl` by [regclient](https://github.com/regclient/regclient)
___
## `dockcheck.sh`
A script to check all currently running containers if they've got updates without pulling images, list them and give the option to update.
Example:
```bash
$ ./dockcheck.sh
. . .
Containers with updates available:
whoogle-search

Containers on latest version:
glances
homer

Do you want to update? y/[n]
y
```
Then it proceedes to run `pull` and `up -d` on every container with updates.   

Example-video:
[![asciicast](https://asciinema.org/a/Bt3UXSoDHIRSn0GbvfZmB0tV2.svg)](https://asciinema.org/a/Bt3UXSoDHIRSn0GbvfZmB0tV2)


## `dc_function.sh`
Function to quickly check for updates on a single contianer or list of containers by name. **Without the need of pulling**.
Preferably placed in `.bashrc` or similar.
Example:
```
$ dockcheck ng
Updates available for local_nginx.
nginx_reverse is already latest.
Updates available for paperless-ng.
```
