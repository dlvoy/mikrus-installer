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
# MAIN APP UI
#=======================================

show_logs() {
	local col=$((COLUMNS - 10))
	local rws=$((LINES - 4))
	if [ "$col" -gt 120 ]; then
		col=160
	fi
	if [ "$col" -lt 60 ]; then
		col=60
	fi
	if [ "$rws" -lt 12 ]; then
		rws=12
	fi

	local ID=$(docker ps -a --no-trunc --filter name="^$1$" --format '{{ .ID }}')
	if [ -n "$ID" ]; then
		local tmpfile=$(mktemp)
		docker logs "$ID" 2>&1 | tail $((rws * -6)) | sed 's/\x1B\[[0-9;]\{1,\}[A-Za-z]//g' >"$tmpfile"
		whiptail --title "Logi $2" --scrolltext --textbox "$tmpfile" "$rws" "$col"
		rm "$tmpfile"
	fi
}

status_menu() {
	while :; do
		local CHOICE=$(whiptail --title "Status kontenerów" --menu "\n  Aktualizacja: kontenery na żywo, watchdog co 5 minut\n\n        Wybierz pozycję aby zobaczyć logi:\n" 18 60 6 \
			"1)" "   Nightscout:  $(get_container_status 'ns-server')" \
			"2)" "  Baza danych:  $(get_container_status 'ns-database')" \
			"3)" "       Backup:  $(get_container_status 'ns-backup')" \
			"4)" "     Watchdog:  $(get_watchdog_status "$(get_watchdog_status_code)" "$uni_watchdog_ok")" \
			"5)" "    Zdarzenia:  $(get_events_status)" \
			"M)" "Powrót do menu" \
			--ok-button="Zobacz logi" --cancel-button="$uni_back" \
			3>&2 2>&1 1>&3)

		case $CHOICE in
		"1)")
			show_logs 'ns-server' 'Nightscouta'
			;;
		"2)")
			show_logs 'ns-database' 'bazy danych'
			;;
		"3)")
			show_logs 'ns-backup' 'usługi kopii zapasowych'
			;;
		"4)")
			show_watchdog_logs
			;;
		"5)")
			okdlg "Zdarzenia" \
				"$(pad_multiline "$(event_list)")"
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

main_menu() {
	while :; do
		local ns_tag=$(dotenv-tool -r get -f "$ENV_FILE_DEP" "NS_NIGHTSCOUT_TAG")
		local quickStatus=$(center_text "Strona Nightscout: $(get_watchdog_status "$(get_watchdog_status_code_live)" "$uni_ns_ok")" 55)
		local quickVersion=$(center_text "Wersja: $ns_tag" 55)
		local quickDomain=$(center_text "Domena: $(get_domain_status 'ns-server')" 55)
		local CHOICE=$(whiptail --title "Zarządzanie Nightscoutem :: $SCRIPT_VERSION" --menu "\n$quickStatus\n$quickVersion\n$quickDomain\n" 21 60 9 \
			"S)" "Status kontenerów i logi" \
			"P)" "Pokaż port i API SECRET" \
			"U)" "Aktualizuj..." \
			"C)" "Sprztąj..." \
			"R)" "Uruchom ponownie kontenery" \
			"D)" "Wyślij diagnostykę i logi" \
			"Z)" "Zmień lub odinstaluj..." \
			"I)" "O tym narzędziu..." \
			"X)" "Wyjście" \
			--ok-button="$uni_select" --cancel-button="$uni_exit" \
			3>&2 2>&1 1>&3)

		case $CHOICE in
		"S)")
			status_menu
			;;
		"P)")
			local ns_external_port=$(dotenv-tool -r get -f "$ENV_FILE_DEP" "NS_PORT")
			local ns_api_secret=$(dotenv-tool -r get -f "$ENV_FILE_NS" "API_SECRET")
			whiptail --title "Podgląd konfiguracji Nightscout" --msgbox \
				"\n   Port usługi Nightscout: $ns_external_port\n               API_SECRET: $ns_api_secret" \
				10 60
			;;
		"U)")
			update_menu
			;;
		"C)")
			cleanup_menu
			;;
		"R)")
			docker_compose_down
			docker_compose_up
			;;
		"D)")
			send_diagnostics
			;;
		"Z)")
			uninstall_menu
			;;
		"I)")
			about_dialog
			;;
		"X)")
			exit 0
			;;
		"")
			exit 0
			;;
		esac
	done
}

install_or_menu() {
	STATUS_NS=$(get_docker_status "ns-server")
	#shellcheck disable=SC2034
	lastTimeSpaceInfo=$(get_space_info)

	if [ "$STATUS_NS" = "missing" ]; then

		if [ "$freshInstall" -eq 0 ]; then
			install_now_prompt
			if ! [ $? -eq 1 ]; then
				freshInstall=1
			fi
		fi

		if [ "$freshInstall" -gt 0 ]; then
			ohai "Instalowanie Nightscout..."
			event_mark "install_start"
			docker_compose_update
			setup_firewall_for_ns
			domain_setup
			# admin_panel_promo
			event_mark "install_end"
			setup_done
		else
			main_menu
		fi
	else
		msgok "Wykryto uruchomiony Nightscout"
		main_menu
	fi
}
