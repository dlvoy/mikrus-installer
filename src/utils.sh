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
