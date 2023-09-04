#!/bin/bash

### version: 1.3.0

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
# shellcheck source=/dev/null
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
check_ufw
setup_packages
setup_node
check_dotenv
setup_users
setup_dir_structure
download_conf
download_tools
update_if_needed
setup_firewall

source_admin

prompt_welcome
prompt_mikrus_host
prompt_mikrus_apikey
prompt_api_secret

install_or_menu
