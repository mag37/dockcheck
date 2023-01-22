# dockcheck
### A script checking updates for docker images **without the need of pulling** - then having the option to auto-update.

With the help of [`regctl`](https://github.com/regclient/regclient).   
This is just a concept for fun and inspiration, use with care.
___

## Dependencies:
Running docker (duh) and compose, either standalone or plugin.   
`regctl` by [regclient](https://github.com/regclient/regclient)  
The script will ask to download `regctl` if it's not in PATH or current directory.
___
## `dockcheck.sh`
```bash
$ ./dockcheck.sh -h
Syntax:     dockcheck.sh [OPTION] [optional string to filter names]

Options:
-h     Print this Help.
-a     Automatic updates, without interaction.
-n     No updates, only checking availability.
```
A script to check for updates on all currently running containers without pulling images, list them and give the option to update.   

Basic example:
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



And with `-n` *No updates* and `gl` for `*gl*` filtering:
```bash
$ ./dockcheck.sh -n gl
. . .
Containers with updates available:
whoogle-search

Containers on latest version:
glances

No updates installed, exiting
```

Example-video:   
![](https://github.com/mag37/dockcheck/blob/main/example_run.gif)


### :beetle: Squashed Bugs:
- ~~No options for running without updates or auto update.~~
- ~~No filter to check only specific containers.~~
- ~~Faulty registry checkups stopped the updates completely.~~
- ~~No clear checks to skip containers producing errors.~~
- ~~Multi-digest images didn't correctly check with registry, giving false positives on updates.~~

### :hammer: Known issues
- No granular choice of what to update (except initial name filter).
- No detailed error feedback (just skip + list what's skipped) .

## `dupc_function.sh`
Function to quickly check for updates on a single contianer or list of containers by name. **Without the need of pulling**.  
Preferably placed in `.bashrc` or similar.
Example:
```
$ dupc ng
Updates available for local_nginx.
nginx_reverse is already latest.
Updates available for paperless-ng.
```
