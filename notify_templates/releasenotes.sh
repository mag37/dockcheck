### Snippet to use together with notify.sh
# 
# Requires a space-separated list-file of container-name and release-note-url, modify the example file "urls.list"
# Copy urls.list and releasenotes.sh to the same directory as dockcheck.sh.
#
# Add the next line (uncommented) to any notification script you're using, after the "UpdToString"-variable setup
# [ -s "$ScriptWorkDir"/releasenotes.sh ] && { source "$ScriptWorkDir"/releasenotes.sh ; UpdToString=$( releasenotes ) ; }

releasenotes() {
    for update in ${Updates[@]}; do
        found=false
        while read -r container url; do
            [[ $update == $container ]] && printf "%s  ->  %s\n" "$update" "$url" && found=true
        done < "$ScriptWorkDir"/urls.list
        [[ $found == false ]] && printf "%s\n" "$update"
    done
}
