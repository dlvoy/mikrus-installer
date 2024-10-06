#!/bin/bash

### version: 1.9.0

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


# shellcheck disable=SC2148
# shellcheck disable=SC2155

#=======================================
# CONFIG
#=======================================

REQUIRED_NODE_VERSION=18.0.0
LOGTO=/dev/null
NIGHTSCOUT_ROOT_DIR=/srv/nightscout
CONFIG_ROOT_DIR=/srv/nightscout/config
ENV_FILE_ADMIN=/srv/nightscout/config/admin.env
ENV_FILE_NS=/srv/nightscout/config/nightscout.env
ENV_FILE_DEP=/srv/nightscout/config/deployment.env
LOG_ENCRYPTION_KEY_FILE=/srv/nightscout/config/log.key
DOCKER_COMPOSE_FILE=/srv/nightscout/config/docker-compose.yml
PROFANITY_DB_FILE=/srv/nightscout/data/profanity.db
RESERVED_DB_FILE=/srv/nightscout/data/reserved.db
WATCHDOG_STATUS_FILE=/srv/nightscout/data/watchdog_status
WATCHDOG_TIME_FILE=/srv/nightscout/data/watchdog_time
WATCHDOG_LOG_FILE=/srv/nightscout/data/watchdog.log
WATCHDOG_FAILURES_FILE=/srv/nightscout/data/watchdog-failures.log
WATCHDOG_CRON_LOG=/srv/nightscout/data/watchdog-cron.log
SUPPORT_LOG=/srv/nightscout/data/support.log
UPDATE_CHANNEL_FILE=/srv/nightscout/data/update_channel
MONGO_DB_DIR=/srv/nightscout/data/mongodb
TOOL_FILE=/srv/nightscout/tools/nightscout-tool
TOOL_LINK=/usr/bin/nightscout-tool
UPDATES_DIR=/srv/nightscout/updates
UPDATE_CHANNEL=master
SCRIPT_VERSION="1.9.0"         #auto-update
SCRIPT_BUILD_TIME="2024.10.06" #auto-update

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

NL="\n"
TL="\n\n"

#=======================================
# EMOJIS
#=======================================

emoji_check="\U2705"
emoji_ok="\U1F197"
emoji_err="\U274C"
emoji_note="\U1F4A1"

uni_bullet="  $(printf '\u2022') "
uni_copyright="$(printf '\uA9\uFE0F')"
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
uni_confirm_ch=" $(printf '\U1F199') Zmień "
uni_confirm_upd=" $(printf '\U1F199') Aktualizuj "
uni_confirm_ed=" $(printf '\U1F4DD') Edytuj "
uni_install=" $(printf '\U1F680') Instaluj "
uni_resign=" $(printf '\U1F6AB') Rezygnuję "
uni_send=" $(printf '\U1F4E7') Wyślij "

uni_ns_ok="$(printf '\U1F7E2') działa"
uni_watchdog_ok="$(printf '\U1F415') Nightscout działa"

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

msgnote() {
	# shellcheck disable=SC2059
	printf "$emoji_note  $1\n"
}

msgcheck() {
	# shellcheck disable=SC2059
	printf "$emoji_check  $1\n"
}

msgerr() {
	# shellcheck disable=SC2059
	printf "$emoji_err  $1\n"
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
	echo "${spaces:0:$((($2 - len) / 2))}$1"
}

rpad_text() {
	local inText="$1"
	local len=${#inText}
	local spaces="                                                                                     "
	echo "$1${spaces:0:$(($2 - len))}"
}

multiline_length() {
	local string=$1
	local maxLen=0
	# shellcheck disable=SC2059
	readarray -t array <<<"$(printf "$string")"
	for i in "${!array[@]}"; do
		local line=${array[i]}
		lineLen=${#line}
		if [ "$lineLen" -gt "$maxLen" ]; then
			maxLen="$lineLen"
		fi
	done

	echo "$maxLen"
}

center_multiline() {
	local maxLen=70
	local string="$*"

	if [ $# -gt 1 ]; then
		maxLen=$1
		shift 1
		string="$*"
	else
		maxLen=$(multiline_length "$string")
	fi

	# shellcheck disable=SC2059
	readarray -t array <<<"$(printf "$string")"
	for i in "${!array[@]}"; do
		local line=${array[i]}
		# shellcheck disable=SC2005
		echo "$(center_text "$line" "$maxLen")"
	done
}

pad_multiline() {
	local string="$*"
	local maxLen=$(multiline_length "$string")

	# shellcheck disable=SC2059
	readarray -t array <<<"$(printf "$string")"
	for i in "${!array[@]}"; do
		local line=${array[i]}
		# shellcheck disable=SC2005
		echo "$(rpad_text "$line" "$maxLen")"
	done
}

okdlg() {
	local title=$1
	shift 1
	local msg="$*"
	local lcount=$(echo -e "$msg" | grep -c '^')
	local width=$(multiline_length "$msg")
	whiptail --title "$title" --msgbox "$(center_multiline $((width + 4)) "$msg")" $((lcount + 6)) $((width + 9))
}

confirmdlg() {
	local title=$1
	local btnlabel=$2
	shift 2
	local msg="$*"
	local lcount=$(echo -e "$msg" | grep -c '^')
	local width=$(multiline_length "$msg")
	whiptail --title "$title" --ok-button "$btnlabel" --msgbox "$(center_multiline $((width + 4)) "$msg")" $((lcount + 6)) $((width + 9))
}

yesnodlg() {
	yesnodlg_base "y" "$@"
}

noyesdlg() {
	yesnodlg_base "n" "$@"
}

yesnodlg_base() {
	local defaultbtn=$1
	local title=$2
	local ybtn=$3
	local nbtn=$4
	shift 4
	local msg="$*"
	# shellcheck disable=SC2059
	local linec=$(printf "$msg" | grep -c '^')
	local width=$(multiline_length "$msg")
	local ylen=${#ybtn}
	local nlen=${#nbtn}
	# we need space for all < > around buttons
	local minbtn=$((ylen + nlen + 6))
	# minimal nice width of dialog
	local minlen=$((minbtn > 15 ? minbtn : 15))
	local mwidth=$((minlen > width ? minlen : width))

	# whiptail has bug, buttons are NOT centered
	local rpad=$((width < minbtn ? (nlen - 2) + ((nlen - 2) / 2) : 4))
	local padw=$((mwidth + rpad))

	if [[ "$defaultbtn" == "y" ]]; then
		whiptail --title "$title" --yesno "$(center_multiline $padw "$msg")" \
			--yes-button "$ybtn" --no-button "$nbtn" \
			$((linec + 7)) $((padw + 4))
	else
		whiptail --title "$title" --yesno --defaultno "$(center_multiline $padw "$msg")" \
			--yes-button "$ybtn" --no-button "$nbtn" \
			$((linec + 7)) $((padw + 4))
	fi
}

#=======================================
# VARIABLES
#=======================================

packages=()
aptGetWasUpdated=0
freshInstall=0
cachedMenuDomain=''
lastTimeSpaceInfo=0

MIKRUS_APIKEY=''
MIKRUS_HOST=''

#=======================================
# ACTIONS AND STEPS
#=======================================

check_interactive() {

	shopt -q login_shell && echo 'Login shell' || echo 'Not login shell'

	# if [[ $- == *i* ]]; then
	#   msgok "Interactive setup"
	# else
	#    msgok "Non-interactive setup"
	# fi
}

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

check_ufw() {
	ufw --version >/dev/null 2>&1
	add_if_not_ok "Firewall" "ufw"
}

check_nano() {
	nano --version >/dev/null 2>&1
	add_if_not_ok "Text Editor" "nano"
}

check_dateutils() {
	dateutils.ddiff --version >/dev/null 2>&1
	add_if_not_ok "Date Utils" "dateutils"
}

check_diceware() {
	diceware --version >/dev/null 2>&1
	add_if_not_ok "Secure Password Generator" "diceware"
}

setup_security() {
	if [[ -f $LOG_ENCRYPTION_KEY_FILE ]]; then
		msgok "Found log encryption key"
	else
		ohai "Generating log encryption file..."
		diceware -n 5 -d - >$LOG_ENCRYPTION_KEY_FILE
		msgcheck "Key generated"
	fi
}

setup_packages() {
	# shellcheck disable=SC2145
	# shellcheck disable=SC2068
	(ifIsSet packages && setup_update_repo &&
		ohai "Installing packages: ${packages[@]}" &&
		apt-get -yq install ${packages[@]} >>$LOGTO 2>&1 &&
		msgcheck "Install successfull") || msgok "All required packages already installed"
}

setup_node() {
	test_node
	local RESULT=$?
	if [ $RESULT -eq 0 ]; then
		msgcheck "Node installed in correct version"
	else
		ohai "Cleaning old Node.js"
		{
			rm -f /etc/apt/sources.list.d/nodesource.list
			apt-get -yq --fix-broken install
			apt-get -yq update
			apt-get -yq remove nodejs nodejs-doc libnode*
		} >>$LOGTO 2>&1

		ohai "Preparing Node.js setup"
		curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null 2>&1

		ohai "Installing Node.js"
		apt-get install -y nodejs >>$LOGTO 2>&1

		test_node
		local RECHECK=$?
		if [ $RECHECK -ne 0 ]; then

			msgerr "Nie udało się zainstalować Node.js"

			msgerr "Instalacja Node.js jest skomplikowanym procesem i zależy od wersji systemu Linux i konfiguracji Mikr.us-a"
			msgerr "Spróbuj ręcznie uruchomić instalację poniższą komendą i sprawdź czy pojawiają się błędy (i jakie):"
			msgerr "    apt-get install -y nodejs   "

			exit 1
		fi

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

setup_firewall() {
	ohai "Configuring firewall"

	{
		ufw default deny incoming
		ufw default allow outgoing

		ufw allow OpenSSH
		ufw allow ssh
	} >>$LOGTO 2>&1

	host=$(hostname)
	host=${host:1}

	port1=$((10000 + host))
	port2=$((20000 + host))
	port3=$((30000 + host))

	if ufw allow $port1 >>$LOGTO 2>&1; then
		msgcheck "Do regul firewalla poprawnie dodano port $port1"
	else
		msgerr "Blad dodawania $port1 do regul firewalla"
	fi

	if ufw allow $port2 >>$LOGTO 2>&1; then
		msgcheck "Do regul firewalla poprawnie dodano port $port2"
	else
		msgerr "Blad dodawania $port2 do regul firewalla"
	fi

	if ufw allow $port3 >>$LOGTO 2>&1; then
		msgcheck "Do regul firewalla poprawnie dodano port $port3"
	else
		msgerr "Blad dodawania $port3 do regul firewalla"
	fi

	ufw --force enable >>$LOGTO 2>&1
}

setup_firewall_for_ns() {
	ns_external_port=$(dotenv-tool -r get -f $ENV_FILE_DEP "NS_PORT")
	if ufw allow "$ns_external_port" >>$LOGTO 2>&1; then
		msgcheck "Do regul firewalla poprawnie dodano port Nightscout: $ns_external_port"
	else
		msgerr "Blad dodawania portu Nightscout: $ns_external_port do reguł firewalla"
	fi
}

install_cron() {
	local croncmd="$TOOL_LINK -w > $WATCHDOG_CRON_LOG 2>&1"
	local cronjob="*/5 * * * * $croncmd"
	msgok "Configuring watchdog..."
	(
		crontab -l | grep -v -F "$croncmd" || :
		echo "$cronjob"
	) | crontab -
}

uninstall_cron() {
	local croncmd="nightscout-tool"
	(crontab -l | grep -v -F "$croncmd") | crontab -
}

get_docker_status() {
	local ID=$(docker ps -a --no-trunc --filter name="^$1" --format '{{ .ID }}')
	if [[ "$ID" =~ [0-9a-fA-F]{12,} ]]; then
		docker inspect "$ID" | jq -r ".[0].State.Status"
	else
		echo 'missing'
	fi
}

get_space_info() {
	df -B1 --output=target,size,avail,pcent | tail -n +2 | awk '$1 ~ /^\/$/'
}

install_containers() {
	docker-compose --env-file /srv/nightscout/config/deployment.env -f /srv/nightscout/config/docker-compose.yml up --no-recreate -d >>$LOGTO 2>&1
}

update_containers() {
	docker-compose --env-file /srv/nightscout/config/deployment.env -f /srv/nightscout/config/docker-compose.yml pull >>$LOGTO 2>&1
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
	download_if_not_exists "deployment config" $ENV_FILE_DEP "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/templates/deployment.env"
	download_if_not_exists "nightscout config" $ENV_FILE_NS "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/templates/nightscout.env"
	download_if_not_exists "docker compose file" $DOCKER_COMPOSE_FILE "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/templates/docker-compose.yml"
	download_if_not_exists "profanity database" $PROFANITY_DB_FILE "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/profanity/templates/profanity.db"
	download_if_not_exists "reservation database" $RESERVED_DB_FILE "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/profanity/templates/reserved.db"
}

download_tools() {
	download_if_not_exists "update stamp" "$UPDATES_DIR/updated" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/updated"

	if ! [[ -f $TOOL_FILE ]]; then
		download_if_not_exists "nightscout-tool file" $TOOL_FILE "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/install.sh"
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

	if [ $((timestamp - lastUpdate)) -gt $((60 * 60 * 24)) ] || [ $# -eq 1 ]; then
		echo "$timestamp" >"$UPDATES_DIR/timestamp"
		local onlineUpdated="$(curl -fsSL "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/updated")"
		local lastUpdate=$(cat "$UPDATES_DIR/updated")
		if [ "$onlineUpdated" == "$lastUpdate" ] || [ $# -eq 0 ]; then
			msgok "Scripts and config files are up to date"
			if [ $# -eq 1 ]; then
				whiptail --title "Aktualizacja skryptów" --msgbox "$1" 7 50
			fi
		else
			ohai "Updating scripts and config files"
			curl -fsSL -o "$UPDATES_DIR/install.sh" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/install.sh"
			curl -fsSL -o "$UPDATES_DIR/deployment.env" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/templates/deployment.env"
			curl -fsSL -o "$UPDATES_DIR/nightscout.env" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/templates/nightscout.env"
			curl -fsSL -o "$UPDATES_DIR/docker-compose.yml" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/templates/docker-compose.yml"
			curl -fsSL -o "$PROFANITY_DB_FILE" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/profanity/templates/profanity.db"
			curl -fsSL -o "$RESERVED_DB_FILE" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/profanity/templates/reserved.db"

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
				changed=$((changed + 1))
				msgInst="$(printf "\U1F534") $instLocalVer $(printf "\U27A1") $instOnlineVer"
			fi

			if ! [ "$depEnvLocalVer" == "$depEnvOnlineVer" ]; then
				changed=$((changed + 1))
				redeploy=$((redeploy + 1))
				msgDep="$(printf "\U1F534") $depEnvLocalVer $(printf "\U27A1") $depEnvOnlineVer"
			fi

			if ! [ "$nsEnvLocalVer" == "$nsEnvOnlineVer" ]; then
				changed=$((changed + 1))
				redeploy=$((redeploy + 1))
				msgNs="$(printf "\U1F534") $nsEnvLocalVer $(printf "\U27A1") $nsEnvOnlineVer"
			fi

			if ! [ "$compLocalVer" == "$compOnlineVer" ]; then
				changed=$((changed + 1))
				redeploy=$((redeploy + 1))
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
	LOG_KEY=$(<$LOG_ENCRYPTION_KEY_FILE)
	okdlg "O tym narzędziu..." \
		"$(printf '\U1F9D1') (c) 2023 Dominik Dzienia" \
		"${NL}$(printf '\U1F4E7') dominik.dzienia@gmail.com" \
		"${TL}$(printf '\U1F3DB')  To narzędzie jest dystrybuowane na licencji CC BY-NC-ND 4.0" \
		"${NL}htps://creativecommons.org/licenses/by-nc-nd/4.0/deed.pl" \
		"${TL}wersja: $SCRIPT_VERSION ($SCRIPT_BUILD_TIME) $UPDATE_CHANNEL" \
		"${TL}hasło do logów: $LOG_KEY"
}

prompt_welcome() {
	yesnodlg "Witamy" "$uni_start" "$uni_exit" \
		"Ten skrypt zainstaluje Nightscout na bieżącym serwerze mikr.us" \
		"${TL}Jeśli na tym serwerze jest już Nightscout " \
		"${NL}- ten skrypt umożliwia jego aktualizację oraz diagnostykę.${TL}"
	exit_on_no_cancel
}
prompt_disclaimer() {
	confirmdlg "Ostrzeżenie!" \
		"Zrozumiano!" \
		"Te narzędzie pozwala TOBIE zainstalować WŁASNĄ instancję Nightscout." \
		"${NL}Ty odpowiadasz za ten serwer i ewentualne skutki jego używania." \
		"${NL}Ty nim zarządzasz, to nie jest usługa czy produkt." \
		"${NL}To rozwiązanie \"Zrób to sam\" - SAM za nie odpowiadasz!" \
		"${TL}Autorzy skryptu nie ponoszą odpowiedzialności za skutki jego użycia!" \
		"${NL}Nie dajemy żadnych gwarancji co do jego poprawności czy dostępności!" \
		"${NL}Używasz go na własną odpowiedzialność!" \
		"${NL}Nie opieraj decyzji terapeutycznych na podstawie wskazań tego narzędzia!" \
		"${TL}Twórcy tego narzędzia NIE SĄ administratorami Mikr.us-ów ani Hetznera!" \
		"${NL}W razie problemów z dostępnością serwera najpierw sprawdź status Mikr.us-a!"
}

instal_now_prompt() {
	yesnodlg "Instalować Nightscout?" "$uni_install" "$uni_noenter" \
		"Wykryto konfigurację ale brak uruchomionych usług" \
		"${NL}Czy chcesz zainstalować teraz kontenery Nightscout?"
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
		freshInstall=$((freshInstall + 1))

		if [ -f "/klucz_api" ]; then
			MIKRUS_APIKEY=$(cat "/klucz_api")
			MIKRUS_INFO_HOST=$(curl -s -d "srv=$MIKRUS_HOST&key=$MIKRUS_APIKEY" -X POST https://api.mikr.us/info | jq -r .server_id)

			if [[ "$MIKRUS_INFO_HOST" == "$MIKRUS_HOST" ]]; then
				msgcheck "Mikrus OK"
			else
				MIKRUS_APIKEY=""
			fi
		fi

		if ! [[ "$MIKRUS_APIKEY" =~ [0-9a-fA-F]{40} ]]; then

			whiptail --title "Przygotuj klucz API" --msgbox "Do zarządzania mikrusem [$MIKRUS_HOST] potrzebujemy klucz API.\n\n${uni_bullet}otwórz nową zakładkę w przeglądarce,\n${uni_bullet}wejdź do panelu administracyjnego swojego Mikr.us-a,\n${uni_bullet}otwórz sekcję API, pod adresem:\n\n${uni_bullet_pad}https://mikr.us/panel/?a=api\n\n${uni_bullet}skopiuj do schowka wartość klucza API" 16 70
			exit_on_no_cancel

			while :; do
				MIKRUS_APIKEY=$(whiptail --title "Podaj klucz API" --passwordbox "\nWpisz klucz API. Jeśli masz go skopiowanego w schowku,\nkliknij prawym przyciskiem i wybierz <wklej> z menu:" --cancel-button "Anuluj" 11 65 3>&1 1>&2 2>&3)
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

		ohai "Updating admin config (api key)"
		dotenv-tool -pmr -i $ENV_FILE_ADMIN -- "MIKRUS_APIKEY=$MIKRUS_APIKEY"
	fi
}

prompt_api_secret() {
	API_SECRET=$(dotenv-tool -r get -f $ENV_FILE_NS "API_SECRET")

	if ! [[ "$API_SECRET" =~ [a-zA-Z0-9%+=./:=@_]{12,} ]]; then
		freshInstall=$((freshInstall + 1))
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
					API_SECRET=$(whiptail --title "Podaj API SECRET" --passwordbox "\nWpisz API SECRET do serwera Nightscout:\n${uni_bullet}Upewnij się że masz go zapisanego np.: w managerze haseł\n${uni_bullet}Użyj conajmniej 12 znaków: małych i dużych liter i cyfr\n\n" --cancel-button "Anuluj" 12 75 3>&1 1>&2 2>&3)

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
				API_SECRET_CHECK=$(whiptail --title "Podaj ponownie API SECRET" --passwordbox "\nDla sprawdzenia, wpisz ustalony przed chwilą API SECRET\n\n" --cancel-button "Anuluj" 11 65 3>&1 1>&2 2>&3)
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
	process_gauge install_containers install_containers_progress "Uruchamianie Nightscouta" "Proszę czekać, trwa uruchamianie kontenerów..."
}

docker_compose_update() {
	process_gauge update_containers install_containers_progress "Uruchamianie Nightscouta" "Proszę czekać, trwa aktualizacja kontenerów..."
}

docker_compose_down() {
	process_gauge uninstall_containers uninstall_containers_progress "Zatrzymywanie Nightscouta" "Proszę czekać, trwa zatrzymywanie i usuwanie kontenerów..."
}

domain_setup_manual() {
	ns_external_port=$(dotenv-tool -r get -f $ENV_FILE_DEP "NS_PORT")
	whiptail --title "Ustaw domenę" --msgbox "Aby Nightscout był widoczny z internetu ustaw subdomenę:\n\n${uni_bullet}otwórz nową zakładkę w przeglądarce,\n${uni_bullet}wejdź do panelu administracyjnego swojego Mikr.us-a,\n${uni_bullet}otwórz sekcję [Subdomeny], pod adresem:\n\n${uni_bullet_pad}   https://mikr.us/panel/?a=domain\n\n${uni_bullet}w pole nazwy wpisz dowolną własną nazwę\n${uni_bullet_pad}(tylko małe litery i cyfry, max. 12 znaków)\n${uni_bullet}w pole numer portu wpisz:\n${uni_bullet_pad}\n                                $ns_external_port\n\n${uni_bullet}kliknij [Dodaj subdomenę] i poczekaj do kilku minut" 22 75
}

domain_setup() {

	local domain=$(get_td_domain)
	local domainLen=${#domain}
	if ((domainLen > 15)); then
		msgcheck "Subdomena jest już skonfigurowana ($domain)"
		okdlg "Subdomena już ustawiona" \
			"Wykryto poprzednio skonfigurowaną subdomenę:" \
			"${TL}$domain" \
			"${TL}Strona Nightscout powinna być widoczna z internetu."
		return
	fi

	ns_external_port=$(dotenv-tool -r get -f $ENV_FILE_DEP "NS_PORT")
	whiptail --title "Ustaw subdomenę" --msgbox "Aby Nightscout był widoczny z internetu ustaw adres - subdomenę:\n\n                      [wybierz].ns.techdiab.pl\n\nWybrany początek subdomeny powinien:\n${uni_bullet}mieć długość od 4 do 12 znaków\n${uni_bullet}zaczynać się z małej litery,\n${uni_bullet}może składać się z małych liter i cyfr\n${uni_bullet}być unikalny, charakterystyczny i łatwa do zapamiętania" 16 75

	while :; do
		SUBDOMAIN=''
		while :; do
			SUBDOMAIN=$(whiptail --title "Podaj początek subdomeny" --inputbox "\n(4-12 znaków, tylko: małe litery i cyfry)\n\n" --cancel-button "Anuluj" 12 60 3>&1 1>&2 2>&3)

			if [ $? -eq 1 ]; then
				break
			fi

			if [[ "$SUBDOMAIN" =~ ^[a-z][a-z0-9]{3,11}$ ]]; then

				if printf "%s" "$SUBDOMAIN" | grep -f "$PROFANITY_DB_FILE" >>$LOGTO 2>&1; then
					okdlg "$uni_excl Nieprawidłowa subdomena $uni_excl" \
						"Podana wartość:" \
						"${NL}$SUBDOMAIN" \
						"${TL}jest zajęta, zarezerwowana lub niedopuszczalna." \
						"${TL}Wymyśl coś innego"
					SUBDOMAIN=''
					continue
				fi

				if printf "%s" "$SUBDOMAIN" | grep -xf "$RESERVED_DB_FILE" >>$LOGTO 2>&1; then
					okdlg "$uni_excl Nieprawidłowa subdomena $uni_excl" \
						"Podana wartość:" \
						"${NL}$SUBDOMAIN" \
						"${TL}jest zajęta lub zarezerwowana." \
						"${TL}Wymyśl coś innego"
					SUBDOMAIN=''
					continue
				fi

				break

			else
				okdlg "$uni_excl Nieprawidłowy początek subdomeny $uni_excl" \
					"Podany początek subdomeny:" \
					"${NL}$SUBDOMAIN" \
					"${TL}ma nieprawidłowy format. Wymyśl coś innego"
				if [ $? -eq 1 ]; then
					SUBDOMAIN=''
					continue
				fi
			fi

		done

		if [ "$SUBDOMAIN" == "" ]; then
			domain_setup_manual
			break
		fi

		local MHOST=$(hostname)
		local APISEC=$(dotenv-tool -r get -f $ENV_FILE_ADMIN "MIKRUS_APIKEY")

		ohai "Rejestrowanie subdomeny $SUBDOMAIN.ns.techdiab.pl"
		local REGSTATUS=$(curl -sd "srv=$MHOST&key=$APISEC&domain=$SUBDOMAIN.ns.techdiab.pl" https://api.mikr.us/domain)
		local STATOK=$(echo "$REGSTATUS" | jq -r ".status")
		local STATERR=$(echo "$REGSTATUS" | jq -r ".error")

		if ! [ "$STATOK" == "null" ]; then
			msgcheck "Subdomena ustawiona poprawnie ($STATOK)"
			okdlg "Subdomena ustawiona" \
				"Ustawiono subdomenę:\n\n$SUBDOMAIN.ns.techdiab.pl\n($STATOK)\n\nZa kilka minut strona będzie widoczna z internetu."
			break
		else
			msgerr "Nie udało się ustawić subdomeny ($STATERR)"
			whiptail --title "$uni_excl Błąd rezerwacji domeny $uni_excl" --yesno "Nie udało się zarezerwować subdomeny:\n    $STATERR\n\nChcesz podać inną subdomenę?" --yes-button "$uni_reenter" --no-button "$uni_noenter" 10 73
			if [ $? -eq 1 ]; then
				SUBDOMAIN=''
				domain_setup_manual
				break
			fi
		fi
	done

}

admin_panel_promo() {
	whiptail --title "Panel zarządzania Mikr.us-em" --msgbox "$(center_multiline 70 \
		"Ta instalacja Nightscout dodaje dodatkowy panel administracyjny" \
		"${NL}do zarządzania serwerem i konfiguracją - online." \
		"${TL}Znajdziesz go klikając na ikonkę serwera w menu strony Nightscout" \
		"${NL}lub dodając /mikrus na końcu swojego adresu Nightscout")" \
		12 75
}

get_watchdog_age_string() {
	local last_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	local curr_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

	if [[ -f $WATCHDOG_TIME_FILE ]]; then
		last_time=$(cat $WATCHDOG_TIME_FILE)
		local status_ago=$(dateutils.ddiff "$last_time" "$curr_time" -f '%Mmin. %Ssek.')
		echo "$last_time ($status_ago temu)"
	else
		echo "jescze nie uruchomiony"
	fi
}

get_watchdog_status_code() {
	local curr_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	local last_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	local status="unknown"

	if [[ -f $WATCHDOG_TIME_FILE ]]; then
		last_time=$(cat $WATCHDOG_TIME_FILE)
	fi

	if [[ -f $WATCHDOG_STATUS_FILE ]]; then
		status=$(cat $WATCHDOG_STATUS_FILE)
	fi

	local status_ago=$(dateutils.ddiff "$curr_time" "$last_time" -f '%S')

	if [ "$status_ago" -gt 900 ]; then
		status="unknown"
	fi

	echo "$status"
}

get_watchdog_status_code_live() {
	local curr_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	local last_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	local status="unknown"

	if [[ -f $WATCHDOG_TIME_FILE ]]; then
		last_time=$(cat $WATCHDOG_TIME_FILE)
	fi

	if [[ -f $WATCHDOG_STATUS_FILE ]]; then
		status=$(cat $WATCHDOG_STATUS_FILE)
	fi

	local status_ago=$(dateutils.ddiff "$curr_time" "$last_time" -f '%S')

	if [ "$status_ago" -gt 900 ]; then
		status="unknown"
	fi

	local NS_STATUS=$(get_container_status_code 'ns-server')
	local DB_STATUS=$(get_container_status_code 'ns-database')
	local COMBINED_STATUS="$NS_STATUS $DB_STATUS"

	if [ "$COMBINED_STATUS" = "running running" ]; then

		status="detection_failed"

		local domain=$cachedMenuDomain
		local cachedDomainLen=${#cachedMenuDomain}
		if ((cachedDomainLen < 16)); then
			domain=$(get_td_domain)
		fi

		local domainLen=${#domain}
		if ((domainLen > 15)); then
			cachedMenuDomain=$domain
			local html=$(curl -Lks "$domain")

			if [[ "$html" =~ github.com/nightscout/cgm-remote-monitor ]]; then
				status="ok"
			fi

			if [[ "$html" =~ 'MongoDB connection failed' ]]; then
				status="crashed"
			fi

			regex3='MIKR.US - coś poszło nie tak'
			if [[ "$html" =~ $regex3 ]]; then
				status="restarting"
			fi

		else
			status="domain_failed"
		fi

	else
		if [ "$NS_STATUS" = "restarting" ] || [ "$DB_STATUS" = "restarting" ]; then
			status="restarting"
		else
			status="not_running"
		fi
	fi

	echo "$status"
}

get_watchdog_status() {
	local status="$1"
	case "$status" in
	"ok")
		echo "$2"
		;;
	"restart")
		printf "\U1F680 wymuszono restart NS"
		;;
	"restarting")
		printf "\U23F3 uruchamia się"
		;;
	"unknown")
		printf "\U1F4A4 brak statusu"
		;;
	"not_running")
		printf "\U1F534 serwer nie działa"
		;;
	"detection_failed")
		printf "\U2753 nieznany stan"
		;;
	"domain_failed")
		printf "\U2753 problem z domeną"
		;;
	"crashed")
		printf "\U1F4A5 awaria NS"
		;;
	esac

}

show_watchdog_logs() {
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

	local tmpfile=$(mktemp)
	{
		echo "Ostatnie uruchomienie watchdoga:"
		get_watchdog_age_string
		echo "-------------------------------------------------------"

		if [[ -f $WATCHDOG_LOG_FILE ]]; then
			echo "Statusy ostatnich przebiegów watchdoga:"
			tail -5 "$WATCHDOG_LOG_FILE"
		else
			echo "Brak logów z ostatnich przebiegów watchdoga"
		fi
		echo "-------------------------------------------------------"

		if [[ -f $WATCHDOG_CRON_LOG ]]; then
			echo "Log ostatniego przebiegu watchdoga:"
			cat "$WATCHDOG_CRON_LOG"
		fi
	} >"$tmpfile"

	whiptail --title "Logi Watchdoga" --scrolltext --textbox "$tmpfile" $rws $col
	rm "$tmpfile"
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

get_container_status_code() {
	local ID=$(docker ps -a --no-trunc --filter name="^$1$" --format '{{ .ID }}')
	if [[ "$ID" =~ [0-9a-fA-F]{12,} ]]; then
		local status=$(docker inspect "$ID" | jq -r ".[0].State.Status")
		echo "$status"
	else
		echo "unknown"
	fi
}

show_logs() {
	local col=$((COLUMNS - 10))
	local rws=$((LINES - 4))
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
		local CHOICE=$(whiptail --title "Status kontenerów" --menu "\n  Aktualizacja: kontenery na żywo, watchdog co 5 minut\n\n        Wybierz pozycję aby zobaczyć logi:\n" 17 60 5 \
			"1)" "   Nightscout:  $(get_container_status 'ns-server')" \
			"2)" "  Baza danych:  $(get_container_status 'ns-database')" \
			"3)" "       Backup:  $(get_container_status 'ns-backup')" \
			"4)" "     Watchdog:  $(get_watchdog_status "$(get_watchdog_status_code)" "$uni_watchdog_ok")" \
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
		"4)")
			show_watchdog_logs
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

version_menu() {

	local tags=$(wget -q -O - "https://hub.docker.com/v2/namespaces/nightscout/repositories/cgm-remote-monitor/tags?page_size=100" | jq -r ".results[].name" | sed "/dev_[a-f0-9]*/d" | sort --version-sort -u -r | head -n 8)

	while :; do

		local ns_tag=$(dotenv-tool -r get -f $ENV_FILE_DEP "NS_NIGHTSCOUT_TAG")
		local versions=()

		while read -r line; do
			if [ "$line" == "$ns_tag" ]; then
				continue
			fi

			label=" - na sztywno $line "

			if [ "$line" == "latest_dev" ]; then
				label=" - najnowsza wersja rozwojowa "
			fi

			if [ "$line" == "latest" ]; then
				label=" - aktualna wersja stabilna "
			fi

			versions+=("$line")
			versions+=("$label")
		done <<<"$tags"

		versions+=("M)")
		versions+=("   Powrót do poprzedniego menu")

		local CHOICE=$(whiptail --title "Wersja Nightscout" --menu "\nZmień wersję kontenera Nightscout z: $ns_tag na:\n\n" 20 60 10 \
			"${versions[@]}" \
			--ok-button="Zmień" --cancel-button="$uni_back" \
			3>&2 2>&1 1>&3)

		if [ "$CHOICE" == "M)" ]; then
			break
		fi

		if [ "$CHOICE" == "" ]; then
			break
		fi

		if [ "$CHOICE" == "$ns_tag" ]; then
			whiptail --title "Ta sama wersja!" --msgbox "Wybrano bieżącą wersję - brak zmiany" 7 50
		else

			whiptail --title "Zmienić wersję Nightscout?" --yesno --defaultno "Czy na pewno chcesz zmienić wersję z: $ns_tag na: $CHOICE?\n\n${uni_bullet}dane i konfiguracja NIE SĄ usuwane\n${uni_bullet}wersję można łatwo zmienić ponownie\n${uni_bullet}dane w bazie danych mogą ulec zmianie i NIE BYĆ kompatybilne" --yes-button "$uni_confirm_ch" --no-button "$uni_resign" 13 73
			if ! [ $? -eq 1 ]; then
				docker_compose_down
				ohai "Changing Nightscout container tag from: $ns_tag to: $CHOICE"
				dotenv-tool -pmr -i $ENV_FILE_DEP -- "NS_NIGHTSCOUT_TAG=$CHOICE"
				docker_compose_update
				whiptail --title "Zmieniono wersję Nightscout" --msgbox "$(center_multiline 65 \
					"Zmieniono wersję Nightscout na: $CHOICE" \
					"${TL}Sprawdź czy Nightscout działa poprawnie, w razie problemów:" \
					"${NL}${uni_bullet}aktualizuj kontenery" \
					"${NL}${uni_bullet}spróbuj wyczyścić bazę danych" \
					"${NL}${uni_bullet}wróć do poprzedniej wersji ($ns_tag)")" \
					13 70
				break
			fi

		fi

	done
}

do_cleanup_sys() {
	ohai "Sprzątanie dziennik systemowego..."
	journalctl --vacuum-size=50M >>$LOGTO 2>&1
	ohai "Czyszczenie systemu apt..."
  msgnote "Ta operacja może TROCHĘ potrwać (od kilku do kilkudziesięciu minut...)"
  apt-get -y autoremove >>$LOGTO 2>&1 && apt-get -y clean >>$LOGTO 2>&1
  msgcheck "Czyszczenie dziennika i apt zakończono"
}

do_cleanup_docker() {
	ohai "Usuwanie nieużywanych obrazów Dockera..."
  msgnote "Ta operacja może TROCHĘ potrwać (do kilku minut...)"
	docker image prune -af >>$LOGTO 2>&1
  msgcheck "Czyszczenie Dockera zakończono"
}

do_cleanup_db() {
	ohai "Usuwanie kopii zapasowych bazy danych..."
  find /srv/nightscout/data/dbbackup ! -type d -delete
  msgcheck "Czyszczenie kopii zapasowych zakończono"
}

cleanup_menu() {

	while :; do

		local spaceInfo=$(get_space_info)
		local remainingTxt=$(echo "$spaceInfo" | awk '{print $3}' | numfmt --to iec-i --suffix=B)
		local totalTxt=$(echo "$spaceInfo" | awk '{print $2}' | numfmt --to iec-i --suffix=B)
		local percTxt=$(echo "$spaceInfo" | awk '{print $4}')
		local fixedPerc=${percTxt/[%]/=}

		local nowB=$(echo "$spaceInfo" | awk '{print $3}')
		local lastTimeB=$(echo "$lastTimeSpaceInfo" | awk '{print $3}')
		local savedB=$((nowB - lastTimeB))
		local savedTxt=$(echo "$savedB" | numfmt --to iec-i --suffix=B)

    if (( savedB < 1)); then
			savedTxt="---"
		fi

		local statusTitle="\n$(center_multiline 45 "$(
			pad_multiline \
				"  Dostępne: ${remainingTxt}" \
				"\n Zwolniono: ${savedTxt}" \
				"\n    Zajęte: ${fixedPerc} (z ${totalTxt})"
		)")\n"

		local CHOICE=$(whiptail --title "Sprzątanie" --menu \
			"${statusTitle/=/%}" \
			16 50 5 \
			"A)" "Posprzątaj wszystko" \
			"S)" "Posprzątaj zasoby systemowe" \
			"D)" "Usuń nieużywane obrazy Dockera" \
			"B)" "Usuń kopie zapasowe bazy danych" \
			"M)" "Powrót do menu" \
			--ok-button="Wybierz" --cancel-button="$uni_back" \
			3>&2 2>&1 1>&3)

		case $CHOICE in
		"A)")
			noyesdlg "Posprzątać wszystko?" "$uni_confirm_del" "$uni_resign" \
				"Czy chcesz posprzątać i usunąć:" \
				"$(pad_multiline \
						"${NL}${uni_bullet}nieużywane pliki apt i dziennika" \
						"${NL}${uni_bullet}nieużywane obrazy Dockera" \
						"${NL} ${uni_bullet}kopie zapasowe bazy danych")" \
        "${TL}(ta operacja może potrwać od kilku do kilkudziesięciu minut)"
			if ! [ $? -eq 1 ]; then
				do_cleanup_sys
				do_cleanup_docker
				do_cleanup_db
			fi
			;;
		"S)")
			noyesdlg "Posprzątać zasoby systemowe?" "$uni_confirm_del" "$uni_resign" \
				"Czy chcesz usunąć nieużywane pakiety apt i poprzątać dziennik systemowy?" \
        "${TL}(ta operacja może potrwać od kilku do kilkudziesięciu minut)"
			if ! [ $? -eq 1 ]; then
				do_cleanup_sys
			fi
			;;
		"D)")
			noyesdlg "Posprzątać obrazy Dockera?" "$uni_confirm_del" "$uni_resign" \
				"Czy chcesz usunąć nieużywane obrazy Dockera?" \
        "${TL}(ta operacja może potrwać kilka minut)"
			if ! [ $? -eq 1 ]; then
				do_cleanup_docker
			fi
			;;
		"B)")
			noyesdlg "Usunąć kopie zapasowe bazy danych?" "$uni_confirm_del" "$uni_resign" \
				"Czy chcesz usunąć kopie zapasowe bazy danych?" \
				"${NL}(na razie i tak nie ma automatycznego mechanizmu ich wykorzystania)"
			if ! [ $? -eq 1 ]; then
				do_cleanup_db
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

update_menu() {
	while :; do
		local CHOICE=$(whiptail --title "Aktualizuj" --menu "\n" 11 40 4 \
			"S)" "Aktualizuj system" \
			"N)" "Aktualizuj to narzędzie" \
			"K)" "Aktualizuj kontenery" \
			"M)" "Powrót do menu" \
			--ok-button="$uni_select" --cancel-button="$uni_back" \
			3>&2 2>&1 1>&3)

		case $CHOICE in
		"S)")
			ohai "Updating package list"
			dialog --title " Aktualizacja systemu " --infobox "\n  Pobieranie listy pakietów\n  ..... Proszę czekać ....." 6 33
			apt-get -yq update >>$LOGTO 2>&1
			ohai "Upgrading system"
			dialog --title " Aktualizacja systemu " --infobox "\n    Instalowanie pakietów\n     ... Proszę czekać ..." 6 33
			apt-get -yq upgrade >>$LOGTO 2>&1
			;;
		"N)")
			update_if_needed "Wszystkie pliki narzędzia są aktualne"
			;;
		"K)")
			docker_compose_down
			docker_compose_update
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
	while :; do
		local extraMenu=()
		extraMenu+=("A)" "Ustaw adres strony (subdomenę)")
		local ns_tag=$(dotenv-tool -r get -f $ENV_FILE_DEP "NS_NIGHTSCOUT_TAG")
		local CHOICE=$(whiptail --title "Zmień lub odinstaluj Nightscout" --menu "\n" 17 70 8 \
			"${extraMenu[@]}" \
			"W)" "Zmień wersję Nightscouta (bieżąca: $ns_tag)" \
			"E)" "Edytuj ustawienia (zmienne środowiskowe)" \
			"K)" "Usuń kontenery" \
			"B)" "Wyczyść bazę danych" \
			"D)" "Usuń kontenery, dane i konfigurację" \
			"U)" "Usuń wszystko - odinstaluj" \
			"M)" "Powrót do menu" \
			--ok-button="$uni_select" --cancel-button="$uni_back" \
			3>&2 2>&1 1>&3)

		case $CHOICE in
		"A)")
			domain_setup
			;;
		"W)")
			version_menu
			;;
		"E)")

			if ! [[ "$0" =~ .*"/usr/bin/nightscout-tool" ]]; then
				okdlg "Opcja niedostępna" \
					"Edytor ustawień dostępny po uruchomieniu narzędzia komendą:" \
					"${TL}nightscout-tool"
			else
				whiptail --title "Edycja ustawień Nightscout" --yesno "Za chwilę otworzę plik konfiguracji Nightscout w edytorze NANO\n\nWskazówki co do obsługi edytora:\n${uni_bullet}Aby ZAPISAĆ zmiany naciśnij Ctrl+O\n${uni_bullet}Aby ZAKOŃCZYĆ edycję naciśnij Ctrl+X\n\n $(printf "\U26A0") Edycja spowoduje też restart i aktualizację kontenerów $(printf "\U26A0")" --yes-button "$uni_confirm_ed" --no-button "$uni_resign" 15 68
				if ! [ $? -eq 1 ]; then
					nano $ENV_FILE_NS
					docker_compose_down
					docker_compose_update
				fi
			fi
			;;
		"K)")
			whiptail --title "Usunąć kontenery?" --yesno --defaultno "Czy na pewno chcesz usunąć kontenery powiązane z Nightscout?\n\n${uni_bullet}dane i konfiguracja NIE SĄ usuwane\n${uni_bullet}kontenery można łatwo odzyskać (opcja Aktualizuj kontenery)" --yes-button "$uni_confirm_del" --no-button "$uni_resign" 11 73
			if ! [ $? -eq 1 ]; then
				docker_compose_down
			fi
			;;
		"B)")
			whiptail --title "Usunąć dane z bazy danych?" --yesno --defaultno "Czy na pewno chcesz usunąć dane z bazy danych?\n\n${uni_bullet}konfiguracja serwera NIE ZOSTANIE usunięta\n${uni_bullet}usunięte zostaną wszystkie dane użytkownika\n${uni_bullet_pad}  (m.in. historia glikemii, wpisy, notatki, pomiary, profile)\n${uni_bullet}kontenery zostaną zatrzymane i uruchomione ponownie (zaktualizowane)" --yes-button "$uni_confirm_del" --no-button "$uni_resign" 13 78
			if ! [ $? -eq 1 ]; then
				docker_compose_down
				dialog --title " Czyszczenie bazy danych " --infobox "\n    Usuwanie plików bazy\n   ... Proszę czekać ..." 6 32
				rm -r "${MONGO_DB_DIR:?}/data"
				docker_compose_update
			fi
			;;
		"D)")
			whiptail --title "Usunąć wszystkie dane?" --yesno --defaultno "Czy na pewno chcesz usunąć wszystkie dane i konfigurację?\n\n${uni_bullet}konfigurację panelu, ustawienia Nightscout\n${uni_bullet}wszystkie dane użytkownika\n${uni_bullet_pad}  (m.in. historia glikemii, wpisy, notatki, pomiary, profile)\n${uni_bullet}kontenery zostaną zatrzymane" --yes-button "$uni_confirm_del" --no-button "$uni_resign" 13 78
			if ! [ $? -eq 1 ]; then
				docker_compose_down
				dialog --title " Czyszczenie bazy danych" --infobox "\n    Usuwanie plików bazy\n   ... Proszę czekać ..." 6 32
				rm -r "${MONGO_DB_DIR:?}/data"
				dialog --title " Czyszczenie konfiguracji" --infobox "\n    Usuwanie konfiguracji\n   ... Proszę czekać ..." 6 32
				rm -r "${CONFIG_ROOT_DIR:?}"
				whiptail --title "Usunięto dane użytkownika" --msgbox "$(center_multiline 65 \
					"Usunęto dane użytkwnika i konfigurację." \
					"${TL}Aby zainstalować Nightscout od zera:" \
					"${NL}uruchom ponownie skrypt i podaj konfigurację")" \
					11 70
				exit 0
			fi
			;;
		"U)")
			whiptail --title "Odinstalować?" --yesno --defaultno "Czy na pewno chcesz usunąć wszystko?\n${uni_bullet}konfigurację panelu, ustawienia Nightscout\n${uni_bullet}wszystkie dane użytkownika (glikemia, status, profile)\n${uni_bullet}kontenery, skrypt nightscout-tool\n\nNIE ZOSTANĄ USUNIĘTE/ODINSTALOWANE:\n${uni_bullet}użytkownik mongo db, firewall, doinstalowane pakiety\n${uni_bullet}kopie zapasowe bazy danych" --yes-button "$uni_confirm_del" --no-button "$uni_resign" 16 78
			if ! [ $? -eq 1 ]; then
				docker_compose_down
				dialog --title " Odinstalowanie" --infobox "\n      Usuwanie plików\n   ... Proszę czekać ..." 6 32
				uninstall_cron
				rm -r "${MONGO_DB_DIR:?}/data"
				rm -r "${CONFIG_ROOT_DIR:?}"
				rm "$TOOL_LINK"
				rm -r "${NIGHTSCOUT_ROOT_DIR:?}/tools"
				rm -r "${NIGHTSCOUT_ROOT_DIR:?}/updates"
				whiptail --title "Odinstalowano" --msgbox "$(center_multiline 65 \
					"Odinstalowano Nightscout z Mikr.us-a" \
					"${TL}Aby ponownie zainstalować, postępuj według instrukcji na stronie:" \
					"${NL}https://t1d.dzienia.pl/mikrus" \
					"${TL}Dziękujemy i do zobaczenia!")" \
					13 70
				exit 0
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

get_td_domain() {
	local MHOST=$(hostname)
	local APIKEY=$(dotenv-tool -r get -f $ENV_FILE_ADMIN "MIKRUS_APIKEY")
	curl -sd "srv=$MHOST&key=$APIKEY" https://api.mikr.us/domain | jq -r ".[].name" | grep ".ns.techdiab.pl" | head -n 1
}

get_domain_status() {
	local domain=$(get_td_domain)
	local domainLen=${#domain}
	if ((domainLen > 15)); then
		printf "\U1F7E2 %s" "$domain"
	else
		printf "\U26AA nie zarejestrowano"
	fi
}

send_diagnostics() {
	LOG_KEY=$(<$LOG_ENCRYPTION_KEY_FILE)

	yesnodlg "Wysyłać diagnostykę?" \
		"$uni_send" "$uni_resign" \
		"Czy chcesz zgromadzić i wysłać sobie mailem dane diagnostyczne?" \
		"\n$(
			pad_multiline \
				"\n${uni_bullet}diagnostyka zawiera logi i informacje o serwerze i usługach" \
				"\n${uni_bullet}wysyłka na e-mail na który zamówiono serwer Mikr.us" \
				"\n${uni_bullet}dane będą skompresowane i zaszyfrowane" \
				"\n${uni_bullet}maila prześlij dalej do zaufanej osoby wspierającej" \
				"\n${uni_bullet_pad}(z którą to wcześniej zaplanowano i uzgodniono!!!)" \
				"\n${uni_bullet}hasło przekaż INNĄ DROGĄ (komunikatorem, SMSem, osobiście)" \
				"\n\n${uni_bullet_pad}Hasło do logów: $LOG_KEY"
		)"

	if ! [ $? -eq 1 ]; then

		ohai "Zbieranie diagnostyki"

		local domain=$(get_td_domain)
		local curr_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
		local ns_tag=$(dotenv-tool -r get -f $ENV_FILE_DEP "NS_NIGHTSCOUT_TAG")
		local mikrus_h=$(hostname)

		local LOG_DIVIDER="======================================================="

		rm -f $SUPPORT_LOG
		rm -f "$SUPPORT_LOG.gz"
		rm -f "$SUPPORT_LOG.gz.asc"

		{
			echo "Dane diagnostyczne zebrane $curr_time"
			echo "    serwer : $mikrus_h"
			echo "    domena : $domain"
			echo " wersja NS : $ns_tag"
		} >$SUPPORT_LOG

		ohai "Zbieranie statusu usług"

		{
			echo "$LOG_DIVIDER"
			echo " Statusy usług"
			echo "$LOG_DIVIDER"
			echo "   Nightscout:  $(get_container_status 'ns-server')"
			echo "  Baza danych:  $(get_container_status 'ns-database')"
			echo "       Backup:  $(get_container_status 'ns-backup')"
			echo "     Watchdog:  $(get_watchdog_status "$(get_watchdog_status_code)" "$uni_watchdog_ok")"
		} >>$SUPPORT_LOG

		ohai "Zbieranie informacji o zasobach"
		local spaceInfo=$(get_space_info)
		local remainingTxt=$(echo "$spaceInfo" | awk '{print $3}' | numfmt --to iec-i --suffix=B)
		local totalTxt=$(echo "$spaceInfo" | awk '{print $2}' | numfmt --to iec-i --suffix=B)
		local percTxt=$(echo "$spaceInfo" | awk '{print $4}')

		{
			echo "$LOG_DIVIDER"
			echo " Miejsce na dysku"
			echo "$LOG_DIVIDER"
			echo "  Dostępne: ${remainingTxt}"
			echo "    Zajęte: ${percTxt} (z ${totalTxt})"
		} >>$SUPPORT_LOG

		ohai "Zbieranie logów watchdoga"

		if [[ -f $WATCHDOG_LOG_FILE ]]; then
			{
				echo "$LOG_DIVIDER"
				echo " Watchdog log"
				echo "$LOG_DIVIDER"
				timeout -k 15 10 cat $WATCHDOG_LOG_FILE
			} >>$SUPPORT_LOG
		fi

		if [[ -f $WATCHDOG_FAILURES_FILE ]]; then
			{
				echo "$LOG_DIVIDER"
				echo " Watchdog failures log"
				echo "$LOG_DIVIDER"
				timeout -k 15 10 cat $WATCHDOG_FAILURES_FILE
			} >>$SUPPORT_LOG
		fi

		ohai "Zbieranie logów usług"

		{
			echo "$LOG_DIVIDER"
			echo " Nightscout log"
			echo "$LOG_DIVIDER"
			timeout -k 15 10 docker logs ns-server --tail 500 >>$SUPPORT_LOG 2>&1
			echo "$LOG_DIVIDER"
			echo " MongoDB database log"
			echo "$LOG_DIVIDER"
			timeout -k 15 10 docker logs ns-database --tail 100 >>$SUPPORT_LOG 2>&1
		} >>$SUPPORT_LOG

		ohai "Kompresowanie i szyfrowanie raportu"

		gzip $SUPPORT_LOG

		local logkey=$(<$LOG_ENCRYPTION_KEY_FILE)

		gpg --passphrase "$logkey" --batch --quiet --yes -a -c "$SUPPORT_LOG.gz"

		ohai "Wysyłanie maila"

		{
			echo "Ta wiadomość zawiera poufne dane diagnostyczne Twojego serwera Nightscout."
			echo "Mogą one pomóc Tobie lub zaufanej osobie w identyfikacji problemu."
			echo " "
			echo "Prześlij ten mail dalej do zaufanej osoby, umówionej na udzielenie wsparcia."
			echo "Przekaż tej osobie w bezpieczny sposób hasło szyfrowania"
			echo "  (w narzędziu nightscout-tool można je znaleźć w pozycji 'O tym narzędziu...')."
			echo "Do przekazania hasła użyj INNEJ metody (komunikator, SMS, osobiście...)."
			echo "Nie przesyłaj tej wiadomości do administratorów grupy lub serwera bez wcześniejszego uzgodnienia!"
			echo " "
			echo "Instrukcje i narzędzie do odszyfrowania logów dostępne pod adresem: https://t1d.dzienia.pl/decoder/"
			echo " "
			echo " "
			cat "$SUPPORT_LOG.gz.asc"
		} | pusher "Diagnostyka_serwera_Nightscout_-_$curr_time"

		okdlg "Diagnostyka wysłana" \
			"Sprawdź swoją skrzynkę pocztową,\n" \
			"otrzymanego maila przekaż zaufanemu wspierającemu.\n\n" \
			"Komunikatorem lub SMS przekaż hasło do logów:\n\n$LOG_KEY"

	fi
}

main_menu() {
	while :; do
		local ns_tag=$(dotenv-tool -r get -f $ENV_FILE_DEP "NS_NIGHTSCOUT_TAG")
		local quickStatus=$(center_text "Strona Nightscout: $(get_watchdog_status "$(get_watchdog_status_code_live)" "$uni_ns_ok")" 55)
		local quickVersion=$(center_text "Wersja: $ns_tag" 55)
		local quickDomain=$(center_text "Domena: $(get_domain_status 'ns-server')" 55)
		local CHOICE=$(whiptail --title "Zarządzanie Nightscoutem :: $SCRIPT_VERSION" --menu "\n$quickStatus\n$quickVersion\n$quickDomain\n" 19 60 9 \
			"S)" "Status kontenerów i logi" \
			"P)" "Pokaż port i API SECRET" \
			"U)" "Aktualizuj..." \
			"C)" "Sprztąj..." \
			"R)" "Uruchom ponownie kontenery" \
			"D)" "Wyślij diagnostykę i logi" \
			"Z)" "Zmień lub odinstaluj..." \
			"I)" "O tym narzędziu..." \
			"X)" "Wyjście" \
			--ok-button="$uni_select" --cancel-button="$uni_exit" \
			3>&2 2>&1 1>&3)

		case $CHOICE in
		"S)")
			status_menu
			;;
		"P)")
			local ns_external_port=$(dotenv-tool -r get -f $ENV_FILE_DEP "NS_PORT")
			local ns_api_secret=$(dotenv-tool -r get -f $ENV_FILE_NS "API_SECRET")
			whiptail --title "Podgląd konfiguracji Nightscout" --msgbox \
				"\n   Port usługi Nightscout: $ns_external_port\n               API_SECRET: $ns_api_secret" \
				10 60
			;;
		"U)")
			update_menu
			;;
		"C)")
			cleanup_menu
			;;
		"R)")
			docker_compose_down
			docker_compose_up
			;;
		"D)")
			send_diagnostics
			;;
		"Z)")
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

install_or_menu() {
	STATUS_NS=$(get_docker_status "ns-server")
	lastTimeSpaceInfo=$(get_space_info)

	if [ "$STATUS_NS" = "missing" ]; then

		if [ "$freshInstall" -eq 0 ]; then
			instal_now_prompt
			if ! [ $? -eq 1 ]; then
				freshInstall=1
			fi
		fi

		if [ "$freshInstall" -gt 0 ]; then
			ohai "Instalowanie Nightscout..."
			docker_compose_update
			setup_firewall_for_ns
			domain_setup
			# admin_panel_promo
			setup_done
		else
			main_menu
		fi
	else
		msgok "Wykryto uruchomiony Nightscout"
		main_menu
	fi
}

watchdog_check() {
	echo "Nightscout Watchdog mode"

	WATCHDOG_LAST_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	WATCHDOG_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	WATCHDOG_LAST_STATUS="unknown"
	WATCHDOG_STATUS="unknown"

	if [[ -f $WATCHDOG_TIME_FILE ]]; then
		echo "Found $WATCHDOG_TIME_FILE"
		WATCHDOG_LAST_TIME=$(cat $WATCHDOG_TIME_FILE)
	else
		echo "First watchdog run"
	fi

	if [[ -f $WATCHDOG_STATUS_FILE ]]; then
		echo "Found $WATCHDOG_STATUS_FILE"
		WATCHDOG_LAST_STATUS=$(cat $WATCHDOG_STATUS_FILE)
	fi

	local STATUS_AGO=$(dateutils.ddiff "$WATCHDOG_TIME" "$WATCHDOG_LAST_TIME" -f '%S')

	if [ "$STATUS_AGO" -gt 900 ]; then
		echo "Watchdog last status is $STATUS_AGO seconds old, ignoring"
		WATCHDOG_LAST_STATUS="unknown"
	fi

	local NS_STATUS=$(get_container_status_code 'ns-server')
	local DB_STATUS=$(get_container_status_code 'ns-database')
	local COMBINED_STATUS="$NS_STATUS $DB_STATUS"

	echo "Server container: $NS_STATUS"
	echo "Database container: $DB_STATUS"

	if [ "$COMBINED_STATUS" = "running running" ]; then
		echo "Will check page contents"
		local domain=$(get_td_domain)

		local domainLen=${#domain}
		if ((domainLen > 15)); then
			local html=$(curl -iLsk "$domain")

			WATCHDOG_STATUS="detection_failed"

			if [[ "$html" =~ github.com/nightscout/cgm-remote-monitor ]]; then
				echo "Nightscout is running"
				WATCHDOG_STATUS="ok"
			fi

			if [[ "$html" =~ 'MongoDB connection failed' ]]; then
				echo "Nightscout is crashed, restarting..."
				WATCHDOG_STATUS="restart"
				if [ "$WATCHDOG_LAST_STATUS" != "restart" ]; then
					docker restart 'ns-server'
					echo "...done"
				fi
			fi

			regex3='MIKR.US - coś poszło nie tak'
			if [[ "$html" =~ $regex3 ]]; then
				echo "Nightscout is still restarting..."
				WATCHDOG_STATUS="restarting"
			fi

			if [ "$WATCHDOG_STATUS" = "detection_failed" ]; then
				{
					echo "----------------------------------------------------------------"
					echo "[$WATCHDOG_TIME] Unknown server failure:"
					echo "CONTAINERS:"
					docker stats --no-stream
					echo "HTTP DUMP:"
					echo "$html"
				} >>"$WATCHDOG_FAILURES_FILE"
			fi

		else
			WATCHDOG_STATUS="domain_failed"
		fi

	else
		if [ "$NS_STATUS" = "restarting" ] || [ "$DB_STATUS" = "restarting" ]; then
			WATCHDOG_STATUS="restarting"
		else
			WATCHDOG_STATUS="not_running"
		fi
	fi

	echo "Watchdog observation: $WATCHDOG_STATUS"

	# if [ "$WATCHDOG_LAST_STATUS" != "$WATCHDOG_STATUS" ]; then
	echo "$WATCHDOG_TIME [$WATCHDOG_STATUS]" >>$WATCHDOG_LOG_FILE
	LOGSIZE=$(wc -l <$WATCHDOG_LOG_FILE)
	if [ "$LOGSIZE" -gt 1000 ]; then
		tail -1000 $WATCHDOG_LOG_FILE >"$WATCHDOG_LOG_FILE.tmp"
		mv -f "$WATCHDOG_LOG_FILE.tmp" "$WATCHDOG_LOG_FILE"
	fi
	# fi

	if [[ -f $WATCHDOG_FAILURES_FILE ]]; then
		FAILSIZE=$(wc -l <$WATCHDOG_FAILURES_FILE)
		if [ "$FAILSIZE" -gt 10000 ]; then
			tail -10000 $WATCHDOG_FAILURES_FILE >"$WATCHDOG_FAILURES_FILE.tmp"
			mv -f "$WATCHDOG_FAILURES_FILE.tmp" "$WATCHDOG_FAILURES_FILE"
		fi
	fi

	echo "$WATCHDOG_TIME" >$WATCHDOG_TIME_FILE
	echo "$WATCHDOG_STATUS" >$WATCHDOG_STATUS_FILE

	exit 0
}

load_update_channel() {
	if [[ -f $UPDATE_CHANNEL_FILE ]]; then
		UPDATE_CHANNEL=$(cat $UPDATE_CHANNEL_FILE)
		msgok "Loaded update channel: $UPDATE_CHANNEL"
	fi
}

startup_version() {
	msgnote "nightscout-tool version $SCRIPT_VERSION ($SCRIPT_BUILD_TIME)"
	msgnote "$uni_copyright 2023-2024 Dominik Dzienia"
	msgnote "Licensed under CC BY-NC-ND 4.0"
}

parse_commandline_args() {

	load_update_channel

	CMDARGS=$(getopt --quiet -o wvdpc: --long watchdog,version,develop,production,channel: -n 'nightscout-tool' -- "$@")

	# shellcheck disable=SC2181
	if [ $? != 0 ]; then
		echo "Invalid arguments: " "$@" >&2
		exit 1
	fi

	# Note the quotes around '$TEMP': they are essential!
	eval set -- "$CMDARGS"

	WATCHDOGMODE=false
	while true; do
		case "$1" in
		-w | --watchdog)
			WATCHDOGMODE=true
			shift
			;;
		-v | --version)
			echo "$SCRIPT_VERSION"
			exit 0
			;;
		-d | --develop)
			warn "Switching to DEVELOP update channel"
			UPDATE_CHANNEL=develop
			echo "$UPDATE_CHANNEL" >$UPDATE_CHANNEL_FILE
			shift
			;;
		-p | --production)
			warn "Switching to PRODUCTION update channel"
			UPDATE_CHANNEL=master
			echo "$UPDATE_CHANNEL" >$UPDATE_CHANNEL_FILE
			shift
			;;
		-c | --channel)
			shift # The arg is next in position args
			UPDATE_CHANNEL_CANDIDATE=$1

			[[ ! "$UPDATE_CHANNEL_CANDIDATE" =~ ^[a-z]{3,}$ ]] && {
				echo "Incorrect channel name provided: $UPDATE_CHANNEL_CANDIDATE"
				exit 1
			}

			warn "Switching to $UPDATE_CHANNEL_CANDIDATE update channel"
			UPDATE_CHANNEL="$UPDATE_CHANNEL_CANDIDATE"
			echo "$UPDATE_CHANNEL" >$UPDATE_CHANNEL_FILE
			shift
			;;
		--)
			shift
			break
			;;
		*) break ;;
		esac
	done

	if [ "$WATCHDOGMODE" = "true" ]; then
		watchdog_check
	fi

}


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
