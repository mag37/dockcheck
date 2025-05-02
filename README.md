<p align="center">
  <img src="extras/dockcheck_logo_by_booYah187.png" width="160" title="dockcheck">
</p>
<p align="center">
  <img src="https://img.shields.io/badge/bash-4.3-green?style=flat-square&logo=gnubash" alt="bash">
  <a href="https://www.gnu.org/licenses/gpl-3.0.html"><img src="https://img.shields.io/badge/license-GPLv3-red?style=flat-square" alt="GPLv3"></a>
  <img src="https://img.shields.io/github/v/tag/mag37/dockcheck?style=flat-square&label=release" alt="release">
  <a href="https://ko-fi.com/mag37"><img src="https://img.shields.io/badge/-Ko--fi-grey?style=flat-square&logo=Ko-fi" alt="Buy me a Coffee"></a>
  <a href="https://liberapay.com/user-bin-rob/donate"><img src="https://img.shields.io/badge/-LiberaPay-grey?style=flat-square&logo=liberapay" alt="LiberaPay"></a>
  <a href="https://github.com/sponsors/mag37"><img src="https://img.shields.io/badge/-Sponsor-grey?style=flat-square&logo=github" alt="Github Sponsor"></a>
</p>

<h2 align="center">CLI tool to automate docker image updates or notifying when updates are available.</h2>
<h3 align="center">selective updates, exclude containers, custom labels, notification plugins, prune when done etc.</h3>

<h4 align="center">:whale: Docker Hub pull limit :chart_with_downwards_trend: not an issue for checks but for actual pulls - <a href="#whale-docker-hub-pull-limit-chart_with_downwards_trend-not-an-issue-for-checks-but-for-actual-pulls">read more</a></h4>

<h5 align="center">For Podman - see the fork <a href="https://github.com/sudo-kraken/podcheck">sudo-kraken/podcheck</a>!</h4>

___
## :bell: Changelog

- **v0.6.2**: Style and colour changes, prometheus hotfix, new options:
    - `-u`, Allow auto self update of dockcheck.sh
    - `-I`, Print container release URLs in the CLI "choose update" list. (please contribute to `urls.list`)
    - Extras: `-m`, Monochrome mode now hides the progress bar.
- **v0.6.1**: Hotfixes: (try removing set+shopt+shopt if debugging more errors)
    - xargs/pipefail, removed `-set -e` bash option for now.
    - unbound variables fixed (hopefully)
    - dependency installer from pkgmanager rewritten
- **v0.6.0**: Refactored a lot of code, cleaner logic and syntax, safer variables.
    - Safer bash options with `set -euo pipefail`, `shopt -s nullglob` and `failglob`.
    - Added a `default.conf` for user settings - persistent through updates.
    - Added `notify_slack.sh` template for slack curl api.

___


![](extras/example.gif)

## :mag_right: `dockcheck.sh`
```
$ ./dockcheck.sh -h
Syntax:     dockcheck.sh [OPTION] [part of name to filter]
Example:    dockcheck.sh -y -d 10 -e nextcloud,heimdall

Options:
-a|y   Automatic updates, without interaction.
-c D   Exports metrics as prom file for the prometheus node_exporter. Provide the collector textfile directory.
-d N   Only update to new images that are N+ days old. Lists too recent with +prefix and age. 2xSlower.
-e X   Exclude containers, separated by comma.
-f     Force stack restart after update. Caution: restarts once for every updated container within stack.
-h     Print this Help.
-i     Inform - send a preconfigured notification.
-I     Prints custom releasenote urls alongside each container with updates (requires urls.list).
-l     Only update if label is set. See readme.
-m     Monochrome mode, no printf colour codes and hides progress bar.
-n     No updates, only checking availability.
-p     Auto-Prune dangling images after update.
-r     Allow updating images for docker run, wont update the container.
-s     Include stopped containers in the check. (Logic: docker ps -a).
-t N   Set a timeout (in seconds) per container for registry checkups, 10 is default.
-u     Allow automatic self updates - caution as this will pull new code and autorun it.
-v     Prints current version.
-x N   Set max asynchronous subprocesses, 1 default, 0 to disable, 32+ tested.
```

### Basic example:
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
Then it proceeds to run `pull` and `up -d` on every container with updates.  
After the updates are complete, you'll get prompted if you'd like to prune dangling images.

___

## :nut_and_bolt: Dependencies
- Running docker (duh) and compose, either standalone or plugin. (see [Podman fork](https://github.com/sudo-kraken/podcheck)  
- Bash shell or compatible shell of at least v4.3
  - POSIX `xargs`, usually default but can be installed with the `findutils` package - to enable async.
- [jq](https://github.com/jqlang/jq)
  - User will be prompted to install with package manager or download static binary.
- [regclient/regctl](https://github.com/regclient/regclient) (Licensed under [Apache-2.0 License](http://www.apache.org/licenses/LICENSE-2.0))  
  - User will be prompted to download `regctl` if not in `PATH` or `PWD`.  
  - regctl requires `amd64/arm64` - see [workaround](#roller_coaster-workaround-for-non-amd64--arm64) if other architecture is used.

## :tent: Install Instructions
Download the script to a directory in **PATH**, I'd suggest using `~/.local/bin` as that's usually in **PATH**.  
For OSX/macOS preferably use `/usr/local/bin`.
```sh
# basic example with curl:
curl -L https://raw.githubusercontent.com/mag37/dockcheck/main/dockcheck.sh -o ~/.local/bin/dockcheck.sh
chmod +x ~/.local/bin/dockcheck.sh

# or oneliner with wget:
wget -O ~/.local/bin/dockcheck.sh "https://raw.githubusercontent.com/mag37/dockcheck/main/dockcheck.sh" && chmod +x ~/.local/bin/dockcheck.sh

# OSX or macOS version with curl:
 curl -L https://raw.githubusercontent.com/mag37/dockcheck/main/dockcheck.sh -o /usr/local/bin/dockcheck.sh && chmod +x /usr/local/bin/dockcheck.sh
```
Then call the script anywhere with just `dockcheck.sh`.
Add preferred `notify.sh`-template to the same directory - this will not be touched by the scripts self-update function.

## :handbag: Configuration
To modify settings and have them persist through updates - copy the `default.config` to `dockcheck.config` alongside the script or in `~/.config/`.  
Alternatively create an alias where specific flags and values are set.  
Example `alias dc=dockcheck.sh -p -x 10 -t 3`.

## :loudspeaker: Notifications
Trigger with the `-i` flag if `notify.sh` is present and configured.  
Will send a list of containers with updates available and a notification when `dockcheck.sh` itself has an update.  
Run it scheduled with `-ni` to only get notified when there's updates available!  

Use a `notify_X.sh` template file from the **notify_templates** directory, copy it to `notify.sh` alongside the script, modify it to your needs! (notify.sh is added to .gitignore)  
**Current templates:**
- Synology [DSM](https://www.synology.com/en-global/dsm)
- Email with [mSMTP](https://wiki.debian.org/msmtp) (or deprecated alternative [sSMTP](https://wiki.debian.org/sSMTP))
- Apprise (with it's [multitude](https://github.com/caronc/apprise#supported-notifications) of notifications)
  - both native [caronc/apprise](https://github.com/caronc/apprise) and the standalone [linuxserver/docker-apprise-api](https://github.com/linuxserver/docker-apprise-api)
  - Read the [QuickStart](extras/apprise_quickstart.md)
- [ntfy.sh](https://ntfy.sh/) - HTTP-based pub-sub notifications.
- [Gotify](https://gotify.net/) - a simple server for sending and receiving messages.
- [Pushbullet](https://www.pushbullet.com/) - connecting different devices with cross-platform features.
- [Telegram](https://telegram.org/) - Telegram chat API.
- [Matrix-Synapse](https://github.com/element-hq/synapse) - [Matrix](https://matrix.org/), open, secure, decentralised communication.
- [Pushover](https://pushover.net/) - Simple Notifications (to your phone, wearables, desktops)
- [Discord](https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks) - Discord webhooks.
- [Slack](https://api.slack.com/tutorials/tracks/posting-messages-with-curl) - Slack curl api

Further additions are welcome - suggestions or PR!  
<sub><sup>Initiated and first contributed by [yoyoma2](https://github.com/yoyoma2).</sup></sub>  

### :date: Release notes addon
There's a function to use a lookup-file to add release note URL's to the notification message.  
Copy the notify_templates/`urls.list` file to the script directory, it will be used automatically if it's there.  
Modify it as necessary, the names of interest in the left column needs to match your container names.  
To also list the URL's in the CLI output (choose containers list) use the `-I` option or variable config.  

The output of the notification will look something like this:
```
Containers on hostname with updates available:
apprise-api  ->  https://github.com/linuxserver/docker-apprise-api/releases
homer  ->  https://github.com/bastienwirtz/homer/releases
nginx  ->  https://github.com/docker-library/official-images/blob/master/library/nginx
...
```
The `urls.list` file is just an example and I'd gladly see that people contribute back when they add their preferred URLs to their lists.

## :fast_forward: Asyncronous update checks with **xargs**; `-x N` option. (default=1)
Pass `-x N` where N is number of subprocesses allowed, experiment in your environment to find a suitable max!  
Change the default value by editing the `MaxAsync=N` variable in `dockcheck.sh`. To disable the subprocess function set `MaxAsync=0`.


## :chart_with_upwards_trend: Extra plugins and tools:

### :small_orange_diamond: Using dockcheck.sh with the Synology DSM
If you run your container through the *Container Manager GUI* - only notifications are supported.  
While if running manual (vanilla docker compose CLI) will allow you to use the update function too.  
Some extra setup to tie together with Synology DSM - check out the [addons/DSM/README.md](./addons/DSM/README.md).

### :small_orange_diamond: Prometheus and node_exporter
Dockcheck can be used together with [Prometheus](https://github.com/prometheus/prometheus) and [node_exporter](https://github.com/prometheus/node_exporter) to export metrics via the file collector, scheduled with cron or likely.
This is done with the `-c` option, like this:
```
dockcheck.sh -c /path/to/exporter/directory
```

See the [README.md](./addons/prometheus/README.md) for more detailed information on how to set it up!  
<sub><sup>Contributed by [tdralle](https://github.com/tdralle).</sup></sub>  

### :small_orange_diamond: Zabbix config to monitor docker image updates
If you already use Zabbix - this config will Shows number of available docker image updates on host.  
Example: *2 Docker Image updates on host-xyz*  
See project: [thetorminal/zabbix-docker-image-updates](https://github.com/thetorminal/zabbix-docker-image-updates)

### :small_orange_diamond: Serve REST API to list all available updates
A custom python script to serve a REST API to get pulled into other monitoring tools like [homepage](https://github.com/gethomepage/homepage).  
See [discussion here](https://github.com/mag37/dockcheck/discussions/146).

### :small_orange_diamond: Wrapper Script for Unraid's User Scripts
A custom bash wrapper script to allow the usage of dockcheck as a Unraid User Script plugin.  
See [discussion here](https://github.com/mag37/dockcheck/discussions/145).

## :bookmark: Labels
Optionally add labels to compose-files. Currently these are the usable labels:
```
    labels:
      mag37.dockcheck.restart-stack: true
      mag37.dockcheck.update: true
```
- `mag37.dockcheck.restart-stack: true` works instead of the `-f` option, forcing stop+restart on the whole compose-stack (Caution: Will restart on every updated container within stack).
- `mag37.dockcheck.update: true` will when used with the `-l` option only update containers with this label and skip the rest. Will still list updates as usual.

## :roller_coaster: Workaround for non **amd64** / **arm64**
`regctl` provides binaries for amd64/arm64, to use on other architecture you could try this workaround.
Run regctl in a container wrapped in a shell script. Copied from [regclient/docs/install.md](https://github.com/regclient/regclient/blob/main/docs/install.md):

```sh
cat >regctl <<EOF
#!/bin/sh
opts=""
case "\$*" in
  "registry login"*) opts="-t";;
esac
docker container run \$opts -i --rm --net host \\
  -u "\$(id -u):\$(id -g)" -e HOME -v \$HOME:\$HOME \\
  -v /etc/docker/certs.d:/etc/docker/certs.d:ro \\
  ghcr.io/regclient/regctl:latest "\$@"
EOF
chmod 755 regctl
```
Test it with `./regctl --help` and then either add the file to the same path as *dockcheck.sh* or in your path (eg. `~/.local/bin/regctl`).

## :whale: Docker Hub pull limit :chart_with_downwards_trend: not an issue for checks but for actual pulls
Due to recent changes in [Docker Hub usage and limits](https://docs.docker.com/docker-hub/usage/)
>Unauthenticated users: 10 pulls/hour  
>Authenticated users with a free account: 100 pulls/hour

This is not an issue for registry checks. But if you have a large stack and pull more than 10 updates at once consider updating more often or to create a free account.
You could use/modify the login-wrapper function in the example below to automate the login prior to running `dockcheck.sh`.

### :guardsman: Function to auth with docker hub before running
**Example** - Change names, paths, and remove cat+password flag if you rather get prompted:
```sh
function dchk {
  cat ~/pwd.txt | docker login --username YourUser --password-stdin
  ~/dockcheck.sh "$@"
}
```

## :hammer: Known issues
- No detailed error feedback (just skip + list what's skipped).
- Not respecting `--profile` options when re-creating the container.
- Not working well with containers created by **Portainer**.
- **Watchtower** might cause issues due to retagging images when checking for updates (and thereby pulling new images).

## :warning: `-r flag` disclaimer and warning
**Wont auto-update the containers, only their images. (compose is recommended)**  
`docker run` dont support using new images just by restarting a container.  
Containers need to be manually stopped, removed and created again to run on the new image.

## :wrench: Debugging
If you hit issues, you could check the output of the `extras/errorCheck.sh` script for clues.
Another option is to run the main script with debugging in a subshell `bash -x dockcheck.sh` - if there's a particular container/image that's causing issues you can filter for just that through `bash -x dockcheck.sh nginx`.

## :scroll: License
dockcheck is created and released under the [GNU GPL v3.0](https://www.gnu.org/licenses/gpl-3.0-standalone.html) license.

## :heartpulse: Sponsorlist

- [avegy](https://github.com/avegy)
- [eichhorn](https://github.com/eichhorn)

___

### :floppy_disk: The [story](https://mag37.org/posts/project_dockcheck/) behind it. 1 year in retrospect.
