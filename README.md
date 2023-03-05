<p align="center">
  <img src="extras/dockcheck_logo_by_booYah187.png" width="160" title="dockcheck">
</p>
<p align="center"> 
  <img src="https://img.shields.io/badge/-bash-grey?style=flat-square&logo=gnubash" alt="bash">
  <a href="https://www.gnu.org/licenses/gpl-3.0.html"><img src="https://img.shields.io/badge/license-GPLv3-red?style=flat-square" alt="GPLv3"></a>
  <img src="https://img.shields.io/github/v/tag/mag37/dockcheck?style=flat-square&label=release" alt="release">
  <a href="https://ko-fi.com/mag37"><img src="https://img.shields.io/badge/-Ko--fi-grey?style=flat-square&logo=Ko-fi" alt="Buy me a Coffee"></a>
  <a href="https://liberapay.com/user-bin-rob/donate"><img src="https://img.shields.io/badge/-LiberaPay-grey?style=flat-square&logo=liberapay" alt="LiberaPay"></a>
  <a href="https://github.com/sponsors/mag37"><img src="https://img.shields.io/badge/-Sponsor-grey?style=flat-square&logo=github" alt="Github Sponsor"></a>
</p>

<h3 align="center">A script checking updates for docker images <b>without pulling</b><br>Then selectively auto-update containers.</h3>
<h4 align="center">With features like excluding specific containers, filter by name, auto-prune dangling images and more.</h4</h3>


### :warning: URGENT! The 2.1 change had a breaking error - make sure you run an updated version.
If you've had errors, inspect your containers and look for odd compose paths, volumes or ports.
[errorCheck.sh](https://github.com/mag37/dockcheck/blob/main/errorCheck.sh) lists the important bits of each running container. If anything suspicious, recreate the container manually with `docker compose`. 

### :pushpin: Recent changes:
- **v0.2.3**: Added a self updating function (curl/git) and a ugly changenote-message for updates.
- **v0.2.2**: Fixed breaking errors with multi-compose, odd breakage and working dir error.
- **v0.2.1**: Added option to exclude a list of containers.
- **v0.2.1**: Added multi-compose support (eg. override). 
- **v0.2.0**: Fixed error with container:tag definition. 
- **v0.1.9:** Fixed custom env-support. 
___

## Dependencies:
Running docker (duh) and compose, either standalone or plugin.   
[`regclient/regctl`](https://github.com/regclient/regclient) (Licensed under [Apache-2.0 License](http://www.apache.org/licenses/LICENSE-2.0))   
User will be prompted to download `regctl` if not in `PATH` or `PWD`
___


![](extras/example.gif)

## `dockcheck.sh`
```
$ ./dockcheck.sh -h
Syntax:     dockcheck.sh [OPTION] [part of name to filter]
Example:    dockcheck.sh -a -e nextcloud,heimdall

Options:
-h     Print this Help.
-a|y   Automatic updates, without interaction.
-n     No updates, only checking availability.
-p     Auto-Prune dangling images after update.
-e     Exclude containers, separated by comma.
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

### :hammer: Known issues
- No detailed error feedback (just skip + list what's skipped) .
- Not respecting `--profile` options when re-creating the container.

## `dc_brief.sh`
Just a brief, slimmed down version of the script to only print what containers got updates, no updates or errors.

# License
dockcheck is created and released under the [GNU GPL v3.0](https://www.gnu.org/licenses/gpl-3.0-standalone.html) license.
___

## Check out a spinoff brother-project:
### [Palleri/dockcheck-web](https://github.com/Palleri/dockcheck-web) for a WebUI-front!

## Special Thanks:
- :bison: [t0rnis](https://github.com/t0rnis)   
- :leopard: [Palleri](https://github.com/Palleri)
