# shellcheck disable=SC2148
# shellcheck disable=SC2155

#dev-begin
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# IMPORTS
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# shellcheck source=./headers.sh
source ./headers.sh
#dev-end

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
uni_watchdog_ok="$(printf '\U1F415') Nightscout działa"
