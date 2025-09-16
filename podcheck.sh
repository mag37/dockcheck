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
  echo "-f     Force pod restart after update."
  echo "-F     Only compose up the specific container, not the whole compose stack (useful for master-compose structure)."
  echo "-h     Print this Help."
  echo "-i     Inform - send a preconfigured notification."
  echo "-I     Prints custom releasenote urls alongside each container with updates in CLI output (requires urls.list)."
  echo "-l     Only update if label is set. See readme."
  echo "-m     Monochrome mode, no printf color codes and hides progress bar."
  echo "-M     Prints custom releasenote urls as markdown (requires template support)."
  echo "-n     No updates; only checking availability."
  echo "-p     Auto-prune dangling images after update."
  echo "-r     Allow updating images for podman run; won't update the container."
  echo "-s     Include stopped containers in the check."
  echo "-t N   Set a timeout (in seconds) per container for registry checkups, 10 is default."
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

# Check podman compose binary
if podman compose version &>/dev/null; then
  PodmanComposeBin="podman compose"
elif command -v podman-compose &>/dev/null; then
  PodmanComposeBin="podman-compose"
elif podman version &>/dev/null; then
  printf "%s\n" "No podman-compose binary available, using plain podman"
else
  printf "%s\n" "No podman binaries available, exiting."
  exit 1
fi

options() {
  num=1
  for i in "${GotUpdates[@]}"; do
    echo "$num) $i"
    ((num++))
  done
}

if [[ -n "${Excludes[*]}" ]]; then
  printf "\n%bExcluding these names:%b\n" "$c_blue" "$c_reset"
  printf "%s\n" "${Excludes[@]}"
  printf "\n"
fi

ContCount=$(podman ps $Stopped --filter "name=$SearchName" --format '{{.Names}}' | wc -l)
RegCheckQue=0
start_time=$(date +%s)

printf "\n%bStarting container update check%b\n" "$c_blue" "$c_reset"

process_container() {
  local container="$1"
  ((RegCheckQue++))
  progress_bar "$RegCheckQue" "$ContCount"
  
  for e in "${Excludes[@]}"; do 
    if [[ "$container" == "$e" ]]; then
      return 0
    fi
  done
  
  local ImageId RepoUrl LocalHash RegHash
  if ! ImageId=$(podman inspect "$container" --format='{{.Image}}'); then
    echo "Error: Failed to get image ID for container $container"
    return 0
  fi
  if ! RepoUrl=$(podman inspect "$container" --format='{{.ImageName}}'); then
    return 0
  fi
  if ! LocalHash=$(podman image inspect "$ImageId" --format '{{.RepoDigests}}'); then
    return 0
  fi
  
  if RegHash=$(${t_out} $regbin -v error image digest --list "$RepoUrl" 2>/dev/null | xargs); then
    if [[ -n "$RegHash" ]]; then
      if [[ "$LocalHash" == *"$RegHash"* ]]; then
        NoUpdates+=("$container")
      else
        # Create a separate array for notifications
        NotifyUpdates+=("$container")
        # Add to GotUpdates for update logic
        GotUpdates+=("$container")
        
        # If it's too recent based on age check, move it to NoUpdates for display 
        # but keep it in NotifyUpdates
        if [[ -n "${DaysOld:-}" ]] && ! datecheck; then
          NoUpdates+=("+$container ${ImageAge}d")
          # Remove from GotUpdates for update logic
          for i in "${!GotUpdates[@]}"; do
            if [[ "${GotUpdates[i]}" = "$container" ]]; then
              unset 'GotUpdates[i]'
              break
            fi
          done
          # Re-index array after removal
          GotUpdates=("${GotUpdates[@]}")
        fi
      fi
    else
      GotErrors+=("$container - No digest returned")
    fi
  else
    GotErrors+=("$container - Error checking registry") 
  fi
}

# Main loop to process all containers
for container in $(podman ps $Stopped --filter "name=$SearchName" --format '{{.Names}}'); do
  process_container "$container" || true
done

IFS=$'\n'
NoUpdates=($(sort <<<"${NoUpdates[*]}"))
GotUpdates=($(sort <<<"${GotUpdates[*]}"))
unset IFS

echo ""
echo "===== Summary ====="
if [[ -n "${NoUpdates[*]}" ]]; then
  printf "\n%bContainers on latest version:%b\n" "$c_green" "$c_reset"
  printf "%s\n" "${NoUpdates[@]}"
fi
if [[ -n "${GotErrors[*]}" ]]; then
  printf "\n%bContainers with errors; won't get updated:%b\n" "$c_red" "$c_reset"
  printf "%s\n" "${GotErrors[@]}"
  printf "%binfo:%b 'unauthorized' often means not found in a public registry.\n" "$c_blue" "$c_reset"
fi
if [[ -n "${GotUpdates[*]}" ]]; then
  printf "\n%bContainers with updates available:%b\n" "$c_yellow" "$c_reset"
  printf "%s\n" "${GotUpdates[@]}"
fi

echo "Found ${#GotUpdates[@]} containers with updates available"

if [[ -n "${GotUpdates[*]}" ]]; then
  UpdCount="${#GotUpdates[@]}"
  
  # Send notification if -i flag was used, regardless of other options
  [[ "${Notify:-}" == "yes" && -n "${NotifyUpdates[*]}" ]] && send_notification "${NotifyUpdates[@]}"
  
  if [[ "$NoUpdateMode" == true ]]; then
    printf "\n%bNo updates will be performed due to -n flag.%b\n" "$c_blue" "$c_reset"
  elif [[ "$AutoUp" == "yes" ]]; then
    SelectedUpdates=( "${GotUpdates[@]}" )
  else
    printf "\n%bChoose what containers to update:%b\n" "$c_teal" "$c_reset"
    options
    choosecontainers
  fi

  if [ "${#SelectedUpdates[@]}" -gt 0 ]; then
    NumberofUpdates="${#SelectedUpdates[@]}"
    CurrentQue=0
    for i in "${SelectedUpdates[@]}"; do
      ((CurrentQue+=1))
      unset CompleteConfs
      ContLabels=$(podman inspect "$i" --format '{{json .Config.Labels}}')
      ContImage=$(podman inspect "$i" --format='{{.ImageName}}')
      ContPath=$($jqbin -r '."com.docker.compose.project.working_dir"' <<< "$ContLabels")
      [ "$ContPath" == "null" ] && ContPath=""
      ContConfigFile=$($jqbin -r '."com.docker.compose.project.config_files"' <<< "$ContLabels")
      [ "$ContConfigFile" == "null" ] && ContConfigFile=""
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
        $PodmanComposeBin ${CompleteConfs} down
        $PodmanComposeBin ${CompleteConfs} ${ContEnvs} up -d
      else
        $PodmanComposeBin ${CompleteConfs} ${ContEnvs} up -d ${ContName}
      fi
    done
    printf "\n%bAll done!%b\n" "$c_green" "$c_reset"
    if [[ -z "$AutoPrune" ]] && [[ "$AutoUp" == "no" ]]; then
      read -r -p "Would you like to prune dangling images? y/[n]: " AutoPrune
    fi
    
    if [[ "$AutoPrune" =~ [yY] ]] || [[ "$AutoUp" == "yes" ]]; then
      printf "\n%bCleaning up failed update images...%b\n\n" "$c_teal" "$c_reset"
      podman image prune -f
      printf "\n"
    fi
  else
    printf "\nNo updates installed, exiting.\n"
  fi
else
  printf "\nNo updates available, exiting.\n"
fi

# Export metrics if collector directory was specified
if [[ -n "${CollectorTextFileDirectory:-}" ]]; then
  # Calculate check duration
  end_time=$(date +%s)
  check_duration=$((end_time - start_time))
  
  # Source the prometheus collector script if it exists
  if [[ -f "$ScriptWorkDir/addons/prometheus/prometheus_collector.sh" ]]; then
    source "$ScriptWorkDir/addons/prometheus/prometheus_collector.sh"
    # Call the prometheus_exporter with appropriate metrics
    prometheus_exporter "${#NoUpdates[@]}" "${#GotUpdates[@]}" "${#GotErrors[@]}" "$ContCount" "$check_duration"
    printf "\n%bPrometheus metrics exported to: %s/podcheck.prom%b\n" "$c_teal" "$CollectorTextFileDirectory" "$c_reset"
  else
    # Fallback if the collector script isn't found
    cat > "$CollectorTextFileDirectory/podcheck.prom" <<EOF
# HELP podcheck_no_updates Number of containers already on latest image
# TYPE podcheck_no_updates gauge
podcheck_no_updates ${#NoUpdates[@]}
# HELP podcheck_updates Number of containers with updates available
# TYPE podcheck_updates gauge
podcheck_updates ${#GotUpdates[@]}
# HELP podcheck_errors Number of containers with errors during update check
# TYPE podcheck_errors gauge
podcheck_errors ${#GotErrors[@]}
# HELP podcheck_total Total number of containers checked
# TYPE podcheck_total gauge
podcheck_total ${ContCount}
# HELP podcheck_check_duration Duration in seconds for the update check
# TYPE podcheck_check_duration gauge
podcheck_check_duration ${check_duration}
# HELP podcheck_last_check_timestamp Epoch timestamp of the last update check
# TYPE podcheck_last_check_timestamp gauge
podcheck_last_check_timestamp $(date +%s)
EOF
    printf "\n%bPrometheus metrics exported to: %s/podcheck.prom%b\n" "$c_teal" "$CollectorTextFileDirectory" "$c_reset"
  fi
fi

exit 0
