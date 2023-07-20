#!/bin/bash

### version: 1.0.0

# ~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.#
#    Nightscout Mikr.us setup script    #
# ~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.#
#      (c)2023 by Dominik Dzienia       #
#      <dominik.dzienia@gmail.com>      #
#      Licensed under MIT license       #
# ~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.#
# Some functions / concepts taken from: #
#   https://github.com/Homebrew/brew    #
# ~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.~.#

#dev-begin
DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
. "$DIR/lib.sh"
#dev-end

#include lib.sh

#=======================================
# MAIN SCRIPT
#=======================================

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
if [ "$STATUS_NS" = "missing" ]; then
    ohai "Instalowanie Nightscout..."
    docker_compose_up
    domain_setup
    admin_panel_promo
    setup_done
else
    msgok "Wykryto uruchomiony Nightscout"
    main_menu
fi

