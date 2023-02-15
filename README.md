# dockcheck
### A script checking updates for docker images **without pulling** - then selectively auto-update some/all containers.  
___

## Dependencies:
Running docker (duh) and compose, either standalone or plugin.   
[`regclient/regctl`](https://github.com/regclient/regclient) (Licensed under [Apache-2.0 License](http://www.apache.org/licenses/LICENSE-2.0))   
User will be prompted to download `regctl` if not in `PATH` or `PWD`
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
-p     Auto-Prune dangling images after update.
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
1) adguardhome
2) syncthing
3) whoogle-search


Choose what containers to update:
Enter number(s) separated by comma, [a] for all - [q] to quit:

```
Then it proceedes to run `pull` and `up -d` on every container with updates.   
After the updates are complete, you'll get prompted if you'd like to prune dangling images.

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
- ~~Script breaks if one of the chosen containers are a `docker run` container.~~
- ~~Using relative paths for volumes eg. `${PWD}/data:data` will create the volumes where you stand.~~
- ~~Having no curl/wget leads to corrupt `regctl` without alerting.~~

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
# License
dockcheck is created and released under the [GNU GPL v3.0](https://www.gnu.org/licenses/gpl-3.0-standalone.html) license.

## Also check out a spinoff brother-project [Palleri/dockcheck-web](https://github.com/Palleri/dockcheck-web) for a WebUI-front!
---

## Special Thanks:
:bison: [t0rnis](https://github.com/t0rnis)   
:leopard: [Palleri](https://github.com/Palleri)
