#!/usr/bin/env bash
SearchName="$1"
for i in $(docker ps --filter "name=$SearchName" --format '{{.Names}}') ; do
  echo "------------ $i ------------"
  ContLabels=$(docker inspect "$i" --format '{{json .Config.Labels}}')
  ContImage=$(docker inspect "$i" --format='{{.Config.Image}}')
  ContPath=$(jq -r '."com.docker.compose.project.working_dir"' <<< "$ContLabels")
  [ "$ContPath" == "null" ] && ContPath=""
  [ -z "$ContPath" ] && { "$i has no compose labels - skipping" ; continue ; }
  ContConfigFile=$(jq -r '."com.docker.compose.project.config_files"' <<< "$ContLabels")
  [ "$ContConfigFile" == "null" ] && ContConfigFile=""
  ContName=$(jq -r '."com.docker.compose.service"' <<< "$ContLabels")
  [ "$ContName" == "null" ] && ContName=""
  ContEnv=$(jq -r '."com.docker.compose.project.environment_file"' <<< "$ContLabels")
  [ "$ContEnv" == "null" ] && ContEnv=""
  ContUpdateLabel=$(jq -r '."mag37.dockcheck.update"' <<< "$ContLabels")
  [ "$ContUpdateLabel" == "null" ] && ContUpdateLabel=""
  ContRestartStack=$(jq -r '."mag37.dockcheck.restart-stack"' <<< "$ContLabels")
  [ "$ContRestartStack" == "null" ] && ContRestartStack=""

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
  echo -e "Update label:\t$ContUpdateLabel"
  echo -e "Restart Stack label:\t$ContRestartStack"
  echo
  echo "Mounts:"
  docker inspect  -f '{{ range .Mounts }}{{ .Source }}:{{ .Destination }}{{ printf "\n" }}{{ end }}' "$i"
  echo
done
