#!/usr/bin/env bash
VERSION="v0.6.2"
### ChangeNotes: Added options: -u; auto self update. -I; print release URL, +style and colour fixes.
Github="https://github.com/mag37/dockcheck"
RawUrl="https://raw.githubusercontent.com/mag37/dockcheck/main/dockcheck.sh"

set -uo pipefail
shopt -s nullglob
shopt -s failglob

# Variables for self updating
ScriptArgs=( "$@" )
ScriptPath="$(readlink -f "$0")"
ScriptWorkDir="$(dirname "$ScriptPath")"

# Check if there's a new release of the script
LatestRelease="$(curl -s -r 0-50 "$RawUrl" | sed -n "/VERSION/s/VERSION=//p" | tr -d '"')"
LatestChanges="$(curl -s -r 0-200 "$RawUrl" | sed -n "/ChangeNotes/s/# ChangeNotes: //p")"

# User customizable defaults
if [[ -s "${HOME}/.config/dockcheck.config" ]]; then
  source "${HOME}/.config/dockcheck.config"
elif [[ -s "${ScriptWorkDir}/dockcheck.config" ]]; then
  source "${ScriptWorkDir}/dockcheck.config"
fi

# Help Function
Help() {
  echo "Syntax:     dockcheck.sh [OPTION] [part of name to filter]"
  echo "Example:    dockcheck.sh -y -d 10 -e nextcloud,heimdall"
  echo
  echo "Options:"
  echo "-a|y   Automatic updates, without interaction."
  echo "-c     Exports metrics as prom file for the prometheus node_exporter. Provide the collector textfile directory."
  echo "-d N   Only update to new images that are N+ days old. Lists too recent with +prefix and age. 2xSlower."
  echo "-e X   Exclude containers, separated by comma."
  echo "-f     Force stack restart after update. Caution: restarts once for every updated container within stack."
  echo "-h     Print this Help."
  echo "-i     Inform - send a preconfigured notification."
  echo "-I     Prints custom releasenote urls alongside each container with updates (requires urls.list)."
  echo "-l     Only update if label is set. See readme."
  echo "-m     Monochrome mode, no printf colour codes and hides progress bar."
  echo "-n     No updates; only checking availability without interaction."
  echo "-p     Auto-prune dangling images after update."
  echo "-r     Allow updating images for docker run; won't update the container."
  echo "-s     Include stopped containers in the check. (Logic: docker ps -a)."
  echo "-t     Set a timeout (in seconds) per container for registry checkups, 10 is default."
  echo "-u     Allow automatic self updates - caution as this will pull new code and autorun it."
  echo "-v     Prints current version."
  echo "-x N   Set max asynchronous subprocesses, 1 default, 0 to disable, 32+ tested."
  echo
  echo "Project source: $Github"
}

# Initialise variables
Timeout=${Timeout:=10}
MaxAsync=${MaxAsync:=1}
BarWidth=${BarWidth:=50}
AutoMode=${AutoMode:=false}
DontUpdate=${DontUpdate:=false}
AutoPrune=${AutoPrune:=false}
AutoSelfUpdate=${AutoSelfUpdate:=false}
OnlyLabel=${OnlyLabel:=false}
Notify=${Notify:=false}
ForceRestartStacks=${ForceRestartStacks:=false}
DRunUp=${DRunUp:=false}
MonoMode=${MonoMode:=false}
PrintReleaseURL=${PrintReleaseURL:=false}
Stopped=${Stopped:=""}
CollectorTextFileDirectory=${CollectorTextFileDirectory:-}
Exclude=${Exclude:-}
DaysOld=${DaysOld:-}
Excludes=()
GotUpdates=()
NoUpdates=()
GotErrors=()
SelectedUpdates=()
regbin=""
jqbin=""

# Colours
c_red="\033[0;31m"
c_green="\033[0;32m"
c_yellow="\033[0;33m"
c_blue="\033[0;34m"
c_teal="\033[0;36m"
c_reset="\033[0m"

while getopts "ayfhiIlmnprsuvc:e:d:t:x:" options; do
  case "${options}" in
    a|y) AutoMode=true ;;
    c)   CollectorTextFileDirectory="${OPTARG}" ;;
    d)   DaysOld=${OPTARG} ;;
    e)   Exclude=${OPTARG} ;;
    f)   ForceRestartStacks=true ;;
    i)   Notify=true ;;
    I)   PrintReleaseURL=true ;;
    l)   OnlyLabel=true ;;
    m)   MonoMode=true ;;
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

# Set $1 to a variable for name filtering later
SearchName="${1:-}"

# Setting up options and sourcing functions
if [[ "$DontUpdate" == true ]]; then AutoMode=true; fi
if [[ "$MonoMode" == true ]]; then declare c_{red,green,yellow,blue,teal,reset}=""; fi
if [[ "$Notify" == true ]]; then
  if [[ -s "${ScriptWorkDir}/notify.sh" ]]; then
    source "${ScriptWorkDir}/notify.sh"
  else Notify=false
  fi
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

self_update_curl() {
  cp "$ScriptPath" "$ScriptPath".bak
  if command -v curl &>/dev/null; then
    curl -L $RawUrl > "$ScriptPath"; chmod +x "$ScriptPath"
    printf "\n%b---%b starting over with the updated version %b---%b\n" "$c_yellow" "$c_teal" "$c_yellow" "$c_reset"
    exec "$ScriptPath" "${ScriptArgs[@]}" # run the new script with old arguments
    exit 1 # Exit the old instance
  elif command -v wget &>/dev/null; then
    wget $RawUrl -O "$ScriptPath"; chmod +x "$ScriptPath"
    printf "\n%b---%b starting over with the updated version %b---%b\n" "$c_yellow" "$c_teal" "$c_yellow" "$c_reset"
    exec "$ScriptPath" "${ScriptArgs[@]}" # run the new script with old arguments
    exit 0 # exit the old instance
  else
    printf "\n%bcurl/wget not available %b- download the update manually: %b%s %b\n" "$c_red" "$c_reset" "$c_teal" "$Github" "$c_reset"
  fi
}

self_update() {
  cd "$ScriptWorkDir" || { printf "%bPath error,%b skipping update.\n" "$c_red" "$c_reset"; return; }
  if command -v git &>/dev/null && [[ "$(git ls-remote --get-url 2>/dev/null)" =~ .*"mag37/dockcheck".* ]]; then
    printf "\n%s\n" "Pulling the latest version."
    git pull --force || { printf "%bGit error,%b manually pull/clone.\n" "$c_red" "$c_reset"; return; }
    printf "\n%s\n" "--- starting over with the updated version ---"
    cd - || { printf "%bPath error.%b\n" "$c_red"; return; }
    exec "$ScriptPath" "${ScriptArgs[@]}" # run the new script with old arguments
    exit 0 # exit the old instance
  else
    cd - || { printf "%bPath error.%b\n" "$c_red"; return; }
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
        if [[ "$CC" -lt 1 || "$CC" -gt $UpdCount ]]; then # Reset choice if out of bounds
          echo "Number not in list: $CC"; unset ChoiceClean; break 1
        else
          SelectedUpdates+=( "${GotUpdates[$CC-1]}" )
        fi
      done
    fi
  done
  printf "\n%bUpdating container(s):%b\n" "$c_blue" "$c_reset"
  printf "%s\n" "${SelectedUpdates[@]}"
  printf "\n"
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

# Function to add user-provided urls to releasenotes
releasenotes() {
  for update in "${GotUpdates[@]}"; do
    found=false
    while read -r container url; do
      if [[ "$update" == "$container" ]]; then Updates+=("$update  ->  $url"); found=true; fi
    done < "${ScriptWorkDir}/urls.list"
    if [[ "$found" == false ]]; then Updates+=("$update  ->  url missing"); else continue; fi
  done
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
  if command -v curl &>/dev/null; then curl -L "$GetUrl" > "$ScriptWorkDir/$BinaryName";
  elif command -v wget &>/dev/null; then wget "$GetUrl" -O "$ScriptWorkDir/$BinaryName";
  else printf "%s\n" "curl/wget not available - get $BinaryName manually from the repo link, exiting."; exit 1;
  fi
  [[ -f "$ScriptWorkDir/$BinaryName" ]] && chmod +x "$ScriptWorkDir/$BinaryName"
}

distro_checker() {
  if [[ -f /etc/arch-release ]]; then PkgInstaller="sudo pacman -S"
  elif [[ -f /etc/redhat-release ]]; then PkgInstaller="sudo dnf install"
  elif [[ -f /etc/SuSE-release ]]; then PkgInstaller="sudo zypper install"
  elif [[ -f /etc/debian_version ]]; then PkgInstaller="sudo apt-get install"
  elif [[ -f /etc/alpine-release ]] ; then PkgInstaller="doas apk add"
  elif [[ $(uname -s) == "Darwin" ]]; then PkgInstaller="brew install"
  else PkgInstaller="ERROR"; printf "\n%bNo distribution could be determined%b, falling back to static binary.\n" "$c_yellow" "$c_reset"
  fi
}

# Dependency check + installer function
dependency_check() {
  AppName="$1"
  AppVar="$2"
  AppUrl="$3"
  if command -v "$AppName" &>/dev/null; then export "$AppVar"="$AppName";
  elif [[ -f "$ScriptWorkDir/$AppName" ]]; then export "$AppVar"="$ScriptWorkDir/$AppName";
  else
    printf "%s\n" "Required dependency '$AppName' missing, do you want to install it?"
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
          [[ -f "$ScriptWorkDir/$AppName" ]] && { export "$AppVar"="$ScriptWorkDir/$1" && printf "\n%b%b downloaded.%b\n" "$c_green" "$AppName" "$c_reset"; }
      fi
    else printf "\n%bDependency missing, exiting.%b\n" "$c_red" "$c_reset"; exit 1;
    fi
  fi
  # Final check if binary is correct
  [[ "$1" == "jq" ]] && VerFlag="--version"
  [[ "$1" == "regctl" ]] && VerFlag="version"
  ${!AppVar} "$VerFlag" &> /dev/null  || { printf "%s\n" "$AppName is not working - try to remove it and re-download it, exiting."; exit 1; }
}

# Numbered List function
# if urls.list exists add release note url per line
options() {
  num=1
  if [[ -s "$ScriptWorkDir/urls.list" ]] && [[ "$PrintReleaseURL" == true ]]; then releasenotes; else Updates=("${GotUpdates[@]}"); fi
  for update in "${Updates[@]}"; do
    echo "$num) $update"
    ((num++))
  done
}

# Version check & initiate self update
if [[ "$VERSION" != "$LatestRelease" ]]; then
  printf "New version available! %b%s%b ⇒ %b%s%b \n Change Notes: %s \n" "$c_yellow" "$VERSION" "$c_reset" "$c_green" "$LatestRelease" "$c_reset" "$LatestChanges"
  if [[ "$AutoMode" == false ]]; then
    read -r -p "Would you like to update? y/[n]: " SelfUpdate
    [[ "$SelfUpdate" =~ [yY] ]] && self_update
  elif [[ "$AutoMode" == true ]] && [[ "$AutoSelfUpdate" == true ]]; then self_update;
  else
    [[ "$Notify" == true ]] && { [[ $(type -t dockcheck_notification) == function ]] && dockcheck_notification "$VERSION" "$LatestRelease" "$LatestChanges" || printf "Could not source notification function.\n"; }
  fi
fi

dependency_check "regctl" "regbin" "https://github.com/regclient/regclient/releases/latest/download/regctl-linux-TEMP"
dependency_check "jq" "jqbin" "https://github.com/jqlang/jq/releases/latest/download/jq-linux-TEMP"

# Check docker compose binary
if docker compose version &>/dev/null; then DockerBin="docker compose" ;
elif docker-compose -v &>/dev/null; then DockerBin="docker-compose" ;
elif docker -v &>/dev/null; then
  printf "%s\n" "No docker compose binary available, using plain docker (Not recommended!)"
  printf "%s\n" "'docker run' will ONLY update images, not the container itself."
else
  printf "%s\n" "No docker binaries available, exiting."
  exit 1
fi

# Listing typed exclusions
if [[ -n ${Excludes[*]:-} ]]; then
  printf "\n%bExcluding these names:%b\n" "$c_blue" "$c_reset"
  printf "%s\n" "${Excludes[@]}"
  printf "\n"
fi

# Variables for progress_bar function
ContCount=$(docker ps $Stopped --filter "name=$SearchName" --format '{{.Names}}' | wc -l)
RegCheckQue=0

# Testing and setting timeout binary
t_out=$(command -v timeout || echo "")
if [[ $t_out ]]; then
  t_out=$(realpath "$t_out" 2>/dev/null || readlink -f "$t_out")
  if [[ $t_out =~ "busybox" ]]; then
    t_out="timeout ${Timeout}"
  else t_out="timeout --foreground ${Timeout}"
  fi
else t_out=""
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

  local NoUpdates GotUpdates GotErrors
  ImageId=$(docker inspect "$i" --format='{{.Image}}')
  RepoUrl=$(docker inspect "$i" --format='{{.Config.Image}}')
  LocalHash=$(docker image inspect "$ImageId" --format '{{.RepoDigests}}')

  # Checking for errors while setting the variable
  if RegHash=$($t_out "$regbin" -v error image digest --list "$RepoUrl" 2>&1); then
    if [[ "$LocalHash" = *"$RegHash"* ]]; then
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
export t_out regbin RepoUrl DaysOld

# Check for POSIX xargs with -P option, fallback without async
if (echo "test" | xargs -P 2 >/dev/null 2>&1) && [[ "$MaxAsync" != 0 ]]; then
  XargsAsync="-P $MaxAsync"
else
  XargsAsync=""
  [[ "$MaxAsync" != 0 ]] && printf "%bMissing POSIX xargs, consider installing 'findutils' for asynchronous lookups.%b\n" "$c_red" "$c_reset"
fi

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
  docker ps $Stopped --filter "name=$SearchName" --format '{{.Names}}' | \
  xargs $XargsAsync -I {} bash -c 'check_image "{}"' \
)

# Sort arrays alphabetically
IFS=$'\n'
NoUpdates=($(sort <<<"${NoUpdates[*]:-}"))
GotUpdates=($(sort <<<"${GotUpdates[*]:-}"))
unset IFS

# Run the prometheus exporter function
if [[ -n "${CollectorTextFileDirectory:-}" ]]; then
  if type -t prometheus_exporter &>/dev/null; then
    prometheus_exporter ${#NoUpdates[@]} ${#GotUpdates[@]} ${#GotErrors[@]}
  else
    printf "%s\n" "Could not source prometheus exporter function."
  fi
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
   [[ "$AutoMode" == false ]] && options || printf "%s\n" "${GotUpdates[@]}"
   [[ "$Notify" == true ]] && { type -t send_notification &>/dev/null && send_notification "${GotUpdates[@]}" || printf "Could not source notification function.\n"; }
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
    NumberofUpdates="${#SelectedUpdates[@]}"
    CurrentQue=0
    for i in "${SelectedUpdates[@]}"
    do
      ((CurrentQue+=1))
      unset CompleteConfs
      # Extract labels and metadata
      ContLabels=$(docker inspect "$i" --format '{{json .Config.Labels}}')
      ContImage=$(docker inspect "$i" --format='{{.Config.Image}}')
      ContPath=$($jqbin -r '."com.docker.compose.project.working_dir"' <<< "$ContLabels")
      [[ "$ContPath" == "null" ]] && ContPath=""
      ContConfigFile=$($jqbin -r '."com.docker.compose.project.config_files"' <<< "$ContLabels")
      [[ "$ContConfigFile" == "null" ]] && ContConfigFile=""
      ContName=$($jqbin -r '."com.docker.compose.service"' <<< "$ContLabels")
      [[ "$ContName" == "null" ]] && ContName=""
      ContEnv=$($jqbin -r '."com.docker.compose.project.environment_file"' <<< "$ContLabels")
      [[ "$ContEnv" == "null" ]] && ContEnv=""
      ContUpdateLabel=$($jqbin -r '."mag37.dockcheck.update"' <<< "$ContLabels")
      [[ "$ContUpdateLabel" == "null" ]] && ContUpdateLabel=""
      ContRestartStack=$($jqbin -r '."mag37.dockcheck.restart-stack"' <<< "$ContLabels")
      [[ "$ContRestartStack" == "null" ]] && ContRestartStack=""

      # Checking if compose-values are empty - hence started with docker run
      if [[ -z "$ContPath" ]]; then
        if [[ "$DRunUp" == true ]]; then
          docker pull "$ContImage"
          printf "%s\n" "$i got a new image downloaded, rebuild manually with preferred 'docker run'-parameters"
        else
          printf "\n%b%s%b has no compose labels, probably started with docker run - %bskipping%b\n\n" "$c_yellow" "$i" "$c_reset" "$c_yellow" "$c_reset"
        fi
        continue
      fi
      # cd to the compose-file directory to account for people who use relative volumes
      cd "$ContPath" || { printf "\n%bPath error - skipping%b %s" "$c_red" "$c_reset" "$i"; continue; }
      ## Reformatting path + multi compose
      if [[ $ContConfigFile = '/'* ]]; then
        CompleteConfs=$(for conf in ${ContConfigFile//,/ }; do printf -- "-f %s " "$conf"; done)
      else
        CompleteConfs=$(for conf in ${ContConfigFile//,/ }; do printf -- "-f %s/%s " "$ContPath" "$conf"; done)
      fi
      printf "\n%bNow updating (%s/%s): %b%s%b\n" "$c_teal" "$CurrentQue" "$NumberofUpdates" "$c_blue" "$i" "$c_reset"
      # Checking if Label Only -option is set, and if container got the label
      [[ "$OnlyLabel" == true ]] && { [[ "$ContUpdateLabel" != true ]] && { echo "No update label, skipping."; continue; } }
      docker pull "$ContImage" || { printf "\n%bDocker error, exiting!%b\n" "$c_red" "$c_reset" ; exit 1; }
      # Check if the container got an environment file set and reformat it
      ContEnvs=""
      if [[ -n "$ContEnv" ]]; then ContEnvs=$(for env in ${ContEnv//,/ }; do printf -- "--env-file %s " "$env"; done); fi
      # Check if the whole stack should be restarted
      if [[ "$ContRestartStack" == true ]] || [[ "$ForceRestartStacks" == true ]]; then
        ${DockerBin} ${CompleteConfs} stop; ${DockerBin} ${CompleteConfs} ${ContEnvs} up -d
      else
        ${DockerBin} ${CompleteConfs} ${ContEnvs} up -d ${ContName}
      fi
    done
    if [[ "$AutoPrune" == false ]] && [[ "$AutoMode" == false ]]; then printf "\n"; read -rep "Would you like to prune dangling images? y/[n]: " AutoPrune; fi
    if [[ "$AutoPrune" == true ]] || [[ "$AutoPrune" =~ [yY] ]]; then docker image prune -f; fi
    printf "\n%bAll done!%b\n" "$c_green" "$c_reset"
  else
    printf "\nNo updates installed, exiting.\n"
  fi
else
  printf "\nNo updates available, exiting.\n"
fi

exit 0
