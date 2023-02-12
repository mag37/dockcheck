#!/bin/bash
VERSION="v0.1.7"
Github="https://github.com/mag37/dockcheck"

### Check if there's a new release of the script:
LatestRelease="$(curl -s -r 0-30 https://raw.githubusercontent.com/mag37/dockcheck/main/dockcheck.sh | sed -n "/VERSION/s/VERSION=//p" | tr -d '"')"
[ "$VERSION" != "$LatestRelease" ] && printf "New version available! Latest: %s - Local: %s \nGrab it here: %s \n\n" "$LatestRelease" "$VERSION" "$Github"

### Help Function:
Help() {
  echo "Syntax:     dockcheck.sh [OPTION] [part of name to filter]" 
  echo "Example:    dockcheck.sh -a ng"
  echo
  echo "Options:"
  echo "-h     Print this Help."
  echo "-a|y   Automatic updates, without interaction."
  echo "-n     No updates, only checking availability."
  echo "-r     Allow updating images for docker run, wont update the container"
}

while getopts "aynrh" options; do
  case "${options}" in
    a|y) UpdYes="yes" ;;
    n) UpdYes="no" ;;
    r) DrUp="yes" ;;
    h|*) Help ; exit 0 ;;
  esac
done
shift "$((OPTIND-1))"

### Set $1 to a variable for name filtering later.
SearchName="$1"

### Check if required binary exists in PATH or directory:
if [[ $(builtin type -P "regctl") ]]; then 
  regbin="regctl"
elif [[ -f "./regctl" ]]; then
  regbin="./regctl"
else
  printf "Required dependency 'regctl' missing, do you want it downloaded? y/[n] "
  read -r GetDep
  if [ "$GetDep" != "${GetDep#[Yy]}" ]; then
    ### Check arch:
    case "$(uname --machine)" in
      x86_64|amd64) architecture="amd64" ;;
      arm64|aarch64) architecture="arm64";;
      *) echo "Architecture not supported, exiting." ; exit ;;
    esac
    curl -L https://github.com/regclient/regclient/releases/latest/download/regctl-linux-$architecture >./regctl
    chmod 755 ./regctl
    regbin="./regctl"
  else
    printf "%s\n" "Dependency missing, quitting."
    exit
  fi
fi
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
  exit
fi

### Numbered List -function:
options() {
num=0
for i in "${NumberedUpdates[@]}"; do
  echo "$num) $i"
  ((num++))
done
}

### Choose from list -function:
choosecontainers() {
  while [[ "$ChoiceClean" =~ [A-Za-z] || -z "$ChoiceClean" ]]; do
    read -r -p "Enter number(s) separated by comma, [q] to quit: " Choice
    if [[ "$Choice" =~ [qQnN] ]] ; then 
      exit 0
    elif [ "$Choice" == "0" ] ; then 
      SelectedUpdates=( "${NumberedUpdates[@]:1}" )
      ChoiceClean=${Choice//[,.:;]/ }
      # ChoiceClean=$(echo "$Choice" |sed 's/[,.:;]/ /g')
    else
      ChoiceClean=${Choice//[,.:;]/ }
      # ChoiceClean=$(echo "$Choice" |sed 's/[,.:;]/ /g')
      for s in $ChoiceClean; do
        SelectedUpdates+=( "${NumberedUpdates[$s]}" )
      done
    fi
  done
  printf "\nUpdating containers:\n"
  printf "%s\n" "${SelectedUpdates[@]}"
  printf "\n"
}

### Check the image-hash of every running container VS the registry
for i in $(docker ps --filter "name=$SearchName" --format '{{.Names}}') ; do
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
### Create new Array to use for the numbered list:
NumberedUpdates=(ALL "${GotUpdates[@]}")

### List what containers got updates or not
if [[ -n ${NoUpdates[*]} ]] ; then
  printf "\n\033[32;1mContainers on latest version:\033[0m\n"
  printf "%s\n" "${NoUpdates[@]}"
fi
if [[ -n ${GotErrors[*]} ]] ; then
  printf "\n\033[33;1mContainers with errors, wont get updated:\033[0m\n"
  printf "%s\n" "${GotErrors[@]}"
fi
if [[ -n ${GotUpdates[*]} ]] ; then 
   printf "\n\033[31;1mContainers with updates available:\033[0m\n"
   [[ -z "$UpdYes" ]] && options || printf "%s\n" "${GotUpdates[@]}"
fi

### Optionally get updates if there's any 
if [ -n "$GotUpdates" ] ; then
  if [ -z "$UpdYes" ] ; then
  printf "\n\033[36;1mChoose what containers to update.\033[0m\n"
  choosecontainers
  else
    SelectedUpdates=( "${GotUpdates[@]}" )
  fi
  if [ "$UpdYes" == "${UpdYes#[Nn]}" ] ; then
    for i in "${SelectedUpdates[@]}"
    do 
      ContPath=$(docker inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}')
      ContConfigFile=$(docker inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.project.config_files" }}')
      ContName=$(docker inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.service" }}')
      ### Checking if compose-values are empty - hence started with docker run:
      if [ -z "$ContPath" ] ; then 
        if [ "$DrUp" == "yes" ] ; then
          ContImage=$(docker inspect "$i" --format='{{.Config.Image}}')
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
      cd "$(dirname "${ComposeFile}")" || { echo "Path error - skipping $i" ; continue ; }
      $DockerBin -f "$ComposeFile" pull "$ContName"
      $DockerBin -f "$ComposeFile" up -d "$ContName"
    done
  else
    printf "\nNo updates installed, exiting.\n"
  fi
else
  printf "\nNo updates available, exiting.\n"
fi

exit 0
