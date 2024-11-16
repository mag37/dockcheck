#!/usr/bin/env bash
SearchName="$1"
for i in $(podman ps --filter "name=$SearchName" --format '{{.Names}}') ; do
  echo "------------ $i ------------"
  ContPath=$(podman inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}')
  if [ -z "$ContPath" ]; then
    echo "$i has no compose labels - skipping"
    continue
  fi
  ContConfigFile=$(podman inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.project.config_files" }}')
  ContName=$(podman inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.service" }}')
  ContEnv=$(podman inspect "$i" --format '{{ index .Config.Labels "com.docker.compose.project.environment_file" }}')
  ContImage=$(podman inspect "$i" --format='{{.ImageName}}')

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
  podman inspect  -f '{{ range .Mounts }}{{ .Source }}:{{ .Destination }}{{ printf "\n" }}{{ end }}' "$i"
  echo
done
