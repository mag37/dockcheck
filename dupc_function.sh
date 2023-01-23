#!/bin/bash

### Requires the regctl binary.
### Get it here: https://github.com/regclient/regclient/releases

### Preferably placed in .bashrc or similar

### Set the full path to the binary or just regctl if in PATH:
regctl="/home/gw-tdc/dockers/regctl"

dupc () {
  if [[ "$@" == "help" ]]; then 
    echo "No container name given, here's the list of currently running containers:" 
    docker ps --format '{{.Names}}'
  else
    for i in $(docker ps --filter "name=$@" --format '{{.Names}}')
    do
      RepoUrl=$(docker inspect $i --format='{{.Config.Image}}')
      LocalHash=$(docker image inspect $RepoUrl --format '{{.RepoDigests}}')
      RegHash=$($regctl image digest --list $RepoUrl 2>/dev/null)
      if [ $? -eq 0 ] ; then
        if [[ "$LocalHash" = *"$RegHash"* ]] ; then printf "$i is already latest.\n" ; else printf "$i got updates.\n" ; fi
      else
        printf "$i got errors, no check possible.\n"
      fi 
    done
  fi
}
dupc $1
