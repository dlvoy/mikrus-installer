#dev-begin
# shellcheck disable=SC2148
# shellcheck disable=SC2155

#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# IMPORTS
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# shellcheck source=./headers.sh
source ./headers.sh
#dev-end

#=======================================
# SETUP CHECKS
#=======================================

# $1 lib name
# $2 package name
add_if_not_ok() {
	local RESULT=$?
	if [ "$RESULT" -eq 0 ]; then
		msgcheck "$1 installed"
	else
		packages+=("$2")
	fi
}

add_if_not_ok_cmd() {
	local RESULT=$?
	if [ "$RESULT" -eq 0 ]; then
		msgcheck "$1 installed"
	else
		ohai "Installing $1..."
		eval "$2" >>"$LOGTO" 2>&1 && msgcheck "Installing $1 successfull"
	fi
}

add_if_not_ok_compose() {
	#shellcheck disable=SC2319
	local RESULT=$?
	if [ "$#" -eq 2 ]; then
		RESULT=-1
	fi

	if [ "$RESULT" -eq 0 ]; then
		msgcheck "$1 installed"
	else
		ohai "Installing $1..."
		{
			mkdir -p "$HOME/.docker/cli-plugins"
			curl -SL "https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64" -o "$HOME/.docker/cli-plugins/docker-compose"
		} >>"$LOGTO" 2>&1
		chmod +x "$HOME/.docker/cli-plugins/docker-compose" >>"$LOGTO" 2>&1
		msgcheck "Installing $1 successfull"
	fi
}

test_node() {
	local node_version_output
	node_version_output="$(node -v 2>/dev/null)"
	version_ge "$(major_minor "${node_version_output/v/}")" "$(major_minor "${REQUIRED_NODE_VERSION}")"
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
	local version_output
	version_output="$(docker compose version 2>&1)"
	# check if output has 'unknown' in it or doesn't match the required version pattern
	if [[ "$version_output" == *"unknown"* ]] || [[ ! "$version_output" =~ version\ v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
		add_if_not_ok_compose "Docker compose" "force"
	else
		msgcheck "Docker compose installed"
	fi
}

check_jq() {
	jq --help >/dev/null 2>&1
	add_if_not_ok "JSON parser" "jq"
}

check_dotenv() {
	if dotenv-tool -v >/dev/null 2>&1; then
		local dotEnvVersion="$(dotenv-tool -v 2>/dev/null)"
		if version_ge "$(major_minor "${dotEnvVersion}")" \
			"$(major_minor "${REQUIRED_DOTENV_VERSION}")"; then
			msgcheck "dotenv-tool installed (${dotEnvVersion})"
		else
			ohai "Updating dotenv-tool (from: ${dotEnvVersion})"
			eval "npm install -g dotenv-tool --registry https://npm.dzienia.pl" >>"$LOGTO" 2>&1 && msgcheck "Updating dotenv-tool successfull"
		fi
	else
		ohai "Installing dotenv-tool..."
		eval "npm install -g dotenv-tool --registry https://npm.dzienia.pl" >>"$LOGTO" 2>&1 && msgcheck "Installing dotenv-tool successfull"
	fi
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

test_diceware() {
	diceware --version >/dev/null 2>&1
}

check_diceware() {
	test_diceware
	add_if_not_ok "Secure Password Generator" "diceware"
}
