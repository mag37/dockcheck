prometheus_exporter() {
  checkedImages=$(($1 + $2 + $3))
  checkTimestamp=$(date +%s)
  
  promFileContent=()
  promFileContent+=("# HELP dockcheck_images_analyzed Docker images that have been analyzed")
  promFileContent+=("# TYPE dockcheck_images_analyzed gauge")
  promFileContent+=("dockcheck_images_analyzed $checkedImages")
  
  promFileContent+=("# HELP dockcheck_images_outdated Docker images that are outdated")
  promFileContent+=("# TYPE dockcheck_images_outdated gauge")
  promFileContent+=("dockcheck_images_outdated ${#GotUpdates[@]}")

  promFileContent+=("# HELP dockcheck_images_latest Docker images that are outdated")
  promFileContent+=("# TYPE dockcheck_images_latest gauge")
  promFileContent+=("dockcheck_images_latest ${#NoUpdates[@]}")
  
  promFileContent+=("# HELP dockcheck_images_error Docker images with analysis errors")
  promFileContent+=("# TYPE dockcheck_images_error gauge")
  promFileContent+=("dockcheck_images_error ${#GotErrors[@]}")
  
  promFileContent+=("# HELP dockcheck_images_analyze_timestamp_seconds Last dockercheck run time")
  promFileContent+=("# TYPE dockcheck_images_analyze_timestamp_seconds gauge")
  promFileContent+=("dockcheck_images_analyze_timestamp_seconds $checkTimestamp")
  
  printf "%s\n" "${promFileContent[@]}" > "$CollectorTextFileDirectory/dockcheck_info.prom\$\$"
  mv -f "$CollectorTextFileDirectory/dockcheck_info.prom\$\$" "$CollectorTextFileDirectory/dockcheck_info.prom"
}
