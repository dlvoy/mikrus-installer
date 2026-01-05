#=======================================
# CONSOLE OUTPUT UTILS
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
