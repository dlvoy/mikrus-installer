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

#setup_update_repo
check_git
check_docker
check_docker_compose
check_jq
setup_packages
setup_node
check_dotenv
setup_users
setup_dir_structure
download_conf

source_admin

prompt_welcome
prompt_mikrus_host
prompt_mikrus_apikey
prompt_api_secret

STATUS_NS=$(get_docker_status "ns-server")

whiptail --msgbox "Gotowe! \n $STATUS_NS\n" 8 20
if [ "$STATUS_NS" = "missing" ]; then
    ohai "Instalowanie Nightscout..."
    processgauge install_containers install_containers_progress "Instalowanie usług" "Proszę czekać, trwa instalowanie usług..."
else
    msgok "Wykryto uruchomiony Nightscout"
    processgauge uninstall_containers uninstall_containers_progress "Zatrzymywanie usług" "Proszę czekać, trwa zatrzymywanie usług..."
fi

