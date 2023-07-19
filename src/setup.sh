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
check_dotenv
setup_packages
setup_node
setup_users
setup_dir_structure
download_conf

source_admin

prompt_welcome
prompt_mikrus_host
prompt_mikrus_apikey
prompt_api_secret

install_containers(){
    docker-compose --env-file /srv/nightscout/config/deployment.env -f /srv/nightscout/config/docker-compose.yml up -d
}

showprogress(){                                     
    start=$1; end=$2; shortest=$3; longest=$4

    for n in $(seq $start $end); do
        echo $n
        pause=$(shuf -i ${shortest:=1}-${longest:=3} -n 1)
        sleep $pause
    done
}

processgauge(){                                       
    process_to_measure=$1
    message=$2
    
    eval $process_to_measure &
    thepid=$!
    num=25
    while true; do
        showprogress 1 $num 1 3
        sleep 2
        while $(ps aux | grep -v 'grep' | grep "$thepid" &>/dev/null); do
            if [[ $num -gt 97 ]] ; then num=$(( num-1 )); fi
            showprogress $num $((num+1))
            num=$((num+1))
        done
        showprogress 99 100 3 3
    done  | whiptail --title "Progress Gauge" --gauge "$message" 6 70 0
}


NS_ID=$(docker ps -a --no-trunc --filter name=^ns-server --format '{{ .ID }}')
if [[ "$NS_ID" =~ [0-9a-fA-F]{12,} ]]; then
    whiptail --msgbox "Nigtscout już działa!" 5 12
else 
    ##processgauge calculate "Todo"
fi

whiptail --msgbox "Odpalam" 5 12
install_containers
whiptail --msgbox "Gotowe!" 5 12

