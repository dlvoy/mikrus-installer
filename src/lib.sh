#=======================================
# CONFIG
#=======================================

REQUIRED_NODE_VERSION=18.0.0
LOGTO=/dev/null
ENV_FILE_ADMIN=/srv/nightscout/config/admin.env
ENV_FILE_NS=/srv/nightscout/config/nightscout.env
ENV_FILE_DEP=/srv/nightscout/config/deployment.env
DOCKER_COMPOSE_FILE=/srv/nightscout/config/docker-compose.yml

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
tty_underline="$(tty_escape "4;39")"
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

#=======================================
# EMOJIS
#=======================================

emoji_unicorn="\U1F984"
emoji_check="\U2705"
emoji_ok="\U1F197"

uni_bullet="  $(printf '\u2022') " 
uni_bullet_pad="    "

uni_exit=" $(printf '\U274C') Wyjdź " 
uni_start=" $(printf '\U1F984') Zaczynamy " 
uni_reenter=" $(printf '\U21AA') Tak "
uni_noenter=" $(printf '\U2716') Nie " 
uni_select=" Wybierz "
uni_excl="$(printf '\U203C')" 

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
    printf "$emoji_ok  $1\n"
}

msgcheck() {
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

if:IsSet() {
    [[ ${!1-x} == x ]] && return 1 || return 0
}

#=======================================
# VARIABLES
#=======================================

packages=()
serverName=$(hostname)
apiKey=""

#=======================================
# ACTIONS AND STEPS
#=======================================

setup_update_repo() {
    ohai "Updating package repository"
    apt-get -yq update >/dev/null 2>&1
}

test_node() {
    local node_version_output
    node_version_output="$(node -v 2>/dev/null)"
    version_ge "$(major_minor "${node_version_output/v/}")" "$(major_minor "${REQUIRED_NODE_VERSION}")"
}

# $1 lib name
# $2 package name
add_if_not_ok() {
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        msgcheck "$1 installed"
    else
        packages+=("$2")
    fi
}

add_if_not_ok_cmd() {
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        msgcheck "$1 installed"
    else
        ohai "Installing $1..."
        eval $2 >/dev/null 2>&1 && msgcheck "Installing $1 successfull"
    fi
}

check_tig() {
    tig -v >/dev/null 2>&1
    add_if_not_ok "Tig" "tig"
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
    if:IsSet packages && ohai "Installing packages: ${packages[@]}" && apt-get -yq install ${packages[@]} >/dev/null 2>&1 && msgcheck "Install successfull" || msgok "All required packages already installed"
}

setup_node() {
    test_node
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        msgcheck "Node installed in correct version"
    else
        ohai "Preparing Node.js setup"
        curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null 2>&1

        ohai "Installing Node.js"
        apt-get install -y nodejs >/dev/null 2>&1
    fi
}

exit_on_no_cancel() {
    if [ $? -eq 1 ]; then
        exit 0
    fi
}

setup_users() {
    id -u mongodb &>/dev/null
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        msgcheck "Mongo DB user detected"
    else
        ohai "Configuring Mongo DB user"
        useradd -u 1001 -g 0 mongodb
    fi
}

setup_dir_structure() {
    ohai "Configuring folder structure"
    mkdir -p /srv/nightscout/data/mongodb
    mkdir -p /srv/nightscout/config
    chown -R mongodb:root /srv/nightscout/data/mongodb
}

get_docker_status() {
    ID=$(docker ps -a --no-trunc --filter name="^$1" --format '{{ .ID }}')
    if [[ "$ID" =~ [0-9a-fA-F]{12,} ]]; then
        echo $(docker inspect $ID | jq -r ".[0].State.Status")
    else 
        echo 'missing'
    fi
}

# >/dev/null 2>&1

install_containers() {
    docker-compose --env-file /srv/nightscout/config/deployment.env -f /srv/nightscout/config/docker-compose.yml up -d >/dev/null 2>&1  
}

install_containers_progress() {
    created=$(docker container ls -f 'status=created' -f name=ns-server -f name=ns-database | wc -l)
    current=$(docker container ls -f 'status=running' -f name=ns-server -f name=ns-database | wc -l)
    progr=$(( ($current-1)*2 + ($created-1) ))
    if [ "$progr" -eq "0" ]; then
        echo $1
    else
        echo $(( ($progr*50 / 6)+50 )) 
    fi
}

uninstall_containers() {
    docker-compose --env-file /srv/nightscout/config/deployment.env -f /srv/nightscout/config/docker-compose.yml down >/dev/null 2>&1
}

uninstall_containers_progress() {
    current=$(docker container ls -f 'status=exited' -f name=ns-server -f name=ns-database | wc -l)
    echo $(( (($current-1)*100 / 3) ))
}

MIKRUS_APIKEY=''
MIKRUS_HOST=''

source_admin() {
    if [[ -f $ENV_FILE_ADMIN ]]; then
        source $ENV_FILE_ADMIN
        msgok "Imported admin config"
    fi
}

download_if_not_exists() {
    if [[ -f $2 ]]; then
        msgok "Found $1"
    else 
        ohai "Downloading $1..."
        curl -fsSL -o $2 $3
        msgcheck "Downloaded $1"
    fi
}

download_conf() {
    download_if_not_exists "deployment config" $ENV_FILE_DEP https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/master/templates/deployment.env
    download_if_not_exists "nightscout config" $ENV_FILE_NS https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/master/templates/nightscout.env
    download_if_not_exists "docker compose file" $DOCKER_COMPOSE_FILE https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/master/templates/docker-compose.yml
}

prompt_welcome() {
    whiptail --title "Witamy" --yesno "Ten skrypt zainstaluje Nightscout na bieżącym serwerze mikr.us\n\nJeśli na tym serwerze jest już Nightscout \n- ten skrypt umożliwia jego aktualizację oraz diagnostykę." --yes-button "$uni_start" --no-button "$uni_exit" 12 70 
    exit_on_no_cancel
}

prompt_mikrus_host() {
    if ! [[ "$MIKRUS_HOST" =~ [a-z][0-9]{3} ]]; then
        MIKRUS_HOST=`hostname`
        while : ; do
            if [[ "$MIKRUS_HOST" =~ [a-z][0-9]{3} ]]; then
                break;
            else
                MIKRUS_NEW_HOST=$(whiptail --title "Podaj identyfikator serwera" --inputbox "\nNie udało się wykryć identyfikatora serwera,\npodaj go poniżej ręcznie.\n\nIdentyfikator składa się z jednej litery i trzech cyfr\n" --cancel-button "Anuluj" 13 65 3>&1 1>&2 2>&3)
                exit_on_no_cancel
                if [[ "$MIKRUS_NEW_HOST" =~ [a-z][0-9]{3} ]]; then
                    MIKRUS_HOST=$MIKRUS_NEW_HOST
                    break;
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
        whiptail --title "Przygotuj klucz API" --msgbox "Do zarządzania mikrusem [$MIKRUS_HOST] potrzebujemy klucz API.\n\n${uni_bullet}otwórz nową zakładkę w przeglądarce,\n${uni_bullet}wejdź do panelu administracyjnego swojego Mikr.us-a,\n${uni_bullet}otwórz sekcję API, pod adresem:\n\n${uni_bullet_pad}https://mikr.us/panel/?a=api\n\n${uni_bullet}skopiuj do schowka wartość klucza API"  16 70 
        exit_on_no_cancel

        while : ; do
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
    while : ; do 
        CHOICE=$(whiptail --title "Ustal API SECRET" --menu "\nUstal bezpieczny API_SECRET, tajne główne hasło zabezpieczające dostęp do Twojego Nightscouta\n" 13 70 2 \
        "1)" "Wygeneruj losowo."   \
        "2)" "Podaj własny."  \
        --ok-button="$uni_select" --cancel-button="$uni_exit" \
        3>&2 2>&1 1>&3)
        exit_on_no_cancel

        case $CHOICE in
            "1)")   
                API_SECRET=$(openssl rand -base64 100 | tr -dc '23456789@ABCDEFGHJKLMNPRSTUVWXYZabcdefghijkmnopqrstuvwxyz' | fold -w 16 | head -n 1)
                whiptail --title "Zapisz API SECRET" --msgbox "Zapisz poniższy wygenerowany API SECRET w bezpiecznym miejscu, np.: managerze haseł:\n\n\n              $API_SECRET" 12 50 
            ;;
            "2)")
                while : ; do   
                    API_SECRET=$(whiptail --title "Podaj API SECRET" --inputbox "\nWpisz API SECRET do serwera Nightscout:\n${uni_bullet}Upewnij się że masz go zapisanego np.: w managerze haseł\n${uni_bullet}Użyj conajmniej 12 znaków: małych i dużych liter i cyfr\n\n" --cancel-button "Anuluj" 12 75 3>&1 1>&2 2>&3)

    
                    if [ $? -eq 1 ]; then
                        break;
                    fi 
                    
                    if [[ "$API_SECRET" =~ [a-zA-Z0-9%+=./:=@_]{12,} ]]; then
                        break;
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
    message=$3
    lenmsg=$(echo "$4" | wc -l)
    eval $process_to_measure &
    thepid=$!
    num=1
    while true; do
        echo 0
        while kill -0 "$thepid" >/dev/null 2>&1; do
            if [[ $num -gt 50 ]] ; then num=50; fi
            eval $2 $num
            num=$((num+1))
            sleep 0.3
        done
        echo 100
        break
    done  | whiptail --title "$3" --gauge "\n  $4\n" $(( $lenmsg +6 )) 70 0
}
