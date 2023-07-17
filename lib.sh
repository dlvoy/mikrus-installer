#=======================================
# CONFIG
#=======================================

REQUIRED_NODE_VERSION=18.0.0
LOGTO=/dev/null

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
uni_start=" $(printf '\U2705') Zaczynamy " 
uni_reenter=" $(printf '\U21AA') Podaj " 
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
    printf "$emoji_ok  $1!\n"
}

msgcheck() {
    printf "$emoji_check  $1!\n"
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
        msgcheck "$1 installed!"
    else
        packages+=("$2")
    fi
}

add_if_not_ok_cmd() {
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
        msgcheck "$1 installed!"
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
        msgcheck "Node installed in correct version!"
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

MIKRUS_APIKEY=''
MIKRUS_HOST=''

prompt_mikrus_host() {
    if ! [[ "$MIKRUS_HOST" =~ [a-z][0-9]{3} ]]; then
        MIKRUS_HOST=`hostname`
        while : ; do
            if [[ "$MIKRUS_HOST" =~ [a-z][0-9]{3} ]]; then
                break;
            else
                MIKRUS_NEW_HOST=$(whiptail --title "Podaj identyfikator serwera" --inputbox "\nNie udało się wykryć identyfikatora serwera,\npodaj go poniżej ręcznie.\n\nIdentyfikator składa się z jednej litery i trzech cyfr\n" 13 65 3>&1 1>&2 2>&3)
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
    fi
}

prompt_mikrus_apikey() {
    if ! [[ "$MIKRUS_APIKEY" =~ [0-9a-fA-F]{40} ]]; then
        whiptail --title "Przygotuj klucz API" --msgbox "Do zarządzania mikrusem [$MIKRUS_HOST] potrzebujemy klucz API.\n\n${uni_bullet}otwórz nową zakładkę w przeglądarce,\n${uni_bullet}wejdź do panelu administracyjnego swojego Mikr.us-a,\n${uni_bullet}otwórz sekcję API, pod adresem:\n\n${uni_bullet_pad}https://mikr.us/panel/?a=api\n\n${uni_bullet}skopiuj do schowka wartość klucza API" --ok-button "Mam!" 16 70 
        exit_on_no_cancel

        while : ; do
            MIKRUS_APIKEY=$(whiptail --title "Podaj klucz API" --inputbox "\nWpisz klucz API. Jeśli masz go skopiowanego w schowku,\nkliknij prawym przyciskiem i wybierz <wklej> z menu:" 11 65 3>&1 1>&2 2>&3)
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
    fi
}

