#=======================================
# UPDATE UI
#=======================================

update_if_needed() {

	download_if_needed "$@"

	local lastDownload=$(read_or_default "$UPDATES_DIR/downloaded" "???")
	local updateInstalled=$(read_or_default "$UPDATES_DIR/updated" "???")

	if [ "$lastDownload" == "$updateInstalled" ] && ((forceUpdateCheck == 0)) && [ $# -eq 0 ]; then
		msgok "Scripts and config files are up to date"
	else

		if [ "$lastDownload" == "error" ]; then
			msgerr "Download update failed"
			if [ $# -eq 1 ]; then
				okdlg "Aktualizacja niemożliwa" "Nie można w tej chwili aktualizować narzędzia.${TL}Spróbuj ponownie później.${NL}Jeśli problem nie ustąpi - sprawdź konfigurację kanału aktualizacji"
			fi
		else

			if [ $# -eq 0 ] && [ "$UPDATE_CHANNEL" == "master" ] && [[ "$lastDownload" < "$updateInstalled" ]]; then
				msgnote "Downgrade not possible on master channel"
				forceUpdateCheck=1
				download_if_needed
			else

				local changed=0
				local redeploy=0

				local instOnlineVer=$(extract_version "$(<"$UPDATES_DIR/install.sh")")
				local depEnvOnlineVer=$(extract_version "$(<"$UPDATES_DIR/deployment.env")")
				local nsEnvOnlineVer=$(extract_version "$(<"$UPDATES_DIR/nightscout.env")")
				local compOnlineVer=$(extract_version "$(<"$UPDATES_DIR/docker-compose.yml")")

				local instLocalVer=$(extract_version "$(<"$TOOL_FILE")")
				local depEnvLocalVer=$(extract_version "$(<"$ENV_FILE_DEP")")
				local nsEnvLocalVer=$(extract_version "$(<"$ENV_FILE_NS")")
				local compLocalVer=$(extract_version "$(<"$DOCKER_COMPOSE_FILE")")

				local msgInst="$(printf "\U1F7E2") $instLocalVer"
				local msgDep="$(printf "\U1F7E2") $depEnvLocalVer"
				local msgNs="$(printf "\U1F7E2") $nsEnvLocalVer"
				local msgComp="$(printf "\U1F7E2") $compLocalVer"

				if ! [ "$instOnlineVer" == "$instLocalVer" ] || ! [ "$lastDownload" == "$updateInstalled" ]; then
					changed=$((changed + 1))
					msgInst="$(printf "\U1F534") $instLocalVer $(printf "\U27A1") $instOnlineVer"
				fi

				if ! [ "$depEnvLocalVer" == "$depEnvOnlineVer" ]; then
					changed=$((changed + 1))
					redeploy=$((redeploy + 1))
					msgDep="$(printf "\U1F534") $depEnvLocalVer $(printf "\U27A1") $depEnvOnlineVer"
				fi

				if ! [ "$nsEnvLocalVer" == "$nsEnvOnlineVer" ]; then
					changed=$((changed + 1))
					redeploy=$((redeploy + 1))
					msgNs="$(printf "\U1F534") $nsEnvLocalVer $(printf "\U27A1") $nsEnvOnlineVer"
				fi

				if ! [ "$compLocalVer" == "$compOnlineVer" ]; then
					changed=$((changed + 1))
					redeploy=$((redeploy + 1))
					msgComp="$(printf "\U1F534") $compLocalVer $(printf "\U27A1") $compOnlineVer"
				fi

				if [ "$changed" -eq 0 ]; then
					if [ $# -eq 1 ]; then
						msgok "Scripts and config files are up to date"
						okdlg "Aktualizacja skryptów" "$1"
					fi
				else
					local okTxt=""
					if [ "$redeploy" -gt 0 ]; then
						okTxt="${TL}${uni_warn} Aktualizacja zrestartuje i zaktualizuje kontenery ${uni_warn}"
					fi

					local versionMsg="${TL}Build: ${updateInstalled}"
					if [ ! "$lastDownload" == "$updateInstalled" ]; then
						versionMsg="$(pad_multiline "${TL}Masz build: ${updateInstalled}${NL}  Dostępny: ${lastDownload}")"
					fi

					yesnodlg "Aktualizacja skryptów" "$uni_confirm_upd" "$uni_resign" \
						"Zalecana jest aktualizacja plików:${versionMsg}" \
						"$(
							pad_multiline \
								"${TL}${uni_bullet}Skrypt instalacyjny:      $msgInst" \
								"${NL}${uni_bullet}Konfiguracja deploymentu: $msgDep" \
								"${NL}${uni_bullet}Konfiguracja Nightscout:  $msgNs" \
								"${NL}${uni_bullet}Kompozycja usług:         $msgComp${NL}"
						)" \
						"$okTxt"

					if ! [ $? -eq 1 ]; then

						clear_last_time "update_needed"

						if [ "$redeploy" -gt 0 ]; then
							docker_compose_down
						fi

						if ! [ "$compOnlineVer" == "$compLocalVer" ]; then
							ohai "Updating $DOCKER_COMPOSE_FILE"
							cp -fr "$UPDATES_DIR/docker-compose.yml" "$DOCKER_COMPOSE_FILE"
						fi

						if ! [ "$depEnvLocalVer" == "$depEnvOnlineVer" ]; then
							ohai "Updating $ENV_FILE_DEP"
							dotenv-tool -pr -o "$ENV_FILE_DEP" -i "$UPDATES_DIR/deployment.env" "$ENV_FILE_DEP"
						fi

						if ! [ "$nsEnvLocalVer" == "$nsEnvOnlineVer" ]; then
							ohai "Updating $ENV_FILE_NS"
							dotenv-tool -pr -o "$ENV_FILE_NS" -i "$UPDATES_DIR/deployment.env" "$ENV_FILE_NS"
						fi

						echo "$lastDownload" >"$UPDATES_DIR/updated"

						if ! [ "$instOnlineVer" == "$instLocalVer" ] || ! [ "$lastDownload" == "$updateInstalled" ]; then
							ohai "Updating $TOOL_FILE"
							cp -fr "$UPDATES_DIR/install.sh" "$TOOL_FILE"
							okdlg "Aktualizacja zakończona" "Narzędzie zostanie uruchomione ponownie"
							ohai "Restarting tool"
							exec "$TOOL_FILE"
						fi
					fi
				fi
			fi
		fi
	fi
}

update_menu() {
	while :; do
		local CHOICE=$(whiptail --title "Aktualizuj" --menu "\n" 11 40 4 \
			"N)" "Aktualizuj to narzędzie" \
			"S)" "Aktualizuj system" \
			"K)" "Aktualizuj kontenery" \
			"M)" "Powrót do menu" \
			--ok-button="$uni_select" --cancel-button="$uni_back" \
			3>&2 2>&1 1>&3)

		case $CHOICE in
		"S)")
			ohai "Updating package list"
			event_mark "update_system"
			dialog --title " Aktualizacja systemu " --infobox "\n  Pobieranie listy pakietów\n  ..... Proszę czekać ....." 6 33
			apt-get -yq update >>"$LOGTO" 2>&1
			ohai "Upgrading system"
			dialog --title " Aktualizacja systemu " --infobox "\n    Instalowanie pakietów\n     ... Proszę czekać ..." 6 33
			apt-get -yq upgrade >>"$LOGTO" 2>&1
			;;
		"N)")
			event_mark "update_tool"
			update_if_needed "Wszystkie pliki narzędzia są aktualne"
			;;
		"K)")
			event_mark "update_containers"
			docker_compose_down
			docker_compose_update
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
