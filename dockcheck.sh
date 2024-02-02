#!/usr/bin/env bash
VERSION="v0.4.0"
### ChangeNotes: Reworked selfupdate (auto git/curl/wget), cleanups, -v for version.
Github="https://github.com/mag37/dockcheck"
RawUrl="https://raw.githubusercontent.com/mag37/dockcheck/main/dockcheck.sh"

### Variables for self updating
ScriptArgs=( "$@" )
ScriptPath="$(readlink -f "$0")"
ScriptName="$(basename "$ScriptPath")"
ScriptWorkDir="$(dirname "$ScriptPath")"

### Check if there's a new release of the script:
LatestRelease="$(curl -s -r 0-50 $RawUrl | sed -n "/VERSION/s/VERSION=//p" | tr -d '"')"
LatestChanges="$(curl -s -r 0-200 $RawUrl | sed -n "/ChangeNotes/s/### ChangeNotes: //p")"


### Help Function:
Help() {
  echo "Syntax:     dockcheck.sh [OPTION] [part of name to filter]" 
  echo "Example:    dockcheck.sh -y -d 10 -e nextcloud,heimdall"
  echo
  echo "Options:"
  echo "-a|y   Automatic updates, without interaction."
  echo "-d N   Only update to new images that are N+ days old. Lists too recent with +prefix and age. 2xSlower."
  echo "-e X   Exclude containers, separated by comma."
  echo "-f     Force stack restart after update. Caution: restarts once for every updated container within stack."
  echo "-h     Print this Help."
  echo "-i     Inform - send a preconfigured notification."
  echo "-l     Only update if label is set. See readme."
  echo "-m     Monochrome mode, no printf color codes."
  echo "-n     No updates, only checking availability."
  echo "-p     Auto-Prune dangling images after update."
  echo "-r     Allow updating images for docker run, wont update the container."
  echo "-s     Include stopped containers in the check. (Logic: docker ps -a)."
  echo "-v     Prints current version."
}

### Colors:
c_red="\033[0;31m"
c_green="\033[0;32m"
c_yellow="\033[0;33m"
c_blue="\033[0;34m"
c_teal="\033[0;36m"
c_reset="\033[0m"

Stopped=""
while getopts "aynpfrhlisvme:d:" options; do
  case "${options}" in
    a|y) AutoUp="yes" ;;
    n)   AutoUp="no" ;;
    r)   DRunUp="yes" ;;
    p)   AutoPrune="yes" ;;
    l)   OnlyLabel=true ;;
    f)   ForceRestartStacks=true ;;
    i)   [ -s "$ScriptWorkDir"/notify.sh ] && { source "$ScriptWorkDir"/notify.sh ; Notify="yes" ; } ;;
    e)   Exclude=${OPTARG} ;;
    m)   declare c_{red,green,yellow,blue,teal,reset}="" ;;
    s)   Stopped="-a" ;;
    v)   printf "%s\n" "$VERSION" ; exit 0 ;;
    d)   DaysOld=${OPTARG}
         if ! [[ $DaysOld =~ ^[0-9]+$ ]] ; then { printf "Days -d argument given (%s) is not a number.\n" "${DaysOld}" ; exit 2 ; } ; fi ;;
    h|*) Help ; exit 2 ;;
  esac
done
shift "$((OPTIND-1))"

self_update_curl() {
  cp "$ScriptPath" "$ScriptPath".bak
  if [[ $(builtin type -P curl) ]]; then 
    curl -L $RawUrl > "$ScriptPath" ; chmod +x "$ScriptPath"  
    printf "\n%s\n" "--- starting over with the updated version ---"
    exec "$ScriptPath" "${ScriptArgs[@]}" # run the new script with old arguments
    exit 1 # exit the old instance
  elif [[ $(builtin type -P wget) ]]; then 
    wget $RawUrl -O "$ScriptPath" ; chmod +x "$ScriptPath"
    printf "\n%s\n" "--- starting over with the updated version ---"
    exec "$ScriptPath" "${ScriptArgs[@]}" # run the new script with old arguments
    exit 1 # exit the old instance
  else
    printf "curl/wget not available - download the update manually: %s \n" "$RawUrl"
  fi
}

self_update() {
  cd "$ScriptWorkDir" || { printf "Path error, skipping update.\n" ; return ; }
  if [[ $(builtin type -P git) ]] && [[ "$(git ls-remote --get-url)" =~ .*"mag37/dockcheck".* ]] ; then
    printf "\n%s\n" "Pulling the latest version."
    git pull --force || { printf "Git error, manually pull/clone.\n" ; return ; }
    printf "\n%s\n" "--- starting over with the updated version ---"
    cd - || { printf "Path error.\n" ; return ; }
    exec "$ScriptPath" "${ScriptArgs[@]}" # run the new script with old arguments
    exit 1 # exit the old instance
  else
    cd - || { printf "Path error.\n" ; return ; }
    self_update_curl
  fi
}

### Choose from list -function:
choosecontainers() {
  while [[ -z "$ChoiceClean" ]]; do
    read -r -p "Enter number(s) separated by comma, [a] for all - [q] to quit: " Choice
    if [[ "$Choice" =~ [qQnN] ]] ; then 
      exit 0
    elif [[ "$Choice" =~ [aAyY] ]] ; then
      SelectedUpdates=( "${GotUpdates[@]}" )
      ChoiceClean=${Choice//[,.:;]/ }
    else
      ChoiceClean=${Choice//[,.:;]/ }
      for CC in $ChoiceClean ; do
        if [[ "$CC" -lt 1 || "$CC" -gt $UpdCount ]] ; then # reset choice if out of bounds
          echo "Number not in list: $CC" ; unset ChoiceClean ; break 1
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
  ImageDate=$($regbin image inspect "$RepoUrl" --format='{{.Created}}' | cut -d" " -f1 )
  ImageAge=$(( ( $(date +%s) - $(date -d "$ImageDate" +%s) )/86400 ))
  if [ "$ImageAge" -gt "$DaysOld" ] ; then
    return 0
  else
    return 1
  fi
}

progress_bar() {
  QueCurrent="$1"
  QueTotal="$2"
  ((Percent=100*QueCurrent/QueTotal))
  ((Complete=50*Percent/100)) # change first number for width (50)
  ((Left=50-Complete)) # change first number for width (50)
  BarComplete=$(printf "%${Complete}s" | tr " " "#")
  BarLeft=$(printf "%${Left}s" | tr " " "-")
  [[ "$QueTotal" == "$QueCurrent" ]] || printf "\r[%s%s] %s/%s " "$BarComplete" "$BarLeft" "$QueCurrent" "$QueTotal"
  [[ "$QueTotal" == "$QueCurrent" ]] && printf "\r[%b%s%b] %s/%s \n" "$c_teal" "$BarComplete" "$c_reset" "$QueCurrent" "$QueTotal"
}

### Version check & initiate self update
if [[ "$VERSION" != "$LatestRelease" ]] ; then 
  printf "New version available! %b%s%b ⇒ %b%s%b \n Change Notes: %s \n" "$c_yellow" "$VERSION" "$c_reset" "$c_green" "$LatestRelease" "$c_reset" "$LatestChanges"
  if [[ -z "$AutoUp" ]] ; then 
    read -r -p "Would you like to update? y/[n]: " SelfUpdate
    [[ "$SelfUpdate" =~ [yY] ]] && self_update
  fi
fi

### Set $1 to a variable for name filtering later.
SearchName="$1"
### Create array of excludes
IFS=',' read -r -a Excludes <<< "$Exclude" ; unset IFS

### Check if required binary exists in PATH or directory:
if [[ $(builtin type -P "regctl") ]]; then regbin="regctl" ;
elif [[ -f "$ScriptWorkDir/regctl" ]]; then regbin="$ScriptWorkDir/regctl" ;
else
  read -r -p "Required dependency 'regctl' missing, do you want it downloaded? y/[n] " GetDep
  if [[ "$GetDep" =~ [yY] ]] ; then
    ### Check arch:
    case "$(uname --machine)" in
      x86_64|amd64) architecture="amd64" ;;
      arm64|aarch64) architecture="arm64";;
      *) echo "Architecture not supported, exiting." ; exit 1;;
    esac
    RegUrl="https://github.com/regclient/regclient/releases/latest/download/regctl-linux-$architecture"
    if [[ $(builtin type -P curl) ]]; then curl -L $RegUrl > "$ScriptWorkDir/regctl" ; chmod +x "$ScriptWorkDir/regctl" ; regbin="$ScriptWorkDir/regctl" ;
    elif [[ $(builtin type -P wget) ]]; then wget $RegUrl -O "$ScriptWorkDir/regctl" ; chmod +x "$ScriptWorkDir/regctl" ; regbin="$ScriptWorkDir/regctl" ;
    else
      printf "%s\n" "curl/wget not available - get regctl manually from the repo link, quitting."
    fi
  else
    printf "%s\n" "Dependency missing, quitting."
    exit 1
  fi
fi
### final check if binary is correct
$regbin version &> /dev/null  || { printf "%s\n" "regctl is not working - try to remove it and re-download it, exiting."; exit 1; }

### Check docker compose binary:
if docker compose version &> /dev/null ; then DockerBin="docker compose" ;
elif docker-compose -v &> /dev/null; then DockerBin="docker-compose" ;
elif docker -v &> /dev/null; then
  printf "%s\n" "No docker compose binary available, using plain docker (Not recommended!)"
  printf "%s\n" "'docker run' will ONLY update images, not the container itself."
else
  printf "%s\n" "No docker binaries available, exiting."
  exit 1
fi

### Numbered List -function:
options() {
num=1
for i in "${GotUpdates[@]}"; do
  echo "$num) $i"
  ((num++))
done
}

### Listing typed exclusions:
if [[ -n ${Excludes[*]} ]] ; then
  printf "\n%bExcluding these names:%b\n" "$c_blue" "$c_reset"
  printf "%s\n" "${Excludes[@]}"
  printf "\n"
fi

# Variables for progress_bar function
DocCount=$(docker ps $Stopped --filter "name=$SearchName" --format '{{.Names}}' | wc -l)
RegCheckQue=0

### Check the image-hash of every running container VS the registry
for i in $(docker ps $Stopped --filter "name=$SearchName" --format '{{.Names}}') ; do
  ((RegCheckQue+=1))
  progress_bar "$RegCheckQue" "$DocCount"
  ### Looping every item over the list of excluded names and skipping:
  for e in "${Excludes[@]}" ; do [[ "$i" == "$e" ]] && continue 2 ; done 
  RepoUrl=$(docker inspect "$i" --format='{{.Config.Image}}')
  LocalHash=$(docker image inspect "$RepoUrl" --format '{{.RepoDigests}}')
  ### Checking for errors while setting the variable:
  if RegHash=$($regbin image digest --list "$RepoUrl" 2>&1) ; then
    if [[ "$LocalHash" = *"$RegHash"* ]] ; then 
      NoUpdates+=("$i") 
    else 
      if [[ -n "$DaysOld" ]] && ! datecheck ; then
        NoUpdates+=("+$i ${ImageAge}d") 
      else 
        GotUpdates+=("$i")
      fi
    fi
  else
    # Here the RegHash is the result of an error code.
    GotErrors+=("$i - ${RegHash}")
  fi
done

### Sort arrays alphabetically
IFS=$'\n' 
NoUpdates=($(sort <<<"${NoUpdates[*]}"))
GotUpdates=($(sort <<<"${GotUpdates[*]}"))
GotErrors=($(sort <<<"${GotErrors[*]}"))
unset IFS
### Define how many updates are available
UpdCount="${#GotUpdates[@]}"

### List what containers got updates or not
if [[ -n ${NoUpdates[*]} ]] ; then
  printf "\n%bContainers on latest version:%b\n" "$c_green" "$c_reset"
  printf "%s\n" "${NoUpdates[@]}"
fi
if [[ -n ${GotErrors[*]} ]] ; then
  printf "\n%bContainers with errors, wont get updated:%b\n" "$c_red" "$c_reset"
  printf "%s\n" "${GotErrors[@]}"
  printf "%binfo:%b 'unauthorized' often means not found in a public registry.%b\n" "$c_blue" "$c_reset"
fi
if [[ -n ${GotUpdates[*]} ]] ; then 
   printf "\n%bContainers with updates available:%b\n" "$c_yellow" "$c_reset"
   [[ -z "$AutoUp" ]] && options || printf "%s\n" "${GotUpdates[@]}"
   [[ -n "$Notify" ]] && { [[ $(type -t send_notification) == function ]] && send_notification "${GotUpdates[@]}" || printf "Could not source notification function.\n" ; }
fi

### Optionally get updates if there's any 
if [ -n "$GotUpdates" ] ; then
  if [ -z "$AutoUp" ] ; then
  printf "\n%bChoose what containers to update.%b\n" "$c_teal" "$c_reset"
  choosecontainers
  else
    SelectedUpdates=( "${GotUpdates[@]}" )
  fi
  if [ "$AutoUp" == "${AutoUp#[Nn]}" ] ; then
    NumberofUpdates="${#SelectedUpdates[@]}"
    CurrentQue=0
    for i in "${SelectedUpdates[@]}"
    do
      ((CurrentQue+=1))
      unset CompleteConfs
      ContPath=$(docker inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}')
      ContConfigFile=$(docker inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.project.config_files" }}')
      ContName=$(docker inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.service" }}')
      ContEnv=$(docker inspect "$i" --format '{{index .Config.Labels "com.docker.compose.project.environment_file" }}')
      ContImage=$(docker inspect "$i" --format='{{.Config.Image}}')
      ContUpdateLabel=$(docker inspect "$i" --format '{{ index .Config.Labels "mag37.dockcheck.update" }}')
      ContRestartStack=$(docker inspect "$i" --format '{{ index .Config.Labels "mag37.dockcheck.restart-stack" }}')
      ### Checking if compose-values are empty - hence started with docker run:
      if [ -z "$ContPath" ] ; then 
        if [ "$DRunUp" == "yes" ] ; then
          docker pull "$ContImage"
          printf "%s\n" "$i got a new image downloaded, rebuild manually with preferred 'docker run'-parameters"
        else
          printf "\n%b%s%b has no compose labels, probably started with docker run - %bskipping%b\n\n" "$c_yellow" "$i" "$c_reset" "$c_yellow" "$c_reset"
        fi
        continue 
      fi
      ### Checking if "com.docker.compose.project.config_files" returns the full path to the config file or just the file name
      if [[ $ContConfigFile = '/'* ]] ; then
        ComposeFile="$ContConfigFile"
      else
        ComposeFile="$ContPath/$ContConfigFile"
      fi
      ### cd to the compose-file directory to account for people who use relative volumes, eg - ${PWD}/data:data
      cd "$ContPath" || { echo "Path error - skipping $i" ; continue ; }
      printf "\n%bNow updating (%s/%s): %b%s%b\n" "$c_teal" "$CurrentQue" "$NumberofUpdates" "$c_blue" "$i" "$c_reset"
      ### Checking if Label Only -option is set, and if container got the label
      [[ "$OnlyLabel" == true ]] && { [[ "$ContUpdateLabel" != true ]] && { echo "No update label, skipping." ; continue ; } }
      docker pull "$ContImage"
      ### Reformat for multi-compose:
      IFS=',' read -r -a Confs <<< "$ComposeFile" ; unset IFS
      for conf in "${Confs[@]}"; do CompleteConfs+="-f $conf " ; done 
      ### Check if the container got an environment file set, use it if so:
      if [ -n "$ContEnv" ]; then 
        ### prepare env-files arguments
        ContEnvs=$(for env in ${ContEnv//,/ } ; do printf -- "--env-file %s " "$env"; done)
        ### Check if the whole stack should be restarted
        if [[ "$ContRestartStack" == true ]] || [[ "$ForceRestartStacks" == true ]] ; then 
          $DockerBin ${CompleteConfs[@]} stop ; $DockerBin ${CompleteConfs[@]} ${ContEnvs} up -d 
        else
          $DockerBin ${CompleteConfs[@]} ${ContEnvs} up -d "$ContName" # unquoted array to allow split - rework?
        fi
      else
        if [[ "$ContRestartStack" == true ]] || [[ "$ForceRestartStacks" == true ]] ; then 
          $DockerBin ${CompleteConfs[@]} stop ; $DockerBin ${CompleteConfs[@]} up -d
        else
          $DockerBin ${CompleteConfs[@]} up -d "$ContName"
        fi
      fi
    done
    printf "\n%bAll done!%b\n" "$c_green" "$c_reset"
    [[ -z "$AutoPrune" ]] && read -r -p "Would you like to prune dangling images? y/[n]: " AutoPrune
    [[ "$AutoPrune" =~ [yY] ]] && docker image prune -f 
  else
    printf "\nNo updates installed, exiting.\n"
  fi
else
  printf "\nNo updates available, exiting.\n"
fi

exit 0

