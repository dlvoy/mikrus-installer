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
# UTILS
#=======================================

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

extract_version() {
	regex='version:\s+([0-9]+\.[0-9]+\.[0-9]+)'
	if [[ "$1" =~ $regex ]]; then
		echo "${BASH_REMATCH[1]}"
	else
		echo "0.0.0"
	fi
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

if_is_set() {
	[[ ${!1-x} == x ]] && return 1 || return 0
}

exit_on_no_cancel() {
	if [ $? -eq 1 ]; then
		exit 0
	fi
}

check_interactive() {
	shopt -q login_shell && echo 'Login shell' || echo 'Not login shell'

	# if [[ $- == *i* ]]; then
	#   msgok "Interactive setup"
	# else
	#    msgok "Non-interactive setup"
	# fi
}

read_or_default() {
	if [ -f "$1" ]; then
		cat "$1"
	else
		if [ $# -eq 2 ]; then
			echo "$2"
		else
			echo ""
		fi
	fi
}
