#!/usr/bin/env bash
VERSION="v0.6.0"
Github="https://github.com/sudo-kraken/podcheck"
RawUrl="https://raw.githubusercontent.com/sudo-kraken/podcheck/upstream_patches/podcheck.sh"

# Variables for self-updating
ScriptArgs=( "$@" )
ScriptPath="$(readlink -f "$0")"
ScriptWorkDir="$(dirname "$ScriptPath")"

# Check if there's a new release of the script
LatestRelease="$(curl -s -r 0-100 "$RawUrl" | sed -n "/VERSION/s/VERSION=//p" | tr -d '"')"
LatestChanges="$(curl -s -r 0-200 "$RawUrl" | sed -n "/ChangeNotes/s/# ChangeNotes: //p")"

Help() {
  echo "Syntax:     podcheck.sh [OPTION] [part of name to filter]"
  echo "Example:    podcheck.sh -y -d 10 -e nextcloud,heimdall"
  echo
  echo "Options:"
  echo "-a|y   Automatic updates, without interaction."
  echo "-c     Exports metrics as prom file for the prometheus node_exporter. Provide the collector textfile directory."
  echo "-d N   Only update to new images that are N+ days old. Lists too recent with +prefix and age."
  echo "-e X   Exclude containers, separated by comma."
  echo "-f     Force pod restart after update."
  echo "-h     Print this Help."
  echo "-i     Inform - send a preconfigured notification."
  echo "-l     Only update if label is set. See readme."
  echo "-m     Monochrome mode, no printf colour codes."
  echo "-n     No updates; only checking availability."
  echo "-p     Auto-prune dangling images after update."
  echo "-r     Allow updating images for podman run; won't update the container."
  echo "-s     Include stopped containers in the check."
  echo "-t     Set a timeout (in seconds) per container for registry checkups, 10 is default."
  echo "-v     Prints current version."
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

# Initialise variables first
AutoUp="no"
AutoPrune=""
Stopped=""
Timeout=10
NoUpdateMode=false
Excludes=()
GotUpdates=()
NoUpdates=()
GotErrors=()
NotifyUpdates=()
SelectedUpdates=()
OnlyLabel=false
ForceRestartPods=false

# regbin will be set later.
regbin=""

set -euo pipefail

while getopts "aynpfrhlisvmc:e:d:t:v" options; do
  case "${options}" in
    a|y) AutoUp="yes" ;;
    c)
      CollectorTextFileDirectory="${OPTARG}"
      if ! [[ -d $CollectorTextFileDirectory ]]; then
        printf "The directory (%s) does not exist.\n" "${CollectorTextFileDirectory}"
        exit 2
      fi
      ;;
    n)   NoUpdateMode=true ;;
    r)   DRunUp="yes" ;;
    p)   AutoPrune="yes" ;;
    l)   OnlyLabel=true ;;
    f)   ForceRestartPods=true ;;
    i)   [ -s "$ScriptWorkDir/notify.sh" ] && { source "$ScriptWorkDir/notify.sh"; Notify="yes"; } ;;
    e)   Exclude="${OPTARG}"
          IFS=',' read -ra Excludes <<< "$Exclude"
          ;;
    m)   declare c_{red,green,yellow,blue,teal,reset}="" ;;
    s)   Stopped="-a" ;;
    t)   Timeout="${OPTARG}" ;;
    d)   DaysOld="${OPTARG}"
         if ! [[ $DaysOld =~ ^[0-9]+$ ]]; then
           printf "Days -d argument given (%s) is not a number.\n" "${DaysOld}"
           exit 2
         fi
         ;;
    v)   printf "%s\n" "$VERSION"; exit 0 ;;
    h|*) Help; exit 2 ;;
  esac
done
shift "$((OPTIND-1))"

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

datecheck() {
  if [[ -z "${DaysOld:-}" ]]; then
    return 0
  fi
  if ! ImageDate=$($regbin -v error image inspect "$RepoUrl" --format='{{.Created}}' 2>/dev/null | cut -d" " -f1); then
     return 1
  fi
  ImageAge=$(( ( $(date +%s) - $(date -d "$ImageDate" +%s) ) / 86400 ))
  if [ "$ImageAge" -gt "$DaysOld" ]; then
    return 0
  else
    return 1
  fi
}

progress_bar() {
  QueCurrent="$1"
  QueTotal="$2"
  ((Percent=100*QueCurrent/QueTotal))
  ((Complete=50*Percent/100))
  ((Left=50-Complete))
  BarComplete=$(printf "%${Complete}s" | tr " " "#")
  BarLeft=$(printf "%${Left}s" | tr " " "-")
  if [[ "$QueTotal" != "$QueCurrent" ]]; then
    printf "\r[%s%s] %s/%s " "$BarComplete" "$BarLeft" "$QueCurrent" "$QueTotal"
  else
    printf "\r[%b%s%b] %s/%s \n" "$c_teal" "$BarComplete" "$c_reset" "$QueCurrent" "$QueTotal"
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

# Dependency check for jq
if command -v jq &>/dev/null; then
  jqbin="jq"
elif [[ -f "$ScriptWorkDir/jq" ]]; then
  jqbin="$ScriptWorkDir/jq"
else
  printf "%s\n" "Required dependency 'jq' missing, do you want to install it?"
  read -r -p "y: With packagemanager (sudo). / s: Download static binary. y/s/[n] " GetJq
  GetJq=${GetJq:-no}
  if [[ "$GetJq" =~ [yYsS] ]]; then
    [[ "$GetJq" =~ [yY] ]] && distro_checker
    if [[ -n "$PkgInstaller" && "$PkgInstaller" != "ERROR" ]]; then 
      (sudo $PkgInstaller jq)
      PkgExitcode="$?"
      [[ "$PkgExitcode" == 0 ]] && jqbin="jq" || printf "\n%bPackagemanager install failed%b, falling back to static binary.\n" "$c_yellow" "$c_reset"
    fi
    if [[ "$GetJq" =~ [nN] || "$PkgInstaller" == "ERROR" || "$PkgExitcode" != 0 ]]; then
      binary_downloader "jq" "https://github.com/jqlang/jq/releases/latest/download/jq-linux-TEMP"
      [[ -f "$ScriptWorkDir/jq" ]] && jqbin="$ScriptWorkDir/jq"
    fi
  else
    printf "\n%bDependency missing, exiting.%b\n" "$c_red" "$c_reset"
    exit 1
  fi
fi

$jqbin --version &>/dev/null || { printf "%s\n" "jq is not working - try to remove it and re-download it, exiting."; exit 1; }

# Dependency check for regctl
if command -v regctl &>/dev/null; then
  regbin="regctl"
elif [[ -f "$ScriptWorkDir/regctl" ]]; then
  regbin="$ScriptWorkDir/regctl"
else
  read -r -p "Required dependency 'regctl' missing, do you want it downloaded? y/[n] " GetRegctl
  if [[ "$GetRegctl" =~ [yY] ]]; then
    binary_downloader "regctl" "https://github.com/regclient/regclient/releases/latest/download/regctl-linux-TEMP"
    if [[ -f "$ScriptWorkDir/regctl" ]]; then
      regbin="$ScriptWorkDir/regctl"
    else
      printf "\n%bFailed to download regctl, exiting.%b\n" "$c_red" "$c_reset"
      exit 1
    fi
  else
    printf "\n%bDependency missing, exiting.%b\n" "$c_red" "$c_reset"
    exit 1
  fi
fi

$regbin version &>/dev/null || { printf "%s\n" "regctl is not working - try to remove it and re-download it, exiting."; exit 1; }

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

process_container() {
  local container="$1"
  ((RegCheckQue++))
  progress_bar "$RegCheckQue" "$ContCount"
  >&2 echo "Processing container: $container"
  
  for e in "${Excludes[@]}"; do 
    if [[ "$container" == "$e" ]]; then
      return 0
    fi
  done
  
  local ImageId RepoUrl LocalHash RegHash
  if ! ImageId=$(podman inspect "$container" --format='{{.Image}}'); then
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
      
      if [ -z "$ContPath" ]; then
        if systemctl --user status "$i.service" &>/dev/null; then
          unit="$i.service"
        elif [ "$(id -u)" -eq 0 ] && systemctl status "$i.service" &>/dev/null; then
          unit="$i.service"
        else
          pattern="^$(echo "$i" | sed 's/_/[_-]/g')\.service$"
          candidates=$(systemctl --user list-units --type=service --no-legend | awk '{print $1}' | grep -iE "$pattern")
          if [ "$(echo "$candidates" | wc -l)" -eq 1 ]; then
            unit="$candidates"
          elif [ "$(echo "$candidates" | wc -l)" -gt 1 ]; then
            for cand in $candidates; do
              if [[ "${cand,,}" == "${i,,}.service" ]]; then
                unit="$cand"
                break
              fi
            done
            if [ -z "${unit:-}" ]; then
              unit=$(echo "$candidates" | head -n 1)
            fi
          fi
        fi

        if [ -n "${unit:-}" ]; then
          echo "Detected Quadlet-managed container: $i (matched unit: $unit)"
          podman pull "$ContImage"
          if systemctl --user restart "$unit" &>/dev/null; then
            echo "Quadlet container $i updated and restarted (user scope)."
          elif [ "$(id -u)" -eq 0 ] && systemctl restart "$unit" &>/dev/null; then
            echo "Quadlet container $i updated and restarted (system scope)."
          else
            echo "Failed to restart unit $unit for container $i."
          fi
        else
          if [ "$DRunUp" == "yes" ]; then
            podman pull "$ContImage"
            printf "%s\n" "$i got a new image downloaded; rebuild manually with preferred 'podman run' parameters"
          else
            printf "\n%b%s%b has no compose labels or associated systemd unit; %bskipping%b\n\n" "$c_yellow" "$i" "$c_reset" "$c_yellow" "$c_reset"
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
      [[ "$OnlyLabel" == true ]] && { [[ "$ContUpdateLabel" != "true" ]] && { echo "No update label, skipping."; continue; } }
      podman pull "$ContImage"
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
    [[ "$AutoPrune" =~ [yY] ]] && podman image prune -f
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
