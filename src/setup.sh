#!/bin/bash

#dev-begin
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/lib.sh"
#dev-end

#include lib.sh

#=======================================
# MAIN SCRIPT
#=======================================


setup_update_repo
check_git
check_docker
check_docker_compose
check_jq
check_dotenv
setup_packages
setup_node
setup_users
setup_dir_structure

whiptail --title "Witamy" --yesno "Ten skrypt zainstaluje Nightscout na bieżącym serwerze mikr.us\n\nJeśli na tym serwerze istnieje już instalacja Nightscout - ten skrypt spróbuje ją przekonfigurować" --yes-button "$uni_start" --no-button "$uni_exit" 12 70 
exit_on_no_cancel

prompt_mikrus_host
prompt_mikrus_apikey

whiptail --msgbox "Gotowe!" 5 12
