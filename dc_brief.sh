#!/usr/bin/env bash

### If not in PATH, set full path. Else just "regctl"
regbin="regctl"
### options to allow exclude:
while getopts "e:" options; do
  case "${options}" in
    e) Exclude=${OPTARG} ;;
    *) exit 0 ;;
  esac
done
shift "$((OPTIND-1))"
### Create array of excludes
IFS=',' read -r -a Excludes <<< "$Exclude" ; unset IFS

SearchName="$1"

for i in $(docker ps --filter "name=$SearchName" --format '{{.Names}}') ; do
  for e in "${Excludes[@]}" ; do [[ "$i" == "$e" ]] && continue 2 ; done
  # [[ " ${Excludes[*]} " =~ ${i} ]] && continue; # Skip if the container is excluded
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
   printf "%s\n" "${GotUpdates[@]}"
fi
printf "\n\n"
