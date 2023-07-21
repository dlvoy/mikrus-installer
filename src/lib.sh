# shellcheck disable=SC2148
# shellcheck disable=SC2155

#=======================================
# CONFIG
#=======================================

REQUIRED_NODE_VERSION=18.0.0
LOGTO=./log.txt
ENV_FILE_ADMIN=/srv/nightscout/config/admin.env
ENV_FILE_NS=/srv/nightscout/config/nightscout.env
ENV_FILE_DEP=/srv/nightscout/config/deployment.env
DOCKER_COMPOSE_FILE=/srv/nightscout/config/docker-compose.yml
MONGO_DB_DIR=/srv/nightscout/data/mongodb
TOOL_FILE=/srv/nightscout/tools/nightscout-tool
TOOL_LINK=/usr/bin/nightscout-tool
UPDATES_DIR=/srv/nightscout/updates
SCRIPT_VERSION="1.0.0" #auto-update
SCRIPT_BUILD_TIME="2023.07.01" #auto-update

#=======================================
# SETUP
#=======================================

set -u

abort() {
    printf "%s\n" "$@" >&2
    exit 1
}

export NEWT_COLORS='
    root=white,black
    border=black,lightgray
    window=lightgray,lightgray
    shadow=black,gray
    title=black,lightgray
    button=black,cyan
    actbutton=white,cyan
    compactbutton=black,lightgray
    checkbox=black,lightgray
    actcheckbox=lightgray,cyan
    entry=black,lightgray
    disentry=gray,lightgray
    label=black,lightgray
    listbox=black,lightgray
    actlistbox=black,cyan
    sellistbox=lightgray,black
    actsellistbox=lightgray,black
    textbox=black,lightgray
    acttextbox=black,cyan
    emptyscale=,gray
    fullscale=,cyan
    helpline=white,black
    roottext=lightgrey,black
'

#=======================================
# SANITY CHECKS
#=======================================

# Fail fast with a concise message when not using bash
# Single brackets are needed here for POSIX compatibility
# shellcheck disable=SC2292
if [ -z "${BASH_VERSION:-}" ]; then
    abort "Bash is required to interpret this script."
fi

# Check if script is run with force-interactive mode in CI
if [[ -n "${CI-}" && -n "${INTERACTIVE-}" ]]; then
    abort "Cannot run force-interactive mode in CI."
fi

# Check if both `INTERACTIVE` and `NONINTERACTIVE` are set
# Always use single-quoted strings with `exp` expressions
# shellcheck disable=SC2016
if [[ -n "${INTERACTIVE-}" && -n "${NONINTERACTIVE-}" ]]; then
    abort 'Both `$INTERACTIVE` and `$NONINTERACTIVE` are set. Please unset at least one variable and try again.'
fi

# Check if script is run in POSIX mode
if [[ -n "${POSIXLY_CORRECT+1}" ]]; then
    abort 'Bash must not run in POSIX mode. Please unset POSIXLY_CORRECT and try again.'
fi

#=======================================
# FORMATERS
#=======================================

if [[ -t 1 ]]; then
    tty_escape() { printf "\033[%sm" "$1"; }
else
    tty_escape() { :; }
fi
tty_mkbold() { tty_escape "1;$1"; }
# tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

#=======================================
# EMOJIS
#=======================================

emoji_check="\U2705"
emoji_ok="\U1F197"

uni_bullet="  $(printf '\u2022') "
uni_bullet_pad="    "

uni_exit=" $(printf '\U274C') Wyjdź "
uni_start=" $(printf '\U1F984') Zaczynamy "
uni_menu=" $(printf '\U1F6E0')  Menu "
uni_finish=" $(printf '\U1F984') Zamknij "
uni_reenter=" $(printf '\U21AA') Tak "
uni_noenter=" $(printf '\U2716') Nie "
uni_back=" $(printf '\U2B05') Wróć "
uni_select=" Wybierz "
uni_excl="$(printf '\U203C')"
uni_confirm_del=" $(printf '\U1F4A3') Tak "
uni_confirm_upd=" $(printf '\U1F199') Aktualizuj "
uni_install=" $(printf '\U1F680') Instaluj "
uni_resign=" $(printf '\U1F6AB') Rezygnuję "

#=======================================
# UTILS
#=======================================

shell_join() {
    local arg
    printf "%s" "$1"
    shift
    for arg in "$@"; do
        printf " "
        printf "%s" "${arg// /\ }"
    done
}

chomp() {
    printf "%s" "${1/"$'\n'"/}"
}

ohai() {
    printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
}

msgok() {
    # shellcheck disable=SC2059
    printf "$emoji_ok  $1\n"
}

msgcheck() {
    # shellcheck disable=SC2059
    printf "$emoji_check  $1\n"
}

warn() {
    printf "${tty_red}Warning${tty_reset}: %s\n" "$(chomp "$1")" >&2
}

# Search for the given executable in PATH (avoids a dependency on the `which` command)
which() {
    # Alias to Bash built-in command `type -P`
    type -P "$@"
}

major_minor() {
    echo "${1%%.*}.$(
        x="${1#*.}"
        echo "${x%%.*}"
    )"
}

version_gt() {
    [[ "${1%.*}" -gt "${2%.*}" ]] || [[ "${1%.*}" -eq "${2%.*}" && "${1#*.}" -gt "${2#*.}" ]]
}
version_ge() {
    [[ "${1%.*}" -gt "${2%.*}" ]] || [[ "${1%.*}" -eq "${2%.*}" && "${1#*.}" -ge "${2#*.}" ]]
}
version_lt() {
    [[ "${1%.*}" -lt "${2%.*}" ]] || [[ "${1%.*}" -eq "${2%.*}" && "${1#*.}" -lt "${2#*.}" ]]
}

ifIsSet() {
    [[ ${!1-x} == x ]] && return 1 || return 0
}

exit_on_no_cancel() {
    if [ $? -eq 1 ]; then
        exit 0
    fi
}

#=======================================
# HELPERS
#=======================================

echo_progress() {
    local realProg=$1       # numerical real progress
    local realMax=$2        # max value of that progress
    local realStart=$3      # where real progress starts, %
    local countr=$4         # real ticker, 3 ticks/s
    local firstPhaseSecs=$5 # how long first, ticked part, last

    if [ "$realProg" -eq "0" ]; then
        local progrsec=$(((countr * realStart) / (3 * firstPhaseSecs)))
        if [ $progrsec -lt "$realStart" ]; then
            echo $progrsec
        else
            echo "$realStart"
        fi
    else
        echo $(((realProg * (100 - realStart) / realMax) + realStart))
    fi
}

process_gauge() {
    local process_to_measure=$1
    local lenmsg
    lenmsg=$(echo "$4" | wc -l)
    eval "$process_to_measure" &
    local thepid=$!
    local num=1
    while true; do
        echo 0
        while kill -0 "$thepid" >/dev/null 2>&1; do
            eval "$2" $num
            num=$((num + 1))
            sleep 0.3
        done
        echo 100
        break
    done | whiptail --title "$3" --gauge "\n  $4\n" $((lenmsg + 6)) 70 0
}

download_if_not_exists() {
    if [[ -f $2 ]]; then
        msgok "Found $1"
    else
        ohai "Downloading $1..."
        curl -fsSL -o "$2" "$3"
        msgcheck "Downloaded $1"
    fi
}

center_text() {
    local inText="$1"
    local len=${#inText}
    local spaces="                                                                      "
    echo "${spaces:0:$(( ($2-len)/2 ))}$1"
}

#=======================================
# VARIABLES
#=======================================

packages=()
aptGetWasUpdated=0
freshInstall=0

MIKRUS_APIKEY=''
MIKRUS_HOST=''

#=======================================
# ACTIONS AND STEPS
#=======================================

setup_update_repo() {
    if [ "$aptGetWasUpdated" -eq "0" ]; then
        aptGetWasUpdated=1
        ohai "Updating package repository"
        apt-get -yq update >>$LOGTO 2>&1
    fi
}

test_node() {
    local node_version_output
    node_version_output="$(node -v 2>/dev/null)"
    version_ge "$(major_minor "${node_version_output/v/}")" "$(major_minor "${REQUIRED_NODE_VERSION}")"
}

# $1 lib name
# $2 package name
add_if_not_ok() {
    local RESULT=$?
    if [ $RESULT -eq 0 ]; then
        msgcheck "$1 installed"
    else
        packages+=("$2")
    fi
}

add_if_not_ok_cmd() {
    local RESULT=$?
    if [ $RESULT -eq 0 ]; then
        msgcheck "$1 installed"
    else
        ohai "Installing $1..."
        eval "$2" >>$LOGTO 2>&1 && msgcheck "Installing $1 successfull"
    fi
}

check_git() {
    git --version >/dev/null 2>&1
    add_if_not_ok "GIT" "git"
}

check_docker() {
    docker -v >/dev/null 2>&1
    add_if_not_ok "Docker" "docker.io"
}

check_docker_compose() {
    docker-compose -v >/dev/null 2>&1
    add_if_not_ok "Docker compose" "docker-compose"
}

check_jq() {
    jq --help >/dev/null 2>&1
    add_if_not_ok "JSON parser" "jq"
}

check_dotenv() {
    dotenv-tool -v >/dev/null 2>&1
    add_if_not_ok_cmd "dotenv-tool" "npm install -g dotenv-tool --registry https://npm.dzienia.pl"
}

setup_packages() {
    # shellcheck disable=SC2145
    # shellcheck disable=SC2068
    (ifIsSet packages && setup_update_repo && ohai "Installing packages: ${packages[@]}" && apt-get -yq install ${packages[@]} >>$LOGTO 2>&1 && msgcheck "Install successfull") || msgok "All required packages already installed"
}

setup_node() {
    test_node
    local RESULT=$?
    if [ $RESULT -eq 0 ]; then
        msgcheck "Node installed in correct version"
    else
        ohai "Preparing Node.js setup"
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null 2>&1

        ohai "Installing Node.js"
        apt-get install -y nodejs >>$LOGTO 2>&1
    fi
}

setup_users() {
    id -u mongodb &>/dev/null
    local RESULT=$?
    if [ $RESULT -eq 0 ]; then
        msgcheck "Mongo DB user detected"
    else
        ohai "Configuring Mongo DB user"
        useradd -u 1001 -g 0 mongodb
    fi
}

setup_dir_structure() {
    ohai "Configuring folder structure"
    mkdir -p $MONGO_DB_DIR
    mkdir -p /srv/nightscout/config
    mkdir -p /srv/nightscout/tools
    mkdir -p $UPDATES_DIR
    chown -R mongodb:root $MONGO_DB_DIR
}

get_docker_status() {
    local ID=$(docker ps -a --no-trunc --filter name="^$1" --format '{{ .ID }}')
    if [[ "$ID" =~ [0-9a-fA-F]{12,} ]]; then
        docker inspect "$ID" | jq -r ".[0].State.Status"
    else
        echo 'missing'
    fi
}

install_containers() {
    docker-compose --env-file /srv/nightscout/config/deployment.env -f /srv/nightscout/config/docker-compose.yml up -d >>$LOGTO 2>&1
}

install_containers_progress() {
    local created=$(docker container ls -f 'status=created' -f name=ns-server -f name=ns-database | wc -l)
    local current=$(docker container ls -f 'status=running' -f name=ns-server -f name=ns-database | wc -l)
    local progr=$(((current - 1) * 2 + (created - 1)))
    echo_progress $progr 6 50 "$1" 60
}

uninstall_containers() {
    docker-compose --env-file /srv/nightscout/config/deployment.env -f /srv/nightscout/config/docker-compose.yml down >>$LOGTO 2>&1
}

uninstall_containers_progress() {
    local running=$(docker container ls -f 'status=running' -f name=ns-server -f name=ns-database -f name=ns-backup | wc -l)
    local current=$(docker container ls -f 'status=exited' -f name=ns-server -f name=ns-database -f name=ns-backup | wc -l)
    local progr=$((current - 1))
    if [ "$(((running - 1) + (current - 1)))" -eq "0" ]; then
        echo_progress 3 3 50 "$1" 15
    else
        echo_progress $progr 3 50 "$1" 15
    fi
}

source_admin() {
    if [[ -f $ENV_FILE_ADMIN ]]; then
        # shellcheck disable=SC1090
        source $ENV_FILE_ADMIN
        msgok "Imported admin config"
    fi
}

download_conf() {
    download_if_not_exists "deployment config" $ENV_FILE_DEP https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/master/templates/deployment.env
    download_if_not_exists "nightscout config" $ENV_FILE_NS https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/master/templates/nightscout.env
    download_if_not_exists "docker compose file" $DOCKER_COMPOSE_FILE https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/master/templates/docker-compose.yml
}

download_tools() {
    download_if_not_exists "update stamp" "$UPDATES_DIR/updated" https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/master/updated

    if ! [[ -f $TOOL_FILE ]]; then
        download_if_not_exists "nightscout-tool file" $TOOL_FILE https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/master/install.sh
        local timestamp=$(date +%s)
        echo "$timestamp" >"$UPDATES_DIR/timestamp"
    else
        msgok "Found nightscout-tool"
    fi

    if ! [[ -f $TOOL_LINK ]]; then
        ohai "Linking nightscout-tool"
        ln -s "$TOOL_FILE" "$TOOL_LINK"
    fi

    chmod +x $TOOL_FILE
    chmod +x $TOOL_LINK
}

extract_version() {
    regex='version:\s+([0-9]+\.[0-9]+\.[0-9]+)'
    if [[ "$1" =~ $regex ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "0.0.0"
    fi
}

update_if_needed() {
    local lastUpdate=$(cat "$UPDATES_DIR/timestamp")
    local timestamp=$(date +%s)

    if [ $((timestamp - lastUpdate)) -gt $(( 60*60*24 ))  ] || [ $# -eq 1  ]; then
        echo "$timestamp" >"$UPDATES_DIR/timestamp"
        local onlineUpdated="$(curl -fsSL "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/master/updated")"
        local lastUpdate=$(cat "$UPDATES_DIR/updated")
        if [ "$onlineUpdated" == "$lastUpdate" ] || [ $# -eq 0 ] ; then
            msgok "Scripts and config files are up to date"
            if [ $# -eq 1 ]; then
                whiptail --title "Aktualizacja skryptów" --msgbox "$1" 7 50
            fi
        else
            ohai "Updating scripts and config files"
            curl -fsSL -o "$UPDATES_DIR/install.sh" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/master/install.sh"
            curl -fsSL -o "$UPDATES_DIR/deployment.env" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/master/templates/deployment.env"
            curl -fsSL -o "$UPDATES_DIR/nightscout.env" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/master/templates/nightscout.env"
            curl -fsSL -o "$UPDATES_DIR/docker-compose.yml" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/master/templates/docker-compose.yml"

            local changed=0
            local redeploy=0

            local instOnlineVer=$(extract_version "$(<"$UPDATES_DIR/install.sh")")
            local depEnvOnlineVer=$(extract_version "$(<"$UPDATES_DIR/deployment.env")")
            local nsEnvOnlineVer=$(extract_version "$(<"$UPDATES_DIR/nightscout.env")")
            local compOnlineVer=$(extract_version "$(<"$UPDATES_DIR/docker-compose.yml")")

            local instLocalVer=$(extract_version "$(<"$TOOL_FILE")")
            local depEnvLocalVer=$(extract_version "$(<"$ENV_FILE_DEP")")
            local nsEnvLocalVer=$(extract_version "$(<"$ENV_FILE_NS")")
            local compLocalVer=$(extract_version "$(<"$DOCKER_COMPOSE_FILE")")

            local msgInst="$(printf "\U1F7E2") $instLocalVer"
            local msgDep="$(printf "\U1F7E2") $depEnvLocalVer"
            local msgNs="$(printf "\U1F7E2") $nsEnvLocalVer"
            local msgComp="$(printf "\U1F7E2") $compLocalVer"

            if ! [ "$instOnlineVer" == "$instLocalVer" ]; then
                changed=$((changed+1))
                msgInst="$(printf "\U1F534") $instLocalVer $(printf "\U27A1") $instOnlineVer"
            fi

            if ! [ "$depEnvLocalVer" == "$depEnvOnlineVer" ]; then
                changed=$((changed+1))
                redeploy=$((redeploy+1))
                msgDep="$(printf "\U1F534") $depEnvLocalVer $(printf "\U27A1") $depEnvOnlineVer"
            fi

            if ! [ "$nsEnvLocalVer" == "$nsEnvOnlineVer" ]; then
                changed=$((changed+1))
                redeploy=$((redeploy+1))
                msgNs="$(printf "\U1F534") $nsEnvLocalVer $(printf "\U27A1") $nsEnvOnlineVer"
            fi

            if ! [ "$compLocalVer" == "$compOnlineVer" ]; then
                changed=$((changed+1))
                redeploy=$((redeploy+1))
                msgComp="$(printf "\U1F534") $compLocalVer $(printf "\U27A1") $compOnlineVer"
            fi

            if [ $changed -eq 0 ]; then
                if [ $# -eq 1 ]; then
                    whiptail --title "Aktualizacja skryptów" --msgbox "$1" 7 50
                fi
            else
                local okTxt=""
                if [ $redeploy -gt 0 ]; then
                    okTxt="\n\n $(printf "\U26A0") Aktualizacja spowoduje też restart i aktualizację kontenerów $(printf "\U26A0")"
                fi

                whiptail --title "Aktualizacja skryptów" --yesno "Zalecana jest aktualizacja plików:\n\n${uni_bullet}Skrypt instalacyjny:      $msgInst \n${uni_bullet}Konfiguracja deploymentu: $msgDep\n${uni_bullet}Konfiguracja Nightscout:  $msgNs \n${uni_bullet}Kompozycja usług:         $msgComp $okTxt" \
                --yes-button "$uni_confirm_upd" --no-button "$uni_resign" 15 70
                if ! [ $? -eq 1 ]; then
                    if [ $redeploy -gt 0 ]; then
                        docker_compose_down
                    fi

                    if ! [ "$instOnlineVer" == "$instLocalVer" ]; then
                        ohai "Updating $DOCKER_COMPOSE_FILE"
                        cp -fr "$UPDATES_DIR/docker-compose.yml" "$DOCKER_COMPOSE_FILE"
                    fi

                    if ! [ "$depEnvLocalVer" == "$depEnvOnlineVer" ]; then
                        ohai "Updating $ENV_FILE_DEP"
                        dotenv-tool -pr -o "$ENV_FILE_DEP" -i "$UPDATES_DIR/deployment.env" "$ENV_FILE_DEP"
                    fi

                    if ! [ "$nsEnvLocalVer" == "$nsEnvOnlineVer" ]; then
                        ohai "Updating $ENV_FILE_NS"
                        dotenv-tool -pr -o "$ENV_FILE_NS" -i "$UPDATES_DIR/deployment.env" "$ENV_FILE_NS"
                    fi

                    echo "$onlineUpdated" >"$UPDATES_DIR/updated"

                    if ! [ "$instOnlineVer" == "$instLocalVer" ]; then
                        ohai "Updating $TOOL_FILE"
                        cp -fr "$UPDATES_DIR/install.sh" "$TOOL_FILE"
                        whiptail --title "Aktualizacja zakończona" --msgbox "Narzędzie zostanie uruchomione ponownie" 7 50
                        ohai "Restarting tool"
                        exec "$TOOL_FILE"
                    fi


                fi
            fi

        fi

    else
        msgok "Too soon to check for update, skipping..."
    fi
}

about_dialog() {
    local width=60
    local cw=$((width - 5))
    whiptail --title "O tym narzędziu..." --msgbox "$(center_text "$(printf '\U1F9D1') (c) 2023 Dominik Dzienia" $cw)\n$(center_text "$(printf '\U1F4E7') dominik.dzienia@gmail.com" $cw)\n\n$(center_text "$(printf '\U1F3DB')  To narzędzie jest dystrybuowane na licencji MIT" $cw)\n\n$(center_text "wersja: $SCRIPT_VERSION ($SCRIPT_BUILD_TIME)" $cw)" 12 $width
}

prompt_welcome() {
    whiptail --title "Witamy" --yesno "Ten skrypt zainstaluje Nightscout na bieżącym serwerze mikr.us\n\nJeśli na tym serwerze jest już Nightscout \n- ten skrypt umożliwia jego aktualizację oraz diagnostykę." --yes-button "$uni_start" --no-button "$uni_exit" 12 70
    exit_on_no_cancel
}

instal_now_prompt() {
    whiptail --title "Instalować Nightscout?" --yesno "Wykryto konfigurację ale brak uruchomionych usług\nCzy chcesz zainstalować teraz kontenery Nightscout?" --yes-button "$uni_install" --no-button "$uni_noenter" 9 70
}

prompt_mikrus_host() {
    if ! [[ "$MIKRUS_HOST" =~ [a-z][0-9]{3} ]]; then
        MIKRUS_HOST=$(hostname)
        while :; do
            if [[ "$MIKRUS_HOST" =~ [a-z][0-9]{3} ]]; then
                break
            else
                MIKRUS_NEW_HOST=$(whiptail --title "Podaj identyfikator serwera" --inputbox "\nNie udało się wykryć identyfikatora serwera,\npodaj go poniżej ręcznie.\n\nIdentyfikator składa się z jednej litery i trzech cyfr\n" --cancel-button "Anuluj" 13 65 3>&1 1>&2 2>&3)
                exit_on_no_cancel
                if [[ "$MIKRUS_NEW_HOST" =~ [a-z][0-9]{3} ]]; then
                    MIKRUS_HOST=$MIKRUS_NEW_HOST
                    break
                else
                    whiptail --title "$uni_excl Nieprawidłowy identyfikator serwera $uni_excl" --yesno "Podany identyfikator serwera ma nieprawidłowy format.\n\nChcesz podać go ponownie?" --yes-button "$uni_reenter" --no-button "$uni_exit" 12 70
                    exit_on_no_cancel
                fi
            fi
        done

        ohai "Updating admin config (host)"
        dotenv-tool -pmr -i $ENV_FILE_ADMIN -- "MIKRUS_HOST=$MIKRUS_HOST"
    fi
}

prompt_mikrus_apikey() {
    if ! [[ "$MIKRUS_APIKEY" =~ [0-9a-fA-F]{40} ]]; then
        freshInstall=$((freshInstall+1))
        whiptail --title "Przygotuj klucz API" --msgbox "Do zarządzania mikrusem [$MIKRUS_HOST] potrzebujemy klucz API.\n\n${uni_bullet}otwórz nową zakładkę w przeglądarce,\n${uni_bullet}wejdź do panelu administracyjnego swojego Mikr.us-a,\n${uni_bullet}otwórz sekcję API, pod adresem:\n\n${uni_bullet_pad}https://mikr.us/panel/?a=api\n\n${uni_bullet}skopiuj do schowka wartość klucza API" 16 70
        exit_on_no_cancel

        while :; do
            MIKRUS_APIKEY=$(whiptail --title "Podaj klucz API" --inputbox "\nWpisz klucz API. Jeśli masz go skopiowanego w schowku,\nkliknij prawym przyciskiem i wybierz <wklej> z menu:" --cancel-button "Anuluj" 11 65 3>&1 1>&2 2>&3)
            exit_on_no_cancel
            if [[ "$MIKRUS_APIKEY" =~ [0-9a-fA-F]{40} ]]; then
                MIKRUS_INFO_HOST=$(curl -s -d "srv=$MIKRUS_HOST&key=$MIKRUS_APIKEY" -X POST https://api.mikr.us/info | jq -r .server_id)

                if [[ "$MIKRUS_INFO_HOST" == "$MIKRUS_HOST" ]]; then
                    msgcheck "Mikrus OK"
                    break
                else
                    whiptail --title "$uni_excl Nieprawidłowy API key $uni_excl" --yesno "Podany API key wydaje się mieć dobry format, ale NIE DZIAŁA!\nMoże to literówka lub podano API KEY z innego Mikr.us-a?.\n\nPotrzebujesz API KEY serwera [$MIKRUS_HOST]\n\nChcesz podać go ponownie?" --yes-button "$uni_reenter" --no-button "$uni_exit" 12 70
                    exit_on_no_cancel
                fi
            else
                whiptail --title "$uni_excl Nieprawidłowy API key $uni_excl" --yesno "Podany API key ma nieprawidłowy format.\n\nChcesz podać go ponownie?" --yes-button "$uni_reenter" --no-button "$uni_exit" 12 70
                exit_on_no_cancel
            fi
        done

        ohai "Updating admin config (api key)"
        dotenv-tool -pmr -i $ENV_FILE_ADMIN -- "MIKRUS_APIKEY=$MIKRUS_APIKEY"
    fi
}

prompt_api_secret() {
    API_SECRET=$(dotenv-tool -r get -f $ENV_FILE_NS "API_SECRET")

    if ! [[ "$API_SECRET" =~ [a-zA-Z0-9%+=./:=@_]{12,} ]]; then
        freshInstall=$((freshInstall+1))
        while :; do
            CHOICE=$(whiptail --title "Ustal API SECRET" --menu "\nUstal bezpieczny API_SECRET, tajne główne hasło zabezpieczające dostęp do Twojego Nightscouta\n" 13 70 2 \
                "1)" "Wygeneruj losowo." \
                "2)" "Podaj własny." \
                --ok-button="$uni_select" --cancel-button="$uni_exit" \
                3>&2 2>&1 1>&3)
            exit_on_no_cancel

            case $CHOICE in
            "1)")
                API_SECRET=$(openssl rand -base64 100 | tr -dc '23456789@ABCDEFGHJKLMNPRSTUVWXYZabcdefghijkmnopqrstuvwxyz' | fold -w 16 | head -n 1)
                whiptail --title "Zapisz API SECRET" --msgbox "Zapisz poniższy wygenerowany API SECRET w bezpiecznym miejscu, np.: managerze haseł:\n\n\n              $API_SECRET" 12 50
                ;;
            "2)")
                while :; do
                    API_SECRET=$(whiptail --title "Podaj API SECRET" --inputbox "\nWpisz API SECRET do serwera Nightscout:\n${uni_bullet}Upewnij się że masz go zapisanego np.: w managerze haseł\n${uni_bullet}Użyj conajmniej 12 znaków: małych i dużych liter i cyfr\n\n" --cancel-button "Anuluj" 12 75 3>&1 1>&2 2>&3)

                    if [ $? -eq 1 ]; then
                        break
                    fi

                    if [[ "$API_SECRET" =~ [a-zA-Z0-9%+=./:=@_]{12,} ]]; then
                        break
                    else
                        whiptail --title "$uni_excl Nieprawidłowy API SECRET $uni_excl" --yesno "Podany API SECRET ma nieprawidłowy format.\nChcesz podać go ponownie?" --yes-button "$uni_reenter" --no-button "$uni_noenter" 10 73
                        if [ $? -eq 1 ]; then
                            API_SECRET=''
                            break
                        fi
                    fi
                done

                ;;
            esac

            while [[ "$API_SECRET" =~ [a-zA-Z0-9%+=./:=@_]{12,} ]]; do
                API_SECRET_CHECK=$(whiptail --title "Podaj ponownie API SECRET" --inputbox "\nDla sprawdzenia, wpisz ustalony przed chwilą API SECRET\n\n" --cancel-button "Anuluj" 11 65 3>&1 1>&2 2>&3)
                if [ $? -eq 1 ]; then
                    API_SECRET=''
                    break
                fi
                if [[ "$API_SECRET" == "$API_SECRET_CHECK" ]]; then
                    ohai "Updating nightscout config (api secret)"
                    dotenv-tool -pmr -i $ENV_FILE_NS -- "API_SECRET=$API_SECRET"
                    break 2
                else
                    whiptail --title "$uni_excl Nieprawidłowe API SECRET $uni_excl" --yesno "Podana wartości API SECRET różni się od poprzedniej!\nChcesz podać ponownie?\n" --yes-button "$uni_reenter" --no-button "$uni_noenter" 9 60
                    if [ $? -eq 1 ]; then
                        API_SECRET=''
                        break
                    fi
                fi

            done

        done
    fi
}

docker_compose_up() {
    process_gauge install_containers install_containers_progress "Instalowanie Nightscouta" "Proszę czekać, trwa instalowanie kontenerów..."
}

docker_compose_down() {
    process_gauge uninstall_containers uninstall_containers_progress "Zatrzymywanie Nightscouta" "Proszę czekać, trwa zatrzymywanie i usuwanie kontenerów..."
}

domain_setup() {
    ns_external_port=$(dotenv-tool -r get -f $ENV_FILE_DEP "NS_PORT")
    whiptail --title "Ustaw domenę" --msgbox "Aby Nightscout był widoczny z internetu ustaw subdomenę:\n\n${uni_bullet}otwórz nową zakładkę w przeglądarce,\n${uni_bullet}wejdź do panelu administracyjnego swojego Mikr.us-a,\n${uni_bullet}otwórz sekcję [Subdomeny], pod adresem:\n\n${uni_bullet_pad}   https://mikr.us/panel/?a=domain\n\n${uni_bullet}w pole nazwy wpisz dowolną własną nazwę\n${uni_bullet_pad}(tylko małe litery i cyfry, max. 12 znaków)\n${uni_bullet}w pole numer portu wpisz:\n${uni_bullet_pad}\n                                $ns_external_port\n\n${uni_bullet}kliknij [Dodaj subdomenę] i poczekaj do kilku minut" 22 75
}

admin_panel_promo() {
    whiptail --title "Panel zarządzania Mikr.us-em" --msgbox "Ta instalacja Nightscout dodaje dodatkowy panel administracyjny do zarządzania serwerem i konfiguracją - online.\n\nZnajdziesz go klikając na ikonkę serwera w menu strony Nightscout\nlub dodając /mikrus na końcu swojego adresu Nightscout" 12 75
}

get_container_status() {
    local ID=$(docker ps -a --no-trunc --filter name="^$1$" --format '{{ .ID }}')
    if [[ "$ID" =~ [0-9a-fA-F]{12,} ]]; then
        local status=$(docker inspect "$ID" | jq -r ".[0].State.Status")
        case "$status" in
        "running")
            printf "\U1F7E2 działa"
            ;;
        "restarting")
            printf "\U1F7E3 restart"
            ;;
        "created")
            printf "\U26AA utworzono"
            ;;
        "exited")
            printf "\U1F534 wyłączono"
            ;;
        "paused")
            printf "\U1F7E1 zapauzowano"
            ;;
        "dead")
            printf "\U1F480 zablokowany"
            ;;

        esac

    else
        printf '\U2753 nie odnaleziono'
    fi
}

show_logs() {
    local col=$((COLUMNS - 10))
    local rws=$((LINES - 3))
    if [ $col -gt 120 ]; then
        col=160
    fi
    if [ $col -lt 60 ]; then
        col=60
    fi
    if [ $rws -lt 12 ]; then
        rws=12
    fi

    local ID=$(docker ps -a --no-trunc --filter name="^$1$" --format '{{ .ID }}')
    if [ -n "$ID" ]; then
        local tmpfile=$(mktemp)
        docker logs "$ID" 2>&1 | tail $((rws * -6)) | sed 's/\x1B\[[0-9;]\{1,\}[A-Za-z]//g' >"$tmpfile"
        whiptail --title "Logi $2" --scrolltext --textbox "$tmpfile" $rws $col
        rm "$tmpfile"
    fi
}

status_menu() {
    while :; do
        local CHOICE=$(whiptail --title "Status kontenerów" --menu "\nWybierz pozycję aby zobaczyć logi:\n" 15 60 5 \
            "1)" "   Nightscout:  $(get_container_status 'ns-server')" \
            "2)" "  Baza danych:  $(get_container_status 'ns-database')" \
            "3)" "       Backup:  $(get_container_status 'ns-backup')" \
            "M)" "Powrót do menu" \
            --ok-button="Zobacz logi" --cancel-button="$uni_back" \
            3>&2 2>&1 1>&3)

        case $CHOICE in
        "1)")
            show_logs 'ns-server' 'Nightscouta'
            ;;
        "2)")
            show_logs 'ns-database' 'bazy danych'
            ;;
        "3)")
            show_logs 'ns-backup' 'usługi kopii zapasowych'
            ;;
        "M)")
            break
            ;;
        "")
            break
            ;;
        esac
    done
}

uninstall_menu() {
    local ns_tag=$(dotenv-tool -r get -f $ENV_FILE_DEP "NS_NIGHTSCOUT_TAG")
    while :; do
        local CHOICE=$(whiptail --title "Zmień lub odinstaluj Nightscout" --menu "\n" 15 70 6 \
            "1)" "Zmień wersję Nightscouta (bieżąca: $ns_tag)" \
            "2)" "Usuń kontenery" \
            "3)" "Wyczyść bazę danych" \
            "4)" "Usuń wszystko (kontenery, dane, konfigurację)" \
            "M)" "Powrót do menu" \
            --ok-button="$uni_select" --cancel-button="$uni_back" \
            3>&2 2>&1 1>&3)

        case $CHOICE in
        "2)")
            whiptail --title "Usunąć kontenery?" --yesno --defaultno "Czy na pewno chcesz usunąć kontenery powiązane z Nightscout?\n\n${uni_bullet}dane i konfiguracja NIE SĄ usuwane\n${uni_bullet}kontenery można łatwo odzyskać (opcja Aktualizuj kontenery)" --yes-button "$uni_confirm_del" --no-button "$uni_resign" 11 73
            if ! [ $? -eq 1 ]; then
                docker_compose_down
            fi
            ;;
        "3)")
            whiptail --title "Usunąć dane z bazy danych?" --yesno --defaultno "Czy na pewno chcesz usunąć dane z bazy danych?\n\n${uni_bullet}konfiguracja serwera NIE ZOSTANIE usunięta\n${uni_bullet}usunięte zostaną wszystkie dane użytkownika\n${uni_bullet_pad}  (m.in. historia glikemii, wpisy, notatki, pomiary, profile)\n${uni_bullet}kontenery zostaną zatrzymane i uruchomione ponownie (zaktualizowane)" --yes-button "$uni_confirm_del" --no-button "$uni_resign" 13 78
            if ! [ $? -eq 1 ]; then
                docker_compose_down
                dialog --title " Czyszczenie bazy danych " --infobox "\n    Usuwanie plików bazy\n   ... Proszę czekać ..." 6 32
                rm -r "${MONGO_DB_DIR:?}/*"
                docker_compose_up
            fi
            ;;
        "M)")
            break
            ;;
        "")
            break
            ;;
        esac
    done
}

main_menu() {
    while :; do
        local quickStatus=$(center_text "Nightscout: $(get_container_status 'ns-server')" 55)
        local CHOICE=$(whiptail --title "Zarządzanie Nightscoutem" --menu "\n$quickStatus\n" 19 60 8 \
            "1)" "Status kontenerów i logi" \
            "2)" "Pokaż port i API SECRET" \
            "3)" "Aktualizuj system" \
            "4)" "Aktualizuj to narzędzie" \
            "5)" "Aktualizuj kontenery" \
            "6)" "Zmień lub odinstaluj" \
            "I)" "O tym narzędziu..." \
            "X)" "Wyjście" \
            --ok-button="$uni_select" --cancel-button="$uni_exit" \
            3>&2 2>&1 1>&3)

        case $CHOICE in
        "1)")
            status_menu
            ;;
        "2)")
            local ns_external_port=$(dotenv-tool -r get -f $ENV_FILE_DEP "NS_PORT")
            local ns_api_secret=$(dotenv-tool -r get -f $ENV_FILE_NS "API_SECRET")
            whiptail --title "Podgląd konfiguracji Nightscout" --msgbox "\n   Port usługi Nightscout: $ns_external_port\n               API_SECRET: $ns_api_secret" 10 60
            ;;
        "3)")
            ohai "Updating package list"
            dialog --title " Aktualizacja systemu " --infobox "\n  Pobieranie listy pakietów\n  ..... Proszę czekać ....." 6 33
            apt-get -yq update >>$LOGTO 2>&1
            ohai "Upgrading system"
            dialog --title " Aktualizacja systemu " --infobox "\n    Instalowanie pakietów\n     ... Proszę czekać ..." 6 33
            apt-get -yq upgrade >>$LOGTO 2>&1
            ;;
        "4)")
            update_if_needed "Wszystkie pliki narzędzia są aktualne"
            ;;
        "5)")
            docker_compose_down
            docker_compose_up
            ;;
        "6)")
            uninstall_menu
            ;;
        "I)")
            about_dialog
            ;;
        "X)")
            exit 0
            ;;
        "")
            exit 0
            ;;
        esac
    done
}

setup_done() {
    whiptail --title "Gotowe!" --yesno --defaultno "     Możesz teraz zamknąć to narzędzie lub wrócić do menu.\n       Narzędzie dostępne jest też jako komenda konsoli:\n\n                         nightscout-tool" --yes-button "$uni_menu" --no-button "$uni_finish" 12 70
    exit_on_no_cancel
    main_menu
}
