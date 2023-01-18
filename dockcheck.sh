#!/bin/bash

### Check arch:
case "`uname --machine`" in
  x86_64|amd64)
    architecture="amd64";;
  arm64|aarch64)
    architecture="arm64";;
  *) echo "Architecture not supported, exiting." ; exit ;;
esac

### Check if required application exists in PATH or directory:
if [[ $(builtin type -P "regctl") ]]; then 
  regbin="regctl"
elif [[ -f "./regctl" ]]; then
  regbin="./regctl"
else
  printf "Required dependency 'regctl' missing, do you want it downloaded? y/[n]\n"
  read GetDep
  if [ "$GetDep" != "${GetDep#[Yy]}" ]; then
    curl -L https://github.com/regclient/regclient/releases/latest/download/regctl-linux-$architecture >./regctl
    chmod 755 ./regctl
    regbin="./regctl"
  else
    printf "Dependency missing, quitting.\n"
    exit
  fi
fi

### Check the image-hash of every running container VS the registry
for i in $(docker ps --format '{{.Names}}') 
do
  RepoUrl=$(docker inspect $i --format='{{.Config.Image}}')
  LocalHash=$(docker image inspect $RepoUrl --format '{{.RepoDigests}}' | sed -e 's/.*sha256/sha256/' -e 's/\]$//')
  RegHash=$(./regctl image digest --list $RepoUrl)
  if [[ "$LocalHash" != "$RegHash" ]] ; then
    GotUpdates+=("$i")
  else
    NoUpdates+=("$i")
  fi
done

### List what containers got updates or not
if [ ! -z $GotUpdates ] ; then
  printf "\n\033[31;1mContainers with updates available:\033[0m\n"
  printf "%s\n" "${GotUpdates[@]}"
fi
if [ ! -z $NoUpdates ] ; then
  printf "\n\033[32;1mContainers on latest version:\033[0m\n"
  printf "%s\n" "${NoUpdates[@]}"
fi

### Optionally get updates 
printf "\n\033[36;1mDo you want to update? y/[n]\033[0m\n"
read UpdYes
if [ "$UpdYes" != "${UpdYes#[Yy]}" ] ; then
  for i in "${GotUpdates[@]}"
  do 
    # Check what compose-type is installed:
    if docker compose &> /dev/null ; then DockerBin="docker compose" ; else DockerBin="docker-compose" ; fi
    ContPath=$(docker inspect $i --format '{{ index .Config.Labels "com.docker.compose.project.working_dir"}}')
    $DockerBin -f "$ContPath/docker-compose.yml" pull 
    $DockerBin -f "$ContPath/docker-compose.yml" up -d
  done
else
  printf "\nNo updates installed, exiting.\n"
fi
