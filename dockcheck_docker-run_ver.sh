#!/bin/bash
### VERSION v.0.1.1

### DOCKER RUN - VERSION

### WARNING WONT REBUILD CONTAINERS - ONLY GRAB NEW IMAGES
### If running docker compose, use the main version. (recommended!)

### Help Function:
Help() {
  echo "Syntax:     dockcheck.sh [OPTION] [part of name to filter]" 
  echo "Example:    dockcheck.sh -a ng"
  echo
  echo "Options:"
  echo "-h     Print this Help."
  echo "-a|y   Automatic updates, without interaction."
  echo "-n     No updates, only checking availability."
}

while getopts "aynh" options; do
  case "${options}" in
    a|y) UpdYes="yes" ;;
    n) UpdYes="no" ;;
    h|*) Help ; exit 0 ;;
  esac
done
shift "$((OPTIND-1))"

### Set $1 to a variable for later
SearchName="$1"

### Check if required binary exists in PATH or directory:
if [[ $(builtin type -P "regctl") ]]; then 
  regbin="regctl"
elif [[ -f "./regctl" ]]; then
  regbin="./regctl"
else
  printf "Required dependency 'regctl' missing, do you want it downloaded? y/[n] "
  read GetDep
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
    printf "What containers do you like to update? \n"
    # options
    read -p 'Enter number(s) separated by comma (eg. 1,3,4): ' Choice
    if [ "$Choice" == "0" ] ; then 
      SelectedUpdates=( ${NumberedUpdates[@]:1} )
      ChoiceClean=$(echo $Choice|sed 's/[,.:;]/ /g')
    else
      ChoiceClean=$(echo $Choice|sed 's/[,.:;]/ /g')
      for s in $ChoiceClean; do
        SelectedUpdates+=( ${NumberedUpdates[$s]} )
      done
    fi
  done
  printf "\nYou've SelectedUpdates:\n"
  printf "%s\n" "${SelectedUpdates[@]}"
}

### Check the image-hash of every running container VS the registry
for i in $(docker ps --filter "name=$SearchName" --format '{{.Names}}') ; do
  printf ". "
  RepoUrl=$(docker inspect "$i" --format='{{.Config.Image}}')
  LocalHash=$(docker image inspect "$RepoUrl" --format '{{.RepoDigests}}')
  RegHash=$($regbin image digest --list "$RepoUrl" 2>/dev/null)
  # Check if regtcl produces errors - add to GotErrors if so.
  if [ $? -eq 0 ] ; then
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
if [ -n "$NoUpdates" ] ; then
  printf "\n\033[32;1mContainers on latest version:\033[0m\n"
  printf "%s\n" "${NoUpdates[@]}"
fi
if [ -n "$GotErrors" ] ; then
  printf "\n\033[33;1mContainers with errors, wont get updated:\033[0m\n"
  printf "%s\n" "${GotErrors[@]}"
fi
if [ -n "$GotUpdates" ] ; then 
   printf "\n\033[31;1mContainers with updates available:\033[0m\n"
   [ -z "$UpdYes" ] && options || printf "%s\n" "${GotUpdates[@]}"
fi

### Optionally get updates if there's any 
if [ -n "$GotUpdates" ] ; then
  if [ -z "$UpdYes" ] ; then
  printf "\n\033[36;1mDo you want to update? y/[n]\033[0m "
  read UpdYes
  [ "$UpdYes" != "${UpdYes#[Yy]}" ] && choosecontainers
  else
    SelectedUpdates=( "${GotUpdates[@]}" )
  fi
  if [ "$UpdYes" != "${UpdYes#[Yy]}" ] ; then
    for i in "${SelectedUpdates[@]}"; do 
      ContImage=$(docker inspect "$i" --format='{{.Config.Image}}')
      docker pull $ContImage
      printf "%s\n" "$i got a new image downloaded, rebuild manually with preferred 'docker run'-parameters"
    done
  else
    printf "\nNo updates installed, exiting.\n"
  fi
else
  printf "\nNo updates available, exiting.\n"
fi

exit 0
