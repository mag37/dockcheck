#!/usr/bin/env bash
SearchName="$1"
for i in $(docker ps --filter "name=$SearchName" --format '{{.Names}}') ; do
  echo "------------ $i ------------"
  ContPath=$(docker inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}')
  [ -z "$ContPath" ] && { "$i has no compose labels - skipping" ; continue ; }
  ContConfigFile=$(docker inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.project.config_files" }}')
  ContName=$(docker inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.service" }}')
  ContEnv=$(docker inspect "$i" --format '{{index .Config.Labels "com.docker.compose.project.environment_file" }}')
  ContImage=$(docker inspect "$i" --format='{{.Config.Image}}')

  if [[ $ContConfigFile = '/'* ]] ; then
    ComposeFile="$ContConfigFile"
  else
    ComposeFile="$ContPath/$ContConfigFile"
  fi

  echo -e "Service name:\t\t$ContName"
  echo -e "Project working dir:\t$ContPath"
  echo -e "Compose files:\t\t$ComposeFile"
  echo -e "Environment files:\t$ContEnv"
  echo -e "Container image:\t$ContImage"
  echo
  echo "Mounts:"
  docker inspect  -f '{{ range .Mounts }}{{ .Source }}:{{ .Destination }}{{ printf "\n" }}{{ end }}' "$i"
  echo
done
