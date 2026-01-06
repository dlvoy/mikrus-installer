#dev-begin
# shellcheck disable=SC2148
# shellcheck disable=SC2155
# shellcheck disable=SC2034

if [ "$EXECUTED" != "true" ]; then

	echo "Headers USED!"
	#=======================================
	# HEADERS
	#=======================================

	#---------------------------------------
	# GLOBAL VARS
	#---------------------------------------

	packages=()
	aptGetWasUpdated=0
	freshInstall=0
	cachedMenuDomain=''
	lastTimeSpaceInfo=0
	diagnosticsSizeOk=0
	forceUpdateCheck=0

	MIKRUS_APIKEY=''
	MIKRUS_HOST=''

	#---------------------------------------
	# UNICODE LITERALS
	#---------------------------------------

	emoji_check="\U2705"
	emoji_ok="\U1F197"
	emoji_err="\U274C"
	emoji_note="\U1F4A1"
	emoji_debug="\U1F4DC"

	uni_bullet="  $(printf '\u2022') "
	uni_copyright="$(printf '\uA9\uFE0F')"
	uni_bullet_pad="    "
	uni_warn="$(printf "\U26A0")"

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
	uni_delete=" $(printf '\U1F5D1') Usuń "
	uni_leave_logs=" $(printf '\U1F4DC') Zostaw "

	uni_ns_ok="$(printf '\U1F7E2') działa"
	uni_leave_logs=''
	uni_back=''
	uni_resign=''
	uni_confirm_del=''
	uni_confirm_ch=''
	uni_confirm_ed=''
	uni_select=''
	uni_bullet=''
	uni_bullet_pad=''
	uni_warn=''
	uni_send=''
	uni_watchdog_ok=''
	uni_exit=''
	uni_ns_ok=''
	uni_start=''
	uni_install=''
	uni_noenter=''

	tty_blue=''
	tty_red=''
	tty_bold=''
	tty_reset=''

fi
#dev-end
