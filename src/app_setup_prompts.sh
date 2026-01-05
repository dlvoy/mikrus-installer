#=======================================
# SETUP PROMPT DIALOGS
#=======================================

prompt_mikrus_host() {
	if ! [[ "$MIKRUS_HOST" =~ [a-zA-Z]{1,16}[0-9]{3} ]]; then
		MIKRUS_HOST=$(hostname)
		while :; do
			if [[ "$MIKRUS_HOST" =~ [a-zA-Z]{1,16}[0-9]{3} ]]; then
				break
			else
				MIKRUS_NEW_HOST=$(whiptail --title "Podaj identyfikator serwera" --inputbox "\nNie udało się wykryć identyfikatora serwera,\npodaj go poniżej ręcznie.\n\nIdentyfikator składa się z jednej litery i trzech cyfr\n" --cancel-button "Anuluj" 13 65 3>&1 1>&2 2>&3)
				exit_on_no_cancel
				if [[ "$MIKRUS_NEW_HOST" =~ [a-zA-Z]{1,16}[0-9]{3} ]]; then
					MIKRUS_HOST=$MIKRUS_NEW_HOST
					break
				else
					whiptail --title "$uni_excl Nieprawidłowy identyfikator serwera $uni_excl" --yesno "Podany identyfikator serwera ma nieprawidłowy format.\n\nChcesz podać go ponownie?" --yes-button "$uni_reenter" --no-button "$uni_exit" 12 70
					exit_on_no_cancel
				fi
			fi
		done

		ohai "Updating admin config (host)"
		dotenv-tool -pmr -i "$ENV_FILE_ADMIN" -- "MIKRUS_HOST=$MIKRUS_HOST"
	fi
}

prompt_mikrus_apikey() {
	if ! [[ "$MIKRUS_APIKEY" =~ [0-9a-fA-F]{40} ]]; then
		freshInstall=$((freshInstall + 1))

		if [ -f "/klucz_api" ]; then
			MIKRUS_APIKEY=$(cat "/klucz_api")
			MIKRUS_INFO_HOST=$(curl -s -d "srv=$MIKRUS_HOST&key=$MIKRUS_APIKEY" -X POST https://api.mikr.us/info | jq -r .server_id)

			if [[ "$MIKRUS_INFO_HOST" == "$MIKRUS_HOST" ]] || [[ "$MIKRUS_INFO_HOST" =~ [a-zA-Z]{1,16}[0-9]{3} ]]; then
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

					if [[ "$MIKRUS_INFO_HOST" == "$MIKRUS_HOST" ]] || [[ "$MIKRUS_INFO_HOST" =~ [a-zA-Z]{1,16}[0-9]{3} ]]; then
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
		dotenv-tool -pmr -i "$ENV_FILE_ADMIN" -- "MIKRUS_APIKEY=$MIKRUS_APIKEY"
	fi
}

prompt_api_secret() {
	API_SECRET=$(dotenv-tool -r get -f "$ENV_FILE_NS" "API_SECRET")

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
					dotenv-tool -pmr -i "$ENV_FILE_NS" -- "API_SECRET=$API_SECRET"
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
