#!/usr/bin/env bash
SearchName="$1"
for i in $(podman ps --filter "name=$SearchName" --format '{{.Names}}') ; do
  echo "------------ $i ------------"
  ContLabels=$(podman inspect "$i" --format '{{json .Config.Labels}}')
  ContImage=$(podman inspect "$i" --format='{{.ImageName}}')
  ContPath=$(jq -r '."com.docker.compose.project.working_dir"' <<< "$ContLabels")
  [ "$ContPath" == "null" ] && ContPath=""
  ContConfigFile=$(jq -r '."com.docker.compose.project.config_files"' <<< "$ContLabels")
  [ "$ContConfigFile" == "null" ] && ContConfigFile=""
  ContName=$(jq -r '."com.docker.compose.service"' <<< "$ContLabels")
  [ "$ContName" == "null" ] && ContName=""
  ContEnv=$(jq -r '."com.docker.compose.project.environment_file"' <<< "$ContLabels")
  [ "$ContEnv" == "null" ] && ContEnv=""
  ContUpdateLabel=$(jq -r '."sudo-kraken.podcheck.update"' <<< "$ContLabels")
  [ "$ContUpdateLabel" == "null" ] && ContUpdateLabel=""
  ContRestartStack=$(jq -r '."sudo-kraken.podcheck.restart-stack"' <<< "$ContLabels")
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
  podman inspect  -f '{{ range .Mounts }}{{ .Source }}:{{ .Destination }}{{ printf "\n" }}{{ end }}' "$i"
  echo
done
