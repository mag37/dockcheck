#!/usr/bin/env bash
VERSION="v0.2.5.1"
### ChangeNotes: Added an -s option to include stopped contianers in the check.
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
  echo "Example:    dockcheck.sh -a -e nextcloud,heimdall"
  echo
  echo "Options:"
  echo "-h     Print this Help."
  echo "-y     Automatic updates, without interaction."
  echo "-n     No updates, only checking availability."
  echo "-e     Exclude containers, separated by comma."
  echo "-p     Auto-Prune dangling images after update."
  echo "-r     Allow updating images for docker run, wont update the container"
  echo "-a     Include stopped containers in the check. (Logic: docker ps -a)"
}

Stopped=""
while getopts "aynprhse:" options; do
  case "${options}" in
    y) UpdYes="yes" ;;
    n) UpdYes="no" ;;
    r) DrUp="yes" ;;
    p) PruneQ="yes" ;;
    e) Exclude=${OPTARG} ;;
    a) Stopped="-a" ;;
    h|*) Help ; exit 0 ;;
  esac
done
shift "$((OPTIND-1))"

self_update_git() {
  cd "$ScriptWorkDir" || { printf "Path error, skipping update.\n" ; return ; }
  [[ $(builtin type -P git) ]] || { printf "Git not installed, skipping update.\n" ; return ; }
  ScriptUpstream=$(git rev-parse --abbrev-ref --symbolic-full-name "@{upstream}") || { printf "Script not in git directory, choose a different method.\n" ; self_update_select ; return ; }
  git fetch
  [ -n "$(git diff --name-only "$ScriptUpstream" "$ScriptName")" ] && {
    printf "%s\n" "Pulling the latest version."
   # git checkout "$ScriptUpstream"
    git pull --force
    printf "%s\n" "--- starting over with the updated version ---"
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
self_update_select() {
  read -r -p "Choose update procedure (or do it manually) - git/curl/[no]: " SelfUpQ
  if [[ "$SelfUpQ" == "git" ]]; then self_update_git ;
  elif [[ "$SelfUpQ" == "curl" ]]; then self_update_curl ;
  else printf "Download it manually from the repo: %s \n\n" "$Github"
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

### Version check & initiate self update
#[[ "$VERSION" != "$LatestRelease" ]] && { printf "New version available! Local: %s - Latest: %s \n Change Notes: %s \n" "$VERSION" "$LatestRelease" "$LatestChanges" ; [[ -z "$UpdYes" ]] && self_update_select ; }

### Set $1 to a variable for name filtering later.
SearchName="$1"
### Create array of excludes
IFS=',' read -r -a Excludes <<< "$Exclude" ; unset IFS

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
  printf "\n\033[0;34mExcluding these names:\033[0m\n"
  printf "%s\n" "${Excludes[@]}"
  printf "\n"
fi
# Check repository
regcheck() {
  hub='hub.docker.com'
  namespace=''
  repository=''
  arg=$1
#echo $arg
  if [[ "$arg" == *":"* ]] ;then
    tag=`echo $arg| cut -f 2 -d ":"`
    arg=`echo $arg |cut -f 1 -d ":"`
  else
    tag='latest'
  fi
#echo $arg
  if [[ "$arg" == *"."* ]] ; then
    hub=`echo $arg| cut -f 1 -d "/"`
    arg=`echo $arg| cut -f 2- -d "/"`
  fi
#echo $arg
  if [[ "$arg" == *"/"* ]] ;then
    namespace=`echo $arg| cut -f 1 -d "/"`
    repository=`echo $arg |cut -f 2 -d "/"`
  else
    namespace='library'
    repository=$arg
  fi
#echo "$hub -> $namespace -> $repository -> $tag"
res=`curl -L -s -w "%{http_code}" https://$hub/v2/namespaces/$namespace/repositories/$repository/tags/$tag`
http_code="${res:${#res}-3}"
if [ ${#res} -eq 3 ] || || [ "$http_code" -ne "200" ] ;then
  body=""
  return 1
else
  body="${res:0:${#res}-3}"
fi
#echo $http_code
#echo $res
echo $body|jq -r .digest
}

### Check the image-hash of every running container VS the registry
for i in $(docker ps $Stopped --filter "name=$SearchName" --format '{{.Names}}') ; do
  ### Looping every item over the list of excluded names and skipping:
  for e in "${Excludes[@]}" ; do [[ "$i" == "$e" ]] && continue 2 ; done
  printf ". "
  RepoUrl=$(docker inspect "$i" --format='{{.Config.Image}}')
  LocalHash=$(docker image inspect "$RepoUrl" --format '{{.RepoDigests}}'|cut -f 2 -d "@")
  ### Checking for errors while setting the variable:
#echo "Repo url: $RepoUrl Hash: $LocalHash"
#regcheck $RepoUrl; continue
  if RegHash=$(regcheck $RepoUrl ) ; then
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
      printf "\n\033[0;36mNow updating (%s/%s): \033[0;34m%s\033[0m\n" "$CurrentQue" "$NumberofUpdates" "$i"
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
