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
  if [ "$NONINTERACTIVE_MODE" = "true" ]; then
    # shellcheck disable=SC2059
  printf "==> %s\n" "$(shell_join "$@")"
  else
	  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "$@")"
  fi
}

msgok() {
	if [ "$NONINTERACTIVE_MODE" = "true" ]; then
  	# shellcheck disable=SC2059
	  printf "$1\n"
  else
  	# shellcheck disable=SC2059
	  printf "$emoji_ok  $1\n"
  fi
}

msgnote() {
	if [ "$NONINTERACTIVE_MODE" = "true" ]; then
  	# shellcheck disable=SC2059
	  printf "$1\n"
  else
	  # shellcheck disable=SC2059
  	printf "$emoji_note  $1\n"
  fi
}

msgcheck() {
	if [ "$NONINTERACTIVE_MODE" = "true" ]; then
  	# shellcheck disable=SC2059
	  printf "$1\n"
  else
	  # shellcheck disable=SC2059
  	printf "$emoji_check  $1\n"
  fi
}

msgerr() {
	if [ "$NONINTERACTIVE_MODE" = "true" ]; then
  	# shellcheck disable=SC2059
	  printf "$1\n"
  else
	  # shellcheck disable=SC2059
	  printf "$emoji_err  $1\n"
  fi
}

msgdebug() {
	if [[ "$UPDATE_CHANNEL" == "develop" || "$FORCE_DEBUG_LOG" == "1" ]]; then
  	if [ "$NONINTERACTIVE_MODE" = "true" ]; then
    	# shellcheck disable=SC2059
  	  printf "$1\n"
    else
	    printf "$emoji_debug  $1\n"
    fi
  fi
}

hline() {
	if [ "$NONINTERACTIVE_MODE" = "true" ]; then
		printf "%s\n" "-------------------------------------------------------"
	else
		printf "${tty_bold}%s${tty_reset}\n" "-------------------------------------------------------"
	fi
}

warn() {
	if [ "$NONINTERACTIVE_MODE" = "true" ]; then
  	# shellcheck disable=SC2059
  	printf "Warning: %s\n" "$(chomp "$1")" >&2
  else
  	printf "${tty_red}Warning${tty_reset}: %s\n" "$(chomp "$1")" >&2
  fi
}
