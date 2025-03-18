#!/bin/bash

### version: 1.9.3

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

startup_version
parse_commandline_args "$@"
# check_interactive
check_git
check_docker
check_docker_compose
check_jq
check_ufw
check_nano
check_dateutils
check_diceware
setup_packages
setup_node
check_dotenv
setup_users
setup_dir_structure
download_conf
download_tools
setup_security

update_if_needed
setup_firewall
install_cron

source_admin

prompt_welcome
prompt_disclaimer
prompt_mikrus_host
prompt_mikrus_apikey
prompt_api_secret

install_or_menu
