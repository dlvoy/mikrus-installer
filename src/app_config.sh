#=======================================
# CONFIG AND MANAGEMENT UI
#=======================================

version_menu() {

	local tags=$(wget -q -O - "https://hub.docker.com/v2/namespaces/nightscout/repositories/cgm-remote-monitor/tags?page_size=100" | jq -r ".results[].name" | sed "/dev_[a-f0-9]*/d" | sort --version-sort -u -r | head -n 8)

	while :; do

		local ns_tag=$(dotenv-tool -r get -f "$ENV_FILE_DEP" "NS_NIGHTSCOUT_TAG")
		local versions=()

		while read -r line; do
			if [ "$line" == "$ns_tag" ]; then
				continue
			fi

			label=" - na sztywno $line "

			if [ "$line" == "latest_dev" ]; then
				label=" - najnowsza wersja rozwojowa "
			fi

			if [ "$line" == "latest" ]; then
				label=" - aktualna wersja stabilna "
			fi

			versions+=("$line")
			versions+=("$label")
		done <<<"$tags"

		versions+=("M)")
		versions+=("   Powrót do poprzedniego menu")

		local CHOICE=$(whiptail --title "Wersja Nightscout" --menu "\nZmień wersję kontenera Nightscout z: $ns_tag na:\n\n" 20 60 10 \
			"${versions[@]}" \
			--ok-button="Zmień" --cancel-button="$uni_back" \
			3>&2 2>&1 1>&3)

		if [ "$CHOICE" == "M)" ]; then
			break
		fi

		if [ "$CHOICE" == "" ]; then
			break
		fi

		if [ "$CHOICE" == "$ns_tag" ]; then
			whiptail --title "Ta sama wersja!" --msgbox "Wybrano bieżącą wersję - brak zmiany" 7 50
		else

			whiptail --title "Zmienić wersję Nightscout?" --yesno --defaultno "Czy na pewno chcesz zmienić wersję z: $ns_tag na: $CHOICE?\n\n${uni_bullet}dane i konfiguracja NIE SĄ usuwane\n${uni_bullet}wersję można łatwo zmienić ponownie\n${uni_bullet}dane w bazie danych mogą ulec zmianie i NIE BYĆ kompatybilne" --yes-button "$uni_confirm_ch" --no-button "$uni_resign" 13 73
			if ! [ $? -eq 1 ]; then
				event_mark "change_ns_version"
				docker_compose_down
				ohai "Changing Nightscout container tag from: $ns_tag to: $CHOICE"
				dotenv-tool -pmr -i "$ENV_FILE_DEP" -- "NS_NIGHTSCOUT_TAG=$CHOICE"
				docker_compose_update
				whiptail --title "Zmieniono wersję Nightscout" --msgbox "$(center_multiline 65 \
					"Zmieniono wersję Nightscout na: $CHOICE" \
					"${TL}Sprawdź czy Nightscout działa poprawnie, w razie problemów:" \
					"${NL}${uni_bullet}aktualizuj kontenery" \
					"${NL}${uni_bullet}spróbuj wyczyścić bazę danych" \
					"${NL}${uni_bullet}wróć do poprzedniej wersji ($ns_tag)")" \
					13 70
				break
			fi

		fi

	done
}

uninstall_menu() {
	while :; do
		local extraMenu=()
		extraMenu+=("A)" "Ustaw adres strony (subdomenę)")
		local ns_tag=$(dotenv-tool -r get -f "$ENV_FILE_DEP" "NS_NIGHTSCOUT_TAG")
		local CHOICE=$(whiptail --title "Zmień lub odinstaluj Nightscout" --menu "\n" 17 70 8 \
			"${extraMenu[@]}" \
			"W)" "Zmień wersję Nightscouta (bieżąca: $ns_tag)" \
			"E)" "Edytuj ustawienia (zmienne środowiskowe)" \
			"K)" "Usuń kontenery" \
			"B)" "Wyczyść bazę danych" \
			"D)" "Usuń kontenery, dane i konfigurację" \
			"U)" "Usuń wszystko - odinstaluj" \
			"M)" "Powrót do menu" \
			--ok-button="$uni_select" --cancel-button="$uni_back" \
			3>&2 2>&1 1>&3)

		case $CHOICE in
		"A)")
			domain_setup
			;;
		"W)")
			version_menu
			;;
		"E)")

			if ! [[ "$0" =~ .*"/usr/bin/nightscout-tool" ]]; then
				okdlg "Opcja niedostępna" \
					"Edytor ustawień dostępny po uruchomieniu narzędzia komendą:" \
					"${TL}nightscout-tool"
			else
				yesnodlg "Edycja ustawień Nightscout" "$uni_confirm_ed" "$uni_resign" \
					"Za chwilę otworzę plik konfiguracji Nightscout w edytorze NANO" \
					"$(pad_multiline \
						"${TL}Wskazówki co do obsługi edytora:" \
						"${NL}${uni_bullet}Aby ZAPISAĆ zmiany naciśnij Ctrl+O" \
						"${NL}${uni_bullet}Aby ZAKOŃCZYĆ edycję naciśnij Ctrl+X")" \
					"${TL}${uni_warn} Edycja spowoduje też restart i aktualizację kontenerów ${uni_warn}"

				if ! [ $? -eq 1 ]; then
					event_mark "edit_env_manual"
					nano "$ENV_FILE_NS"
					docker_compose_down
					docker_compose_update
				fi
			fi
			;;
		"K)")
			noyesdlg "Usunąć kontenery?" "$uni_confirm_del" "$uni_resign" \
				"Czy na pewno chcesz usunąć kontenery powiązane z Nightscout?" \
				"$(pad_multiline \
					"${TL}${uni_bullet}dane i konfiguracja NIE SĄ usuwane" \
					"${NL}${uni_bullet}kontenery można łatwo odzyskać (opcja Aktualizuj kontenery)")"

			if ! [ $? -eq 1 ]; then
				event_mark "remove_containers"
				docker_compose_down
			fi
			;;
		"B)")
			noyesdlg "Usunąć dane z bazy danych?" "$uni_confirm_del" "$uni_resign" \
				"Czy na pewno chcesz usunąć dane z bazy danych?" \
				"$(pad_multiline \
					"${TL}${uni_bullet}konfiguracja serwera NIE ZOSTANIE usunięta" \
					"${NL}${uni_bullet}usunięte zostaną wszystkie dane użytkownika" \
					"${NL}${uni_bullet_pad}  (m.in. historia glikemii, wpisy, notatki, pomiary, profile)" \
					"${NL}${uni_bullet}kontenery zostaną zatrzymane i uruchomione ponownie (zaktualizowane)")"

			if ! [ $? -eq 1 ]; then
				docker_compose_down
				dialog --title " Czyszczenie bazy danych " --infobox "\n    Usuwanie plików bazy\n   ... Proszę czekać ..." 6 32
				rm -r "${MONGO_DB_DIR:?}/data"
				event_mark "remove_db_data"
				docker_compose_update
			fi
			;;
		"D)")
			noyesdlg "Usunąć wszystkie dane?" "$uni_confirm_del" "$uni_resign" \
				"Czy na pewno chcesz usunąć wszystkie dane i konfigurację?" \
				"$(pad_multiline \
					"${TL}${uni_bullet}konfigurację panelu, ustawienia Nightscout" \
					"${NL}${uni_bullet}wszystkie dane użytkownika" \
					"${NL}${uni_bullet_pad}(m.in. glikemia, wpisy, notatki, pomiary, profile)" \
					"${NL}${uni_bullet}kontenery zostaną zatrzymane")"

			if ! [ $? -eq 1 ]; then
				docker_compose_down
				dialog --title " Czyszczenie bazy danych" --infobox "\n    Usuwanie plików bazy\n   ... Proszę czekać ..." 6 32
				rm -r "${MONGO_DB_DIR:?}/data"
				event_mark "remove_all_data"
				dialog --title " Czyszczenie konfiguracji" --infobox "\n    Usuwanie konfiguracji\n   ... Proszę czekać ..." 6 32
				rm -r "${CONFIG_ROOT_DIR:?}"
				do_cleanup_diagnostics
				do_cleanup_app_logs

				okdlg "Usunięto dane użytkownika" \
					"Usunęto dane użytkwnika i konfigurację." \
					"${TL}Aby zainstalować Nightscout od zera:" \
					"${NL}uruchom ponownie skrypt i podaj konfigurację"

				exit 0
			fi
			;;
		"U)")
			noyesdlg "Odinstalować?" "$uni_confirm_del" "$uni_resign" \
				"Czy na pewno chcesz usunąć wszystko?" \
				"$(pad_multiline \
					"${TL}${uni_bullet}konfigurację panelu, ustawienia Nightscout" \
					"${NL}${uni_bullet}wszystkie dane użytkownika (glikemia, status, profile)" \
					"${NL}${uni_bullet}kontenery, skrypt nightscout-tool")" \
				"${TL}NIE ZOSTANĄ USUNIĘTE/ODINSTALOWANE:" \
				"$(pad_multiline \
					"${TL}${uni_bullet}użytkownik mongo db, firewall, doinstalowane pakiety" \
					"${NL}${uni_bullet}kopie zapasowe bazy danych")"

			if ! [ $? -eq 1 ]; then
				docker_compose_down
				dialog --title " Odinstalowanie" --infobox "\n      Usuwanie plików\n   ... Proszę czekać ..." 6 32
				uninstall_cron
				rm -r "${MONGO_DB_DIR:?}/data"
				rm -r "${CONFIG_ROOT_DIR:?}"
				rm "$TOOL_LINK"
				rm -r "${NIGHTSCOUT_ROOT_DIR:?}/tools"
				rm -r "${NIGHTSCOUT_ROOT_DIR:?}/updates"
				do_cleanup_diagnostics
				do_cleanup_app_logs
				do_cleanup_app_state
				event_mark "uninstall"

				okdlg "Odinstalowano" \
					"Odinstalowano Nightscout z Mikr.us-a" \
					"${TL}Aby ponownie zainstalować, postępuj według instrukcji na stronie:" \
					"${NL}https://t1d.dzienia.pl/nightscout_mikrus_tutorial" \
					"${TL}Dziękujemy i do zobaczenia!"

				exit 0
			fi
			;;
		"M)")
			break
			;;
		"")
			break
			;;
		esac
	done
}
