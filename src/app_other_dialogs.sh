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
# OTHER UI
#=======================================

about_dialog() {
	LOG_KEY=$(<"$LOG_ENCRYPTION_KEY_FILE")
	okdlg "O tym narzędziu..." \
		"$(printf '\U1F9D1') (c) 2023-2026 Dominik Dzienia" \
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

install_now_prompt() {
	yesnodlg "Instalować Nightscout?" "$uni_install" "$uni_noenter" \
		"Wykryto konfigurację ale brak uruchomionych usług" \
		"${NL}Czy chcesz zainstalować teraz kontenery Nightscout?"
}

# Promocja panelu administracyjnego - nie jest używany
admin_panel_promo() {
	whiptail --title "Panel zarządzania Mikr.us-em" --msgbox "$(center_multiline 70 \
		"Ta instalacja Nightscout dodaje dodatkowy panel administracyjny" \
		"${NL}do zarządzania serwerem i konfiguracją - online." \
		"${TL}Znajdziesz go klikając na ikonkę serwera w menu strony Nightscout" \
		"${NL}lub dodając /mikrus na końcu swojego adresu Nightscout")" \
		12 75
}
