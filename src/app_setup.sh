#=======================================
# SETUP UI
#=======================================

docker_compose_up() {
	process_gauge install_containers install_containers_progress "Uruchamianie Nightscouta" "Proszę czekać, trwa uruchamianie kontenerów..."
}

docker_compose_update() {
	process_gauge update_containers install_containers_progress "Uruchamianie Nightscouta" "Proszę czekać, trwa aktualizacja kontenerów..."
}

docker_compose_down() {
	process_gauge uninstall_containers uninstall_containers_progress "Zatrzymywanie Nightscouta" "Proszę czekać, trwa zatrzymywanie i usuwanie kontenerów..."
}

setup_done() {
	whiptail --title "Gotowe!" --yesno --defaultno "     Możesz teraz zamknąć to narzędzie lub wrócić do menu.\n       Narzędzie dostępne jest też jako komenda konsoli:\n\n                         nightscout-tool" --yes-button "$uni_menu" --no-button "$uni_finish" 12 70
	exit_on_no_cancel
	main_menu
}

domain_setup_manual() {
	ns_external_port=$(dotenv-tool -r get -f "$ENV_FILE_DEP" "NS_PORT")
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

	ns_external_port=$(dotenv-tool -r get -f "$ENV_FILE_DEP" "NS_PORT")
	whiptail --title "Ustaw subdomenę" --msgbox "Aby Nightscout był widoczny z internetu ustaw adres - subdomenę:\n\n                      [wybierz].ns.techdiab.pl\n\nWybrany początek subdomeny powinien:\n${uni_bullet}mieć długość od 4 do 12 znaków\n${uni_bullet}zaczynać się z małej litery,\n${uni_bullet}może składać się z małych liter i cyfr\n${uni_bullet}być unikalny, charakterystyczny i łatwa do zapamiętania" 16 75

	while :; do
		SUBDOMAIN=''
		while :; do
			SUBDOMAIN=$(whiptail --title "Podaj początek subdomeny" --inputbox "\n(4-12 znaków, tylko: małe litery i cyfry)\n\n" --cancel-button "Anuluj" 12 60 3>&1 1>&2 2>&3)

			if [ $? -eq 1 ]; then
				break
			fi

			if [[ "$SUBDOMAIN" =~ ^[a-z][a-z0-9]{3,11}$ ]]; then

				if printf "%s" "$SUBDOMAIN" | grep -f "$PROFANITY_DB_FILE" >>"$LOGTO" 2>&1; then
					okdlg "$uni_excl Nieprawidłowa subdomena $uni_excl" \
						"Podana wartość:" \
						"${NL}$SUBDOMAIN" \
						"${TL}jest zajęta, zarezerwowana lub niedopuszczalna." \
						"${TL}Wymyśl coś innego"
					SUBDOMAIN=''
					continue
				fi

				if printf "%s" "$SUBDOMAIN" | grep -xf "$RESERVED_DB_FILE" >>"$LOGTO" 2>&1; then
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
		local APISEC=$(dotenv-tool -r get -f "$ENV_FILE_ADMIN" "MIKRUS_APIKEY")

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