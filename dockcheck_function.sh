### Requires the regctl binary, either in PATH or as an alias
### Get it here: https://github.com/regclient/regclient/releases

alias="/path/to/regctl"
dockcheck () {
  if [[ -z "$1" ]]; then 
    echo "No container name given, here's the list of currently running containers:" 
    docker ps --format '{{.Names}}'
  else
    RepoUrl=$(docker inspect $1 --format='{{.Config.Image}}')
    LocalHash=$(docker image inspect $RepoUrl --format '{{.RepoDigests}}' | sed -e 's/.*sha256/sha256/' -e 's/\]$//')
    RegHash=$(regctl image digest --list $RepoUrl)
    if [[ "$LocalHash" != "$RegHash" ]] ; then printf "Updates available.\n" ; else printf "Already latest.\n" ; fi
  fi
}
