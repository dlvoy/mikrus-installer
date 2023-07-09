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
setup_packages
setup_node
