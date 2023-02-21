### If not in PATH, set full path. Else just "regctl"
regbin="regctl"
SearchName="$1"

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
