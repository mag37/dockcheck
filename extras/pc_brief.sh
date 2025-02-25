#!/usr/bin/env bash
# pc_brief.sh - Provides a brief diagnostic summary of Podman Compose containers.
# Usage: pc_brief.sh <name-filter>

set -euo pipefail

# Check if a name filter argument was provided
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <name-filter>"
    exit 1
fi

SearchName="$1"

# Use a while-read loop to correctly handle container names with spaces
podman ps --filter "name=$SearchName" --format '{{.Names}}' | while IFS= read -r container; do
  echo "------------ $container ------------"
  
  # Retrieve container labels and image name
  ContLabels=$(podman inspect "$container" --format '{{json .Config.Labels}}')
  ContImage=$(podman inspect "$container" --format '{{.ImageName}}')
  
  # Extract Docker Compose-related labels via jq; default to empty if null
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
  
  # Determine the full path to the compose file(s)
  if [[ $ContConfigFile = /* ]]; then
    ComposeFile="$ContConfigFile"
  else
    ComposeFile="$ContPath/$ContConfigFile"
  fi
  
  # Output a concise summary of container configuration
  echo -e "Service name:\t\t$ContName"
  echo -e "Project working dir:\t$ContPath"
  echo -e "Compose files:\t\t$ComposeFile"
  echo -e "Environment files:\t$ContEnv"
  echo -e "Container image:\t$ContImage"
  echo -e "Update label:\t\t$ContUpdateLabel"
  echo -e "Restart Stack label:\t$ContRestartStack"
  echo
  echo "Mounts:"
  podman inspect -f '{{ range .Mounts }}{{ .Source }}:{{ .Destination }}{{ "\n" }}{{ end }}' "$container"
  echo
done
