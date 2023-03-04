#!/usr/bin/env bash
VERSION="v0.2.31"
Github="https://github.com/mag37/dockcheck"
RawUrl="https://raw.githubusercontent.com/mag37/dockcheck/main/dockcheck.sh"

### Check if there's a new release of the script:
LatestRelease="$(curl -s -r 0-50 $RawUrl | sed -n "/VERSION/s/VERSION=//p" | tr -d '"')"

### Variables for self updating
ScriptBranch="main"
ScriptArgs=( "$@" )
ScriptPath="$(readlink -f "$0")"
ScriptName="$(basename "$ScriptPath")"
ScriptWorkDir="$(dirname "$ScriptPath")"

### Help Function:
Help() {
  echo "Syntax:     dockcheck.sh [OPTION] [part of name to filter]" 
  echo "Example:    dockcheck.sh -a -e nextcloud,heimdall"
  echo
  echo "Options:"
  echo "-h     Print this Help."
  echo "-a|y   Automatic updates, without interaction."
  echo "-n     No updates, only checking availability."
  echo "-e     Exclude containers, separated by comma."
  echo "-p     Auto-Prune dangling images after update."
  echo "-r     Allow updating images for docker run, wont update the container"
}

while getopts "aynprhe:" options; do
  case "${options}" in
    a|y) UpdYes="yes" ;;
    n) UpdYes="no" ;;
    r) DrUp="yes" ;;
    p) PruneQ="yes" ;;
    e) Exclude=${OPTARG} ;;
    h|*) Help ; exit 0 ;;
  esac
done
shift "$((OPTIND-1))"

self_update_git() {
  cd "$ScriptWorkDir" || { printf "Path error, skipping update.\n" ; return ; }
  [[ $(builtin type -P git) ]] || { printf "Git not installed, skipping update.\n" ; return ; }
  git fetch
  [ -n "$(git diff --name-only "origin/$ScriptBranch" "$ScriptName")" ] && {
    printf "%s\n" "Pulling the latest version."
    git pull --force
    git checkout "$ScriptBranch"
    git pull --force
    echo "Running the new version..."
    cd - || { printf "Path error.\n" ; return ; }
    exec "$ScriptPath" "${ScriptArgs[@]}" # run the new script with old arguments
    exit 1 # exit the old instance
  }
  echo "Local is already latest."
}
self_update_curl() {
  cp "$ScriptPath" "$ScriptPath".bak
  if [[ $(builtin type -P curl) ]]; then 
    curl -L $RawUrl > "$ScriptPath" ; chmod +x "$ScriptPath"  
    printf "%s\n" "--- starting over with the updated version ---"
    exec "$ScriptPath" "${ScriptArgs[@]}" # run the new script with old arguments
    exit 1 # exit the old instance
  else
    printf "curl not available - download the update manually: %s \n" "$RawUrl"
  fi
}
if [ "$VERSION" != "$LatestRelease" ] ; then 
  printf "New version available! Local: %s - Latest: %s \n" "$VERSION" "$LatestRelease"
  read -r -p "Choose update procedure (or do it manually) - git/curl/[no]: " SelfUpQ
  if [[ "$SelfUpQ" == "git" ]]; then self_update_git ;
  elif [[ "$SelfUpQ" == "curl" ]]; then self_update_curl ; 
  else printf "Download it manually from the repo: %s \n\n" "$Github"
  fi
fi

### Set $1 to a variable for name filtering later.
SearchName="$1"
### Create array of excludes
IFS=',' read -r -a Excludes <<< "$Exclude" ; unset IFS

### Check if required binary exists in PATH or directory:
if [[ $(builtin type -P "regctl") ]]; then regbin="regctl" ;
elif [[ -f "./regctl" ]]; then regbin="./regctl" ;
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
    if [[ $(builtin type -P curl) ]]; then curl -L $RegUrl > ./regctl ; chmod +x ./regctl ; regbin="./regctl" ;
    elif [[ $(builtin type -P wget) ]]; then wget $RegUrl -O ./regctl ; chmod +x ./regctl ; regbin="./regctl" ;
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
if docker compose version &> /dev/null ; then 
  DockerBin="docker compose"
elif docker-compose -v &> /dev/null; then
  DockerBin="docker-compose"
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

### Check the image-hash of every running container VS the registry
for i in $(docker ps --filter "name=$SearchName" --format '{{.Names}}') ; do
  [[ " ${Excludes[*]} " =~ ${i} ]] && continue; # Skip if the container is excluded
  printf ". "
  RepoUrl=$(docker inspect "$i" --format='{{.Config.Image}}')
  LocalHash=$(docker image inspect "$RepoUrl" --format '{{.RepoDigests}}')
  ### Checking for errors while setting the variable:
  if RegHash=$($regbin image digest --list "$RepoUrl" 2>/dev/null) ; then
    if [[ "$LocalHash" = *"$RegHash"* ]] ; then NoUpdates+=("$i"); else GotUpdates+=("$i"); fi
  else
    GotErrors+=("$i")
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
  printf "\n\033[0;32mContainers on latest version:\033[0m\n"
  printf "%s\n" "${NoUpdates[@]}"
fi
if [[ -n ${GotErrors[*]} ]] ; then
  printf "\n\033[0;31mContainers with errors, wont get updated:\033[0m\n"
  printf "%s\n" "${GotErrors[@]}"
fi
if [[ -n ${GotUpdates[*]} ]] ; then 
   printf "\n\033[0;33mContainers with updates available:\033[0m\n"
   [[ -z "$UpdYes" ]] && options || printf "%s\n" "${GotUpdates[@]}"
fi

### Optionally get updates if there's any 
if [ -n "$GotUpdates" ] ; then
  if [ -z "$UpdYes" ] ; then
  printf "\n\033[0;36mChoose what containers to update.\033[0m\n"
  choosecontainers
  else
    SelectedUpdates=( "${GotUpdates[@]}" )
  fi
  if [ "$UpdYes" == "${UpdYes#[Nn]}" ] ; then
    for i in "${SelectedUpdates[@]}"
    do
      unset CompleteConfs
      ContPath=$(docker inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}')
      ContConfigFile=$(docker inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.project.config_files" }}')
      ContName=$(docker inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.service" }}')
      ContEnv=$(docker inspect "$i" --format '{{index .Config.Labels "com.docker.compose.project.environment_file" }}')
      ContImage=$(docker inspect "$i" --format='{{.Config.Image}}')
      ### Checking if compose-values are empty - hence started with docker run:
      if [ -z "$ContPath" ] ; then 
        if [ "$DrUp" == "yes" ] ; then
          docker pull "$ContImage"
          printf "%s\n" "$i got a new image downloaded, rebuild manually with preferred 'docker run'-parameters"
        else
          printf "\n\033[33;1m%s\033[0m has no compose labels, probably started with docker run - \033[33;1mskipping\033[0m\n\n" "$i"
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
      docker pull "$ContImage"
      ### Reformat for multi-compose:
      IFS=',' read -r -a Confs <<< "$ComposeFile" ; unset IFS
      for conf in "${Confs[@]}"; do CompleteConfs+="-f $conf " ; done 
      
      ### Check if the container got an environment file set, use it if so:
      if [ -n "$ContEnv" ]; then 
        $DockerBin ${CompleteConfs[@]} --env-file "$ContEnv" up -d "$ContName" # unquoted array to allow split - rework?
      else
        $DockerBin ${CompleteConfs[@]} up -d "$ContName" # unquoted array to allow split - rework?
      fi
    done
    printf "\033[0;32mAll done!\033[0m\n"
    [[ -z "$PruneQ" ]] && read -r -p "Would you like to prune dangling images? y/[n]: " PruneQ
    [[ "$PruneQ" =~ [yY] ]] && docker image prune -f 
  else
    printf "\nNo updates installed, exiting.\n"
  fi
else
  printf "\nNo updates available, exiting.\n"
fi

exit 0
