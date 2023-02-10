# dockcheck
### A script checking updates for docker images **without pulling** - then selectively auto-update some/all containers.  

With the help of [`regctl`](https://github.com/regclient/regclient). This is just a concept for inspiration, use with care.
___

## Dependencies:
Running docker (duh) and compose, either standalone or plugin.   
`regctl` by [regclient](https://github.com/regclient/regclient) (will ask to download `regctl` if not in `PATH` or `PWD`)
___


![](https://github.com/mag37/dockcheck/blob/main/example.gif)

## `dockcheck.sh`
```
$ ./dockcheck.sh -h
Syntax:     dockcheck.sh [OPTION] [part of name to filter]
Example:    dockcheck.sh -a ng

Options:
-h     Print this Help.
-a|y   Automatic updates, without interaction.
-n     No updates, only checking availability.
-r     Allow updating images for docker run, wont update the container.
```

Basic example:
```
$ ./dockcheck.sh
. . .
Containers on latest version:
glances
homer

Containers with updates available:
0) ALL
1) adguardhome
2) syncthing
3) whoogle-search


Choose what containers to update:
Enter number(s) separated by comma, [q] to quit: 1,3

```
Then it proceedes to run `pull` and `up -d` on every container with updates.   

### `-r flag` :warning: disclaimer and warning:
**Wont auto-update the containers, only their images. (compose is recommended)**   
`docker run` dont support using new images just by restarting a container.  
Containers need to be manually stopped, removed and created again to run on the new image.


### :beetle: Squashed Bugs:
- ~~No options for running without updates or auto update.~~
- ~~No filter to check only specific containers.~~
- ~~Faulty registry checkups stopped the updates completely.~~
- ~~No clear checks to skip containers producing errors.~~
- ~~Multi-digest images didn't correctly check with registry, giving false positives on updates.~~
- ~~Not working with filenames other than `docker-compose.yml`~~
- ~~Lists are not alphabetically sorted (due to stacks and other parameters)~~
- ~~Old `docker-compose` binary-check sometimes returned false error~~
- ~~Stacks gets updated as whole, even if only one service is chosen.~~
- ~~Path broken occationally (from inspect) - probably due to old docker-compose binary.~~
- ~~Script breaks if one of the chosen containers are a `docker run` container.

### :hammer: Known issues
- ~~No granular choice of what to update (except initial name filter).~~
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
## Also check out a spinoff brother-project [Palleri/dockcheck-web](https://github.com/Palleri/dockcheck-web) for a WebUI-front!
---

## Special Thanks:
:bison: [t0rnis](https://github.com/t0rnis)   
:leopard: [Palleri](https://github.com/Palleri)
