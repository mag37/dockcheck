#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob
shopt -s failglob

VERSION="v0.7.1"

# Variables for self-updating
ScriptArgs=( "$@" )
ScriptPath="$(readlink -f "$0")"
ScriptWorkDir="$(dirname "$ScriptPath")"

# ChangeNotes: Sync with dockcheck v0.7.1 - Added advanced notifications, async processing, configuration system
Github="https://github.com/sudo-kraken/podcheck"
RawUrl="https://raw.githubusercontent.com/sudo-kraken/podcheck/main/podcheck.sh"

# Source helper functions
source_if_exists_or_fail() {
  if [[ -s "$1" ]]; then
    source "$1"
    [[ "${DisplaySourcedFiles:-false}" == true ]] && echo " * sourced config: ${1}"
    return 0
  else
    return 1
  fi
}

# User customizable defaults
source_if_exists_or_fail "${HOME}/.config/podcheck.config" || source_if_exists_or_fail "${ScriptWorkDir}/podcheck.config"

cleanup() {
    # Temporarily disable failglob for cleanup
    shopt -u failglob
    
    # Remove temporary files if any
    rm -f /tmp/podcheck-* 2>/dev/null
    # Remove backup file if update failed
    [ -f "$ScriptPath.bak" ] && rm -f "$ScriptPath.bak"
    # Clean up any temporary downloaded binaries
    [ -f "/tmp/regctl.tmp" ] && rm -f "/tmp/regctl.tmp"
    [ -f "/tmp/jq.tmp" ] && rm -f "/tmp/jq.tmp"
    
    # Re-enable failglob
    shopt -s failglob
}
trap cleanup EXIT

# Check if there's a new release of the script
LatestRelease="$(curl -s -r 0-100 "$RawUrl" | sed -n "/VERSION/s/VERSION=//p" | tr -d '"')"
LatestChanges="$(curl -s -r 0-200 "$RawUrl" | sed -n "/ChangeNotes/s/# ChangeNotes: //p")"

# After getting LatestRelease
if [[ -n "$LatestRelease" && "$LatestRelease" != "$VERSION" ]]; then
    printf "\nNew version available: %s\nCurrent version: %s\nChanges: %s\n" \
        "$LatestRelease" "$VERSION" "$LatestChanges"
    read -r -p "Do you want to update? [y/N] " update
    if [[ "$update" =~ [yY] ]]; then
        self_update
    fi
fi

Help() {
  echo "Syntax:     podcheck.sh [OPTION] [comma separated names to include]"
  echo "Example:    podcheck.sh -y -x 10 -d 10 -e nextcloud,heimdall"
  echo
  echo "Options:"
  echo "-a|y   Automatic updates, without interaction."
  echo "-c D   Exports metrics as prom file for the prometheus node_exporter. Provide the collector textfile directory."
  echo "-d N   Only update to new images that are N+ days old. Lists too recent with +prefix and age. 2xSlower."
  echo "-e X   Exclude containers, separated by comma."
  echo "-f     Force stop+start stack after update. Caution: restarts once for every updated container within stack."
  echo "-F     Only compose up the specific container, not the whole compose stack (useful for master-compose structure)."
  echo "-h     Print this Help."
  echo "-i     Inform - send a preconfigured notification."
  echo "-I     Prints custom releasenote urls alongside each container with updates in CLI output (requires urls.list)."
  echo "-l     Only update if label is set. See readme."
  echo "-m     Monochrome mode, no printf colour codes and hides progress bar."
  echo "-M     Prints custom releasenote urls as markdown (requires template support)."
  echo "-n     No updates; only checking availability without interaction."
  echo "-p     Auto-prune dangling images after update."
  echo "-r     Allow checking for updates/updating images for podman run containers. Won't update the container."
  echo "-s     Include stopped containers in the check. (Logic: podman ps -a)."
  echo "-t     Set a timeout (in seconds) per container for registry checkups, 10 is default."
  echo "-u     Allow automatic self updates - caution as this will pull new code and autorun it."
  echo "-v     Prints current version."
  echo "-x N   Set max asynchronous subprocesses, 1 default, 0 to disable, 32+ tested."
  echo
  echo "Project source: $Github"
}

# Colours
c_red="\033[0;31m"
c_green="\033[0;32m"
c_yellow="\033[0;33m"
c_blue="\033[0;34m"
c_teal="\033[0;36m"
c_reset="\033[0m"

# Initialise variables
Timeout=${Timeout:-10}
MaxAsync=${MaxAsync:-1}
BarWidth=${BarWidth:-50}
AutoMode=${AutoMode:-false}
DontUpdate=${DontUpdate:-false}
AutoPrune=${AutoPrune:-false}
AutoSelfUpdate=${AutoSelfUpdate:-false}
OnlyLabel=${OnlyLabel:-false}
Notify=${Notify:-false}
ForceRestartStacks=${ForceRestartStacks:-false}
DRunUp=${DRunUp:-false}
MonoMode=${MonoMode:-false}
PrintReleaseURL=${PrintReleaseURL:-false}
PrintMarkdownURL=${PrintMarkdownURL:-false}
Stopped=${Stopped:-""}
CollectorTextFileDirectory=${CollectorTextFileDirectory:-}
Exclude=${Exclude:-}
DaysOld=${DaysOld:-}
OnlySpecific=${OnlySpecific:-false}
SpecificContainer=${SpecificContainer:-""}
Excludes=()
GotUpdates=()
NoUpdates=()
GotErrors=()
SelectedUpdates=()
CurlArgs="--retry ${CurlRetryCount:-3} --retry-delay ${CurlRetryDelay:-1} --connect-timeout ${CurlConnectTimeout:-5} -sf"
regbin=""
jqbin=""

set -euo pipefail

while getopts "ayfFhiIlmMnprsuvc:e:d:t:x:" options; do
  case "${options}" in
    a|y) AutoMode=true ;;
    c)   CollectorTextFileDirectory="${OPTARG}" ;;
    d)   DaysOld=${OPTARG} ;;
    e)   Exclude=${OPTARG} ;;
    f)   ForceRestartStacks=true ;;
    F)   OnlySpecific=true ;;
    i)   Notify=true ;;
    I)   PrintReleaseURL=true ;;
    l)   OnlyLabel=true ;;
    m)   MonoMode=true ;;
    M)   PrintMarkdownURL=true ;;
    n)   DontUpdate=true; AutoMode=true;;
    p)   AutoPrune=true ;;
    r)   DRunUp=true ;;
    s)   Stopped="-a" ;;
    t)   Timeout="${OPTARG}" ;;
    u)   AutoSelfUpdate=true ;;
    v)   printf "%s\n" "$VERSION"; exit 0 ;;
    x)   MaxAsync=${OPTARG} ;;
    h|*) Help; exit 2 ;;
  esac
done
shift "$((OPTIND-1))"

# Set $1 to a variable for name filtering later, rewriting if multiple
SearchName="${1:-}"
if [[ ! -z "$SearchName" ]]; then
  SearchName="^(${SearchName//,/|})$"
fi

# Check if there's a new release of the script
LatestSnippet="$(curl ${CurlArgs} -r 0-200 "$RawUrl" || printf "undefined")"
LatestRelease="$(echo "${LatestSnippet}" | sed -n "/VERSION/s/VERSION=//p" | tr -d '"')"
LatestChanges="$(echo "${LatestSnippet}" | sed -n "/ChangeNotes/s/# ChangeNotes: //p")"

# Basic notify configuration check
if [[ "${Notify}" == true ]] && [[ ! -s "${ScriptWorkDir}/notify.sh" ]] && [[ -z "${NOTIFY_CHANNELS:-}" ]]; then
  printf "Using v2 notifications with -i flag passed but no notify channels configured in podcheck.config. This will result in no notifications being sent.\n"
fi

# Setting up options and sourcing functions
if [[ "$DontUpdate" == true ]]; then AutoMode=true; fi
if [[ "$MonoMode" == true ]]; then declare c_{red,green,yellow,blue,teal,reset}=""; fi
if [[ "$Notify" == true ]]; then
  source_if_exists_or_fail "${ScriptWorkDir}/notify.sh" || source_if_exists_or_fail "${ScriptWorkDir}/notify_templates/notify_v2.sh" || Notify=false
fi
if [[ -n "$Exclude" ]]; then
  IFS=',' read -ra Excludes <<< "$Exclude"
  unset IFS
fi
if [[ -n "$DaysOld" ]]; then
  if ! [[ $DaysOld =~ ^[0-9]+$ ]]; then
    printf "Days -d argument given (%s) is not a number.\n" "$DaysOld"
    exit 2
  fi
fi
if [[ -n "$CollectorTextFileDirectory" ]]; then
  if ! [[ -d  $CollectorTextFileDirectory ]]; then
    printf "The directory (%s) does not exist.\n" "$CollectorTextFileDirectory"
    exit 2
  else
    source "${ScriptWorkDir}/addons/prometheus/prometheus_collector.sh"
  fi
fi

exec_if_exists() {
  if [[ $(type -t $1) == function ]]; then "$@"; fi
}

exec_if_exists_or_fail() {
  [[ $(type -t $1) == function ]] && "$@"
}

# Now get the search name from the first remaining positional parameter
SearchName="${1:-}"

# Self-update functions
self_update_curl() {
  cp "$ScriptPath" "$ScriptPath".bak
  if command -v curl &>/dev/null; then
    curl -L "$RawUrl" > "$ScriptPath"
    chmod +x "$ScriptPath"
    printf "\n%s\n" "--- starting over with the updated version ---"
    exec "$ScriptPath" "${ScriptArgs[@]}"
    exit 1
  elif command -v wget &>/dev/null; then
    wget "$RawUrl" -O "$ScriptPath"
    chmod +x "$ScriptPath"
    printf "\n%s\n" "--- starting over with the updated version ---"
    exec "$ScriptPath" "${ScriptArgs[@]}"
    exit 1
  else
    printf "curl/wget not available - download the update manually: %s \n" "$Github"
  fi
}

self_update() {
  cd "$ScriptWorkDir" || { printf "Path error, skipping update.\n"; return; }
  if command -v git &>/dev/null && [[ "$(git ls-remote --get-url 2>/dev/null)" =~ .*"sudo-kraken/podcheck".* ]]; then
    printf "\n%s\n" "Pulling the latest version."
    git pull --force || { printf "Git error, manually pull/clone.\n"; return; }
    printf "\n%s\n" "--- starting over with the updated version ---"
    cd - || { printf "Path error.\n"; return; }
    exec "$ScriptPath" "${ScriptArgs[@]}"
    exit 1
  else
    cd - || { printf "Path error.\n"; return; }
    self_update_curl
  fi
}

choosecontainers() {
  while [[ -z "${ChoiceClean:-}" ]]; do
    read -r -p "Enter number(s) separated by comma, [a] for all - [q] to quit: " Choice
    if [[ "$Choice" =~ [qQnN] ]]; then
      exit 0
    elif [[ "$Choice" =~ [aAyY] ]]; then
      SelectedUpdates=( "${GotUpdates[@]}" )
      ChoiceClean=${Choice//[,.:;]/ }
    else
      ChoiceClean=${Choice//[,.:;]/ }
      for CC in $ChoiceClean; do
        if [[ "$CC" -lt 1 || "$CC" -gt $UpdCount ]]; then
          echo "Number not in list: $CC"
          unset ChoiceClean
          break 1
        else
          SelectedUpdates+=( "${GotUpdates[$CC-1]}" )
        fi
      done
    fi
  done
  printf "\nUpdating containers:\n"
  printf "%s\n" "${SelectedUpdates[@]}"
  printf "\n"
}

# Function to add user-provided urls to releasenotes
releasenotes() {
  unset Updates
  for update in "${GotUpdates[@]}"; do
    found=false
    while read -r container url; do
      if [[ "$update" == "$container" ]] && [[ "$PrintMarkdownURL" == true ]]; then
        Updates+=("- [$update]($url)"); found=true;
      elif [[ "$update" == "$container" ]]; then
        Updates+=("$update  ->  $url"); found=true;
      fi
    done < "${ScriptWorkDir}/urls.list"
    if [[ "$found" == false ]] && [[ "$PrintMarkdownURL" == true ]]; then 
      Updates+=("- $update  ->  url missing");
    elif [[ "$found" == false ]]; then 
      Updates+=("$update  ->  url missing");
    else 
      continue;
    fi
  done
}

# Numbered List function
# if urls.list exists add release note url per line
list_options() {
  num=1
  for update in "${Updates[@]}"; do
    echo "$num) $update"
    ((num++))
  done
}

progress_bar() {
  QueCurrent="$1"
  QueTotal="$2"
  BarWidth=${BarWidth:-50}
  ((Percent=100*QueCurrent/QueTotal))
  ((Complete=BarWidth*Percent/100))
  ((Left=BarWidth-Complete)) || true # to not throw error when result is 0
  BarComplete=$(printf "%${Complete}s" | tr " " "#")
  BarLeft=$(printf "%${Left}s" | tr " " "-")
  if [[ "$QueTotal" != "$QueCurrent" ]]; then
    printf "\r[%s%s] %s/%s " "$BarComplete" "$BarLeft" "$QueCurrent" "$QueTotal"
  else
    printf "\r[%b%s%b] %s/%s \n" "$c_teal" "$BarComplete" "$c_reset" "$QueCurrent" "$QueTotal"
  fi
}

datecheck() {
  ImageDate=$("$regbin" -v error image inspect "$RepoUrl" --format='{{.Created}}' | cut -d" " -f1)
  ImageEpoch=$(date -d "$ImageDate" +%s 2>/dev/null) || ImageEpoch=$(date -f "%Y-%m-%d" -j "$ImageDate" +%s)
  ImageAge=$(( ( $(date +%s) - ImageEpoch )/86400 ))
  if [[ "$ImageAge" -gt "$DaysOld" ]]; then
    return 0
  else
    return 1
  fi
}



t_out=$(command -v timeout 2>/dev/null || echo "")
if [[ -n "$t_out" ]]; then
  t_out=$(realpath "$t_out" 2>/dev/null || readlink -f "$t_out")
  if [[ "$t_out" =~ "busybox" ]]; then
    t_out="timeout ${Timeout}"
  else
    t_out="timeout --foreground ${Timeout}"
  fi
else
  t_out=""
fi

binary_downloader() {
  BinaryName="$1"
  BinaryUrl="$2"
  case "$(uname --machine)" in
    x86_64|amd64) architecture="amd64" ;;
    arm64|aarch64) architecture="arm64" ;;
    *) printf "\n%bArchitecture not supported, exiting.%b\n" "$c_red" "$c_reset"; exit 1 ;;
  esac
  GetUrl="${BinaryUrl/TEMP/"$architecture"}"
  if command -v curl &>/dev/null; then
    curl -L "$GetUrl" > "$ScriptWorkDir/$BinaryName"
  elif command -v wget &>/dev/null; then
    wget "$GetUrl" -O "$ScriptWorkDir/$BinaryName"
  else
    printf "%s\n" "curl/wget not available - get $BinaryName manually from the repo link, exiting."
    exit 1
  fi
  [[ -f "$ScriptWorkDir/$BinaryName" ]] && chmod +x "$ScriptWorkDir/$BinaryName"
}

distro_checker() {
  if [[ -f /etc/arch-release ]]; then
    PkgInstaller="pacman -S"
  elif [[ -f /etc/redhat-release ]]; then
    PkgInstaller="dnf install"
  elif [[ -f /etc/SuSE-release ]]; then
    PkgInstaller="zypper install"
  elif [[ -f /etc/debian_version ]]; then
    PkgInstaller="apt-get install"
  else
    PkgInstaller="ERROR"
    printf "\n%bNo distribution could be determined%b, falling back to static binary.\n" "$c_yellow" "$c_reset"
  fi
}

# Static binary downloader for dependencies
binary_downloader() {
  BinaryName="$1"
  BinaryUrl="$2"
  case "$(uname -m)" in
    x86_64|amd64) architecture="amd64" ;;
    arm64|aarch64) architecture="arm64";;
    *) printf "\n%bArchitecture not supported, exiting.%b\n" "$c_red" "$c_reset"; exit 1;;
  esac
  GetUrl="${BinaryUrl/TEMP/"$architecture"}"
  if command -v curl &>/dev/null; then
    curl ${CurlArgs} -L "$GetUrl" > "$ScriptWorkDir/$BinaryName" || { printf "ERROR: Failed to curl binary dependency. Rerun the script to retry.\n"; exit 1; }
  elif command -v wget &>/dev/null; then 
    wget --waitretry=1 --timeout=15 -t 10 "$GetUrl" -O "$ScriptWorkDir/$BinaryName";
  else 
    printf "\n%bcurl/wget not available - get %s manually from the repo link, exiting.%b" "$c_red" "$BinaryName" "$c_reset"; exit 1;
  fi
  [[ -f "$ScriptWorkDir/$BinaryName" ]] && chmod +x "$ScriptWorkDir/$BinaryName"
}

distro_checker() {
  isRoot=false
  [[ ${EUID:-} == 0 ]] && isRoot=true
  if [[ -f /etc/alpine-release ]] ; then
    [[ "$isRoot" == true ]] && PkgInstaller="apk add" || PkgInstaller="doas apk add"
  elif [[ -f /etc/arch-release ]]; then
    [[ "$isRoot" == true ]] && PkgInstaller="pacman -S" || PkgInstaller="sudo pacman -S"
  elif [[ -f /etc/debian_version ]]; then
    [[ "$isRoot" == true ]] && PkgInstaller="apt-get install" || PkgInstaller="sudo apt-get install"
  elif [[ -f /etc/redhat-release ]]; then
    [[ "$isRoot" == true ]] && PkgInstaller="dnf install" || PkgInstaller="sudo dnf install"
  elif [[ -f /etc/SuSE-release ]]; then
    [[ "$isRoot" == true ]] && PkgInstaller="zypper install" || PkgInstaller="sudo zypper install"
  elif [[ $(uname -s) == "Darwin" ]]; then 
    PkgInstaller="brew install"
  else 
    PkgInstaller="ERROR"; printf "\n%bNo distribution could be determined%b, falling back to static binary.\n" "$c_yellow" "$c_reset"
  fi
}

# Dependency check + installer function
dependency_check() {
  AppName="$1"
  AppVar="$2"
  AppUrl="$3"
  if command -v "$AppName" &>/dev/null; then 
    export "$AppVar"="$AppName";
  elif [[ -f "$ScriptWorkDir/$AppName" ]]; then 
    export "$AppVar"="$ScriptWorkDir/$AppName";
  else
    printf "\nRequired dependency %b'%s'%b missing, do you want to install it?\n" "$c_teal" "$AppName" "$c_reset"
    read -r -p "y: With packagemanager (sudo). / s: Download static binary. y/s/[n] " GetBin
    GetBin=${GetBin:-no} # set default to no if nothing is given
    if [[ "$GetBin" =~ [yYsS] ]]; then
      [[ "$GetBin" =~ [yY] ]] && distro_checker
      if [[ -n "${PkgInstaller:-}" && "${PkgInstaller:-}" != "ERROR" ]]; then
        [[ $(uname -s) == "Darwin" && "$AppName" == "regctl" ]] && AppName="regclient"
        if $PkgInstaller "$AppName"; then
          AppName="$1"
          export "$AppVar"="$AppName"
          printf "\n%b%b installed.%b\n" "$c_green" "$AppName" "$c_reset"
        else
          PkgInstaller="ERROR"
          printf "\n%bPackagemanager install failed%b, falling back to static binary.\n" "$c_yellow" "$c_reset"
        fi
      fi
      if [[ "$GetBin" =~ [sS] ]] || [[ "$PkgInstaller" == "ERROR" ]]; then
          binary_downloader "$AppName" "$AppUrl"
          [[ -f "$ScriptWorkDir/$AppName" ]] && { export "$AppVar"="$ScriptWorkDir/$1" && printf "\n%b%s downloaded.%b\n" "$c_green" "$AppName" "$c_reset"; }
      fi
    else 
      printf "\n%bDependency missing, exiting.%b\n" "$c_red" "$c_reset"; exit 1;
    fi
  fi
  # Final check if binary is correct
  [[ "$1" == "jq" ]] && VerFlag="--version"
  [[ "$1" == "regctl" ]] && VerFlag="version"
  ${!AppVar} "$VerFlag" &> /dev/null  || { printf "%s\n" "$AppName is not working - try to remove it and re-download it, exiting."; exit 1; }
}

# Use the new dependency management system
dependency_check "regctl" "regbin" "https://github.com/regclient/regclient/releases/latest/download/regctl-linux-TEMP"
dependency_check "jq" "jqbin" "https://github.com/jqlang/jq/releases/latest/download/jq-linux-TEMP"

# Version check & initiate self update
if [[ "$LatestRelease" != "undefined" ]]; then
  if [[ "$VERSION" != "$LatestRelease" ]]; then
    printf "New version available! %b%s%b ⇒ %b%s%b \n Change Notes: %s \n" "$c_yellow" "$VERSION" "$c_reset" "$c_green" "$LatestRelease" "$c_reset" "$LatestChanges"
    if [[ "$AutoMode" == false ]]; then
      read -r -p "Would you like to update? y/[n]: " SelfUpdate
      [[ "$SelfUpdate" =~ [yY] ]] && self_update
    elif [[ "$AutoMode" == true ]] && [[ "$AutoSelfUpdate" == true ]]; then 
      self_update;
    else
      [[ "$Notify" == true ]] && { exec_if_exists_or_fail podcheck_notification "$VERSION" "$LatestRelease" "$LatestChanges" || printf "Could not source notification function.\n"; }
    fi
  fi
else
  printf "ERROR: Failed to curl latest Podcheck.sh release version.\n"
fi

# Version check for notify templates
[[ "$Notify" == true ]] && [[ ! -s "${ScriptWorkDir}/notify.sh" ]] && { exec_if_exists_or_fail notify_update_notification || printf "Could not source notify notification function.\n"; }

# Check podman compose binary
podman info &>/dev/null || { printf "\n%bYour current user does not have permissions to the podman socket - may require root / podman group. Exiting.%b\n" "$c_red" "$c_reset"; exit 1; }
if podman compose version &>/dev/null; then 
  PodmanBin="podman compose" ;
elif podman-compose version &>/dev/null; then 
  PodmanBin="podman-compose" ;
elif podman -v &>/dev/null; then
  printf "%s\n" "No podman compose binary available, using plain podman (Not recommended!)"
  printf "%s\n" "'podman run' will ONLY update images, not the container itself."
else
  printf "%s\n" "No podman binaries available, exiting."
  exit 1
fi

# Listing typed exclusions
if [[ -n ${Excludes[*]:-} ]]; then
  printf "\n%bExcluding these names:%b\n" "$c_blue" "$c_reset"
  printf "%s\n" "${Excludes[@]}"
  printf "\n"
fi



if [[ -n "${Excludes[*]}" ]]; then
  printf "\n%bExcluding these names:%b\n" "$c_blue" "$c_reset"
  printf "%s\n" "${Excludes[@]}"
  printf "\n"
fi

ContCount=$(podman ps $Stopped --filter "name=$SearchName" --format '{{.Names}}' | wc -l)
RegCheckQue=0
start_time=$(date +%s)

printf "\n%bStarting container update check%b\n" "$c_blue" "$c_reset"

# Testing and setting timeout binary
t_out=$(command -v timeout || echo "")
if [[ $t_out ]]; then
  t_out=$(realpath "$t_out" 2>/dev/null || readlink -f "$t_out")
  if [[ $t_out =~ "busybox" ]]; then
    t_out="timeout ${Timeout}"
  else 
    t_out="timeout --foreground ${Timeout}"
  fi
else
  t_out=""
fi

check_image() {
  i="$1"
  local Excludes=($Excludes_string)
  for e in "${Excludes[@]}"; do
    if [[ "$i" == "$e" ]]; then
      printf "%s\n" "Skip $i"
      return
    fi
  done

  # Check ALL containers - original v0.6.0 behavior
  # Filtering happens during update, not during check

  local NoUpdates GotUpdates GotErrors
  ImageId=$(podman inspect "$i" --format='{{.Image}}')
  RepoUrl=$(podman inspect "$i" --format='{{.Config.Image}}')
  LocalHash=$(podman image inspect "$ImageId" --format '{{.RepoDigests}}')

  # Checking for errors while setting the variable
  if RegHash=$($t_out "$regbin" -v error image digest --list "$RepoUrl" 2>&1); then
    if [[ "$LocalHash" == *"$RegHash"* ]]; then
      printf "%s\n" "NoUpdates $i"
    else
      if [[ -n "${DaysOld:-}" ]] && ! datecheck; then
        printf "%s\n" "NoUpdates +$i ${ImageAge}d"
      else
        printf "%s\n" "GotUpdates $i"
      fi
    fi
  else
    printf "%s\n" "GotErrors $i - ${RegHash}"  # Reghash contains an error code here
  fi
}

# Make required functions and variables available to subprocesses
export -f check_image datecheck
export Excludes_string="${Excludes[*]:-}" # Can only export scalar variables
export t_out regbin RepoUrl DaysOld DRunUp jqbin

# Check for POSIX xargs with -P option, fallback without async
if (echo "test" | xargs -P 2 >/dev/null 2>&1) && [[ "$MaxAsync" != 0 ]]; then
  XargsAsync="-P $MaxAsync"
else
  XargsAsync=""
  [[ "$MaxAsync" != 0 ]] && printf "%bMissing POSIX xargs, consider installing 'findutils' for asynchronous lookups.%b\n" "$c_yellow" "$c_reset"
fi

# Variables for progress_bar function
ContCount=$(podman ps $Stopped --filter "name=$SearchName" --format '{{.Names}}' | wc -l)
RegCheckQue=0

# Asynchronously check the image-hash of every running container VS the registry
while read -r line; do
  ((RegCheckQue+=1))
  if [[ "$MonoMode" == false ]]; then progress_bar "$RegCheckQue" "$ContCount"; fi

  Got=${line%% *}  # Extracts the first word (NoUpdates, GotUpdates, GotErrors)
  item=${line#* }

  case "$Got" in
    NoUpdates) NoUpdates+=("$item") ;;
    GotUpdates) GotUpdates+=("$item") ;;
    GotErrors) GotErrors+=("$item") ;;
    Skip) ;;
    *) echo "Error! Unexpected output from subprocess: ${line}" ;;
  esac
done < <( \
  podman ps $Stopped --filter "name=$SearchName" --format '{{.Names}}' | \
  xargs $XargsAsync -I {} bash -c 'check_image "{}"' \
)

# Sort arrays alphabetically
IFS=$'\n'
NoUpdates=($(sort <<<"${NoUpdates[*]:-}"))
GotUpdates=($(sort <<<"${GotUpdates[*]:-}"))
unset IFS

# Run the prometheus exporter function
if [[ -n "${CollectorTextFileDirectory:-}" ]]; then
  exec_if_exists_or_fail prometheus_exporter ${#NoUpdates[@]} ${#GotUpdates[@]} ${#GotErrors[@]} || printf "%s\n" "Could not source prometheus exporter function."
fi

# Define how many updates are available
UpdCount="${#GotUpdates[@]}"

# List what containers got updates or not
if [[ -n ${NoUpdates[*]:-} ]]; then
  printf "\n%bContainers on latest version:%b\n" "$c_green" "$c_reset"
  printf "%s\n" "${NoUpdates[@]}"
fi
if [[ -n ${GotErrors[*]:-} ]]; then
  printf "\n%bContainers with errors, won't get updated:%b\n" "$c_red" "$c_reset"
  printf "%s\n" "${GotErrors[@]}"
  printf "%binfo:%b 'unauthorized' often means not found in a public registry.\n" "$c_blue" "$c_reset"
fi
if [[ -n ${GotUpdates[*]:-} ]]; then
  printf "\n%bContainers with updates available:%b\n" "$c_yellow" "$c_reset"
  if [[ -s "$ScriptWorkDir/urls.list" ]] && [[ "$PrintReleaseURL" == true ]]; then 
    releasenotes; 
  else 
    Updates=("${GotUpdates[@]}"); 
  fi
  [[ "$AutoMode" == false ]] && list_options || printf "%s\n" "${Updates[@]}"
  [[ "$Notify" == true ]] && { exec_if_exists_or_fail send_notification "${GotUpdates[@]}" || printf "\nCould not source notification function.\n"; }
else
  [[ "$Notify" == true ]] && [[ ! -s "${ScriptWorkDir}/notify.sh" ]] && { exec_if_exists_or_fail send_notification "${GotUpdates[@]}" || printf "\nCould not source notification function.\n"; }
fi

# Optionally get updates if there's any
if [[ -n "${GotUpdates:-}" ]]; then
  if [[ "$AutoMode" == false ]]; then
    printf "\n%bChoose what containers to update.%b\n" "$c_teal" "$c_reset"
    choosecontainers
  else
    SelectedUpdates=( "${GotUpdates[@]}" )
  fi
  if [[ "$DontUpdate" == false ]]; then
    printf "\n%bUpdating container(s):%b\n" "$c_blue" "$c_reset"
    printf "%s\n" "${SelectedUpdates[@]}"

    NumberofUpdates="${#SelectedUpdates[@]}"

    CurrentQue=0
    for i in "${SelectedUpdates[@]}"; do
      ((CurrentQue+=1))
      printf "\n%bNow updating (%s/%s): %b%s%b\n" "$c_teal" "$CurrentQue" "$NumberofUpdates" "$c_blue" "$i" "$c_reset"
      ContLabels=$(podman inspect "$i" --format '{{json .Config.Labels}}')
      ContImage=$(podman inspect "$i" --format='{{.Config.Image}}')
      ContPath=$($jqbin -r '."com.docker.compose.project.working_dir"' <<< "$ContLabels")
      [[ "$ContPath" == "null" ]] && ContPath=""
      ContUpdateLabel=$($jqbin -r '."sudo-kraken.podcheck.update"' <<< "$ContLabels")
      [[ "$ContUpdateLabel" == "null" ]] && ContUpdateLabel=""
      # Checking if Label Only -option is set, and if container got the label
      [[ "$OnlyLabel" == true ]] && { [[ "$ContUpdateLabel" != true ]] && { echo "No update label, skipping."; continue; } }

      # Checking if compose-values are empty - hence started with podman run
      if [[ -z "$ContPath" ]]; then
        if [[ "$DRunUp" == true ]]; then
          podman pull "$ContImage"
          printf "%s\n" "$i got a new image downloaded, rebuild manually with preferred 'podman run'-parameters"
        else
          printf "\n%b%s%b has no compose labels, probably started with podman run - %bskipping%b\n\n" "$c_yellow" "$i" "$c_reset" "$c_yellow" "$c_reset"
        fi
        continue
      fi

      podman pull "$ContImage" || { printf "\n%bPodman error, exiting!%b\n" "$c_red" "$c_reset" ; exit 1; }
    done
    printf "\n%bDone pulling updates. %bRecreating updated containers.%b\n" "$c_green" "$c_blue" "$c_reset"

    CurrentQue=0
    for i in "${SelectedUpdates[@]}"; do
      ((CurrentQue+=1))
      unset CompleteConfs
      # Extract labels and metadata
      ContLabels=$(podman inspect "$i" --format '{{json .Config.Labels}}')
      ContImage=$(podman inspect "$i" --format='{{.Config.Image}}')
      ContPath=$($jqbin -r '."com.docker.compose.project.working_dir"' <<< "$ContLabels")
      [[ "$ContPath" == "null" ]] && ContPath=""
      ContConfigFile=$($jqbin -r '."com.docker.compose.project.config_files"' <<< "$ContLabels")
      [[ "$ContConfigFile" == "null" ]] && ContConfigFile=""
      ContName=$($jqbin -r '."com.docker.compose.service"' <<< "$ContLabels")
      [[ "$ContName" == "null" ]] && ContName=""
      ContEnv=$($jqbin -r '."com.docker.compose.project.environment_file"' <<< "$ContLabels")
      [[ "$ContEnv" == "null" ]] && ContEnv=""
      ContUpdateLabel=$($jqbin -r '."sudo-kraken.podcheck.update"' <<< "$ContLabels")
      [[ "$ContUpdateLabel" == "null" ]] && ContUpdateLabel=""
      ContRestartStack=$($jqbin -r '."sudo-kraken.podcheck.restart-stack"' <<< "$ContLabels")
      [[ "$ContRestartStack" == "null" ]] && ContRestartStack=""
      ContOnlySpecific=$($jqbin -r '."sudo-kraken.podcheck.only-specific-container"' <<< "$ContLabels")
      [[ "$ContOnlySpecific" == "null" ]] && ContRestartStack=""

      printf "\n%bNow recreating (%s/%s): %b%s%b\n" "$c_teal" "$CurrentQue" "$NumberofUpdates" "$c_blue" "$i" "$c_reset"

      # Checking if compose-values are empty - hence started with podman run
      [[ -z "$ContPath" ]] && { echo "Not a compose container, skipping."; continue; }

      # Checking if Label Only -option is set, and if container got the label
      [[ "$OnlyLabel" == true ]] && { [[ "$ContUpdateLabel" != true ]] && { echo "No update label, skipping."; continue; } }

      # cd to the compose-file directory to account for people who use relative volumes
      cd "$ContPath" || { printf "\n%bPath error - skipping%b %s" "$c_red" "$c_reset" "$i"; continue; }
      ## Reformatting path + multi compose
      if [[ $ContConfigFile == '/'* ]]; then
        CompleteConfs=$(for conf in ${ContConfigFile//,/ }; do printf -- "-f %s " "$conf"; done)
      else
        CompleteConfs=$(for conf in ${ContConfigFile//,/ }; do printf -- "-f %s/%s " "$ContPath" "$conf"; done)
      fi
      # Check if the container got an environment file set and reformat it
      ContEnvs=""
      if [[ -n "$ContEnv" ]]; then 
        ContEnvs=$(for env in ${ContEnv//,/ }; do printf -- "--env-file %s " "$env"; done); 
      fi
      # Set variable when compose up should only target the specific container, not the stack
      if [[ $OnlySpecific == true ]] || [[ $ContOnlySpecific == true ]]; then 
        SpecificContainer="$ContName"; 
      fi

      # Check if the whole stack should be restarted
      if [[ "$ContRestartStack" == true ]] || [[ "$ForceRestartStacks" == true ]]; then
        ${PodmanBin} ${CompleteConfs} stop; ${PodmanBin} ${CompleteConfs} ${ContEnvs} up -d || { printf "\n%bPodman error, exiting!%b\n" "$c_red" "$c_reset" ; exit 1; }
      else
        ${PodmanBin} ${CompleteConfs} ${ContEnvs} up -d ${SpecificContainer} || { printf "\n%bPodman error, exiting!%b\n" "$c_red" "$c_reset" ; exit 1; }
      fi
    done
    if [[ "$AutoPrune" == false ]] && [[ "$AutoMode" == false ]]; then 
      printf "\n"; read -rep "Would you like to prune dangling images? y/[n]: " AutoPrune; 
    fi
    if [[ "$AutoPrune" == true ]] || [[ "$AutoPrune" =~ [yY] ]]; then 
      printf "\nAuto pruning.."; podman image prune -f; 
    fi
    printf "\n%bAll done!%b\n" "$c_green" "$c_reset"
  else
    printf "\nNo updates installed, exiting.\n"
  fi
else
  printf "\nNo updates available, exiting.\n"
fi

exit 0
      ContName=$($jqbin -r '."com.docker.compose.service"' <<< "$ContLabels")
      [ "$ContName" == "null" ] && ContName=""
      ContEnv=$($jqbin -r '."com.docker.compose.project.environment_file"' <<< "$ContLabels")
      [ "$ContEnv" == "null" ] && ContEnv=""
      ContUpdateLabel=$($jqbin -r '."sudo-kraken.podcheck.update"' <<< "$ContLabels")
      [ "$ContUpdateLabel" == "null" ] && ContUpdateLabel=""
      ContRestartStack=$($jqbin -r '."sudo-kraken.podcheck.restart-stack"' <<< "$ContLabels")
      [ "$ContRestartStack" == "null" ] && ContRestartStack=""
      
      # Add spacing and colors to systemd unit detection
      if [ -z "$ContPath" ]; then
        printf "\n%bChecking systemd units for container: %s%b\n\n" \
          "$c_teal" "$i" "$c_reset"
        
        unit=$(podman inspect "$i" --format '{{.Config.Labels.PODMAN_SYSTEMD_UNIT}}')
        if [ -n "$unit" ]; then
            printf "%bDetected Quadlet-managed container: %s (unit: %s)%b\n\n" \
              "$c_green" "$i" "$unit" "$c_reset"

            printf "%bPulling new image...%b\n\n" "$c_teal" "$c_reset"

            if podman pull "$ContImage"; then
                printf "\n%bSuccessfully pulled new image%b\n\n" "$c_green" "$c_reset"
            else
                printf "\n%bFailed to pull image for %s%b\n\n" "$c_red" "$i" "$c_reset"
                continue
            fi
            printf "%bAttempting to restart unit...%b\n\n" "$c_teal" "$c_reset"
            
            if timeout 60 systemctl --user restart "$unit"; then
                printf "\n%bQuadlet container %s updated and restarted (user scope)%b\n\n" \
                  "$c_green" "$i" "$c_reset"
            else
                printf "\n%bFailed to restart unit %s%b\n" "$c_red" "$unit" "$c_reset"
                systemctl --user status "$unit"
            fi
        fi
        continue
      fi
      cd "$ContPath" || { echo "Path error - skipping $i"; continue; }
      if [[ $ContConfigFile = /* ]]; then
        CompleteConfs=$(for conf in ${ContConfigFile//,/ }; do printf -- "-f %s " "$conf"; done)
      else
        CompleteConfs=$(for conf in ${ContConfigFile//,/ }; do printf -- "-f %s/%s " "$ContPath" "$conf"; done)
      fi
      printf "\n%bNow updating (%s/%s): %b%s%b\n" "$c_teal" "$CurrentQue" "$NumberofUpdates" "$c_blue" "$i" "$c_reset"
      echo "Processing update for container: $i"
      [[ "$OnlyLabel" == true ]] && { [[ "$ContUpdateLabel" != "true" ]] && { echo "No update label, skipping."; continue; } }
      podman pull "$ContImage"
      ContEnvs=""
      if [ -n "$ContEnv" ]; then
        ContEnvs=$(for env in ${ContEnv//,/ }; do printf -- "--env-file %s " "$env"; done)
      fi
      if [[ "$ContRestartStack" == "true" ]] || [[ "$ForceRestartPods" == true ]]; then
        ${PodmanBin} ${CompleteConfs} down
        ${PodmanBin} ${CompleteConfs} ${ContEnvs} up -d
      else
        ${PodmanBin} ${CompleteConfs} ${ContEnvs} up -d ${ContName}
      fi
    done
    if [[ "$AutoPrune" == false ]] && [[ "$AutoMode" == false ]]; then 
      printf "\n"; read -rep "Would you like to prune dangling images? y/[n]: " AutoPrune; 
    fi
    if [[ "$AutoPrune" == true ]] || [[ "$AutoPrune" =~ [yY] ]]; then 
      printf "\nAuto pruning.."; podman image prune -f; 
    fi
    printf "\n%bAll done!%b\n" "$c_green" "$c_reset"
  else
    printf "\nNo updates installed, exiting.\n"
  fi
else
  printf "\nNo updates available, exiting.\n"
fi

exit 0
