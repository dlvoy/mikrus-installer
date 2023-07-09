#=======================================
# CONFIG
#=======================================

REQUIRED_NODE_VERSION=20.0.0
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
window=,red
border=white,red
textbox=white,red
button=black,white
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
