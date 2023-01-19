#!/bin/bash

### Requires the regctl binary, either in PATH or as an alias
### Get it here: https://github.com/regclient/regclient/releases

### Preferably placed in .bashrc or similar

### if regctl is not in PATH, set the alias:
alias regctl="/path/to/regctl"


dupc () {
  if [[ -z "$1" ]]; then 
    echo "No container name given, here's the list of currently running containers:" 
    docker ps --format '{{.Names}}'
  else
    for i in $(docker ps --filter "name=$1" --format '{{.Names}}')
    do
      RepoUrl=$(docker inspect $i --format='{{.Config.Image}}')
      LocalHash=$(docker image inspect $RepoUrl --format '{{.RepoDigests}}' | sed -e 's/.*sha256/sha256/' -e 's/\]$//')
      RegHash=$(regctl image digest --list $RepoUrl)
      if [[ "$LocalHash" != "$RegHash" ]] ; then printf "Updates available for $i.\n" ; else printf "$i is already latest.\n" ; fi
    done
  fi
}
