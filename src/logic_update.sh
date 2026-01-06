#=======================================
# UPGRADE
#=======================================

mark_github_unavailable() {
	GITHUB_UNAVAILABLE="1"
}

get_url_branch() {
	local branch="$1"
	local path="$2"
	if [[ -n "$GITHUB_UNAVAILABLE" ]]; then
		echo "${GITEA_BASE_URL}/${branch}/${path}"
	else
		echo "${GITHUB_BASE_URL}/${branch}/${path}"
	fi
}

get_url() {
	get_url_branch "$UPDATE_CHANNEL" "$1"
}

download_file() {
	local label="$1"
	local target="$2"
	local path="$3"
	local branch="${4:-$UPDATE_CHANNEL}"

	local url=$(get_url_branch "$branch" "$path")

	if ! curl -fsSL -o "$target" "$url" 2>>"$LOGTO"; then
		if [[ -z "$GITHUB_UNAVAILABLE" ]]; then
			mark_github_unavailable
			url=$(get_url_branch "$branch" "$path")
			ohai "GitHub failed, retrying with Gitea ($label)..."
			curl -fsSL -o "$target" "$url" 2>>"$LOGTO"
		else
			return 1
		fi
	fi
}

download_if_not_exists() {
	local label="$1"
	local target="$2"
	local path="$3"
	local branch="${4:-$UPDATE_CHANNEL}"

	if [[ -f "$target" ]]; then
		msgok "Found $label"
	else
		ohai "Downloading $label..."
		if download_file "$label" "$target" "$path" "$branch"; then
			msgcheck "Downloaded $label"
		else
			msgerr "Failed to download $label"
			return 1
		fi
	fi
}

download_conf() {
	download_if_not_exists "deployment config" "$ENV_FILE_DEP" "templates/deployment.env"
	download_if_not_exists "nightscout config" "$ENV_FILE_NS" "templates/nightscout.env"
	download_if_not_exists "docker compose file" "$DOCKER_COMPOSE_FILE" "templates/docker-compose.yml"
	download_if_not_exists "profanity database" "$PROFANITY_DB_FILE" "templates/profanity.db" "profanity"
	download_if_not_exists "reservation database" "$RESERVED_DB_FILE" "templates/reserved.db" "profanity"
}

download_tools() {
	download_if_not_exists "update stamp" "$UPDATES_DIR/updated" "updated"

	if ! [[ -f "$TOOL_FILE" ]]; then
		download_if_not_exists "nightscout-tool file" "$TOOL_FILE" "install.sh"
		local timestamp=$(date +%s)
		echo "$timestamp" >"$UPDATES_DIR/timestamp"
	else
		msgok "Found nightscout-tool"
	fi

	if ! [[ -f "$TOOL_LINK" ]]; then
		ohai "Linking nightscout-tool"
		ln -s "$TOOL_FILE" "$TOOL_LINK"
	fi

	chmod +x "$TOOL_FILE"
	chmod +x "$TOOL_LINK"
}

download_updates() {
	ohai "Downloading updated scripts and config files"

	local url=$(get_url "updated")
	local onlineUpdated=$(curl -fsSL "$url" 2>>"$LOGTO")

	if [[ -z "$onlineUpdated" && -z "$GITHUB_UNAVAILABLE" ]]; then
		mark_github_unavailable
		url=$(get_url "updated")
		ohai "GitHub failed, retrying with Gitea (update check)..."
		onlineUpdated=$(curl -fsSL "$url" 2>>"$LOGTO")
	fi

	if [ ! "$onlineUpdated" == "" ]; then
		download_file "install script" "$UPDATES_DIR/install.sh" "install.sh"
		download_file "deployment info" "$UPDATES_DIR/deployment.env" "templates/deployment.env"
		download_file "nightscout info" "$UPDATES_DIR/nightscout.env" "templates/nightscout.env"
		download_file "docker compose" "$UPDATES_DIR/docker-compose.yml" "templates/docker-compose.yml"
		download_file "profanity db" "$PROFANITY_DB_FILE" "templates/profanity.db" "profanity"
		download_file "reserved db" "$RESERVED_DB_FILE" "templates/reserved.db" "profanity"
	else
		onlineUpdated="error"
	fi
	echo "$onlineUpdated" >"$UPDATES_DIR/downloaded"
}

download_if_needed() {
	local lastCheck=$(read_or_default "$UPDATES_DIR/timestamp")
	local lastDownload=$(read_or_default "$UPDATES_DIR/downloaded" "")
	local timestampNow=$(date +%s)
	local updateCheck=$UPDATE_CHECK
	if (((timestampNow - lastCheck) > updateCheck)) || [ "$lastDownload" == "" ] || [ "$lastDownload" == "error" ] || ((forceUpdateCheck == 1)) || [ $# -eq 1 ]; then
		echo "$timestampNow" >"$UPDATES_DIR/timestamp"
		ohai "Checking if new version is available..."
		local url=$(get_url "updated")
		local onlineUpdated=$(curl -fsSL "$url" 2>>"$LOGTO")

		if [[ -z "$onlineUpdated" && -z "$GITHUB_UNAVAILABLE" ]]; then
			mark_github_unavailable
			url=$(get_url "updated")
			ohai "GitHub failed, retrying with Gitea (version check)..."
			onlineUpdated=$(curl -fsSL "$url" 2>>"$LOGTO")
		fi

		local lastDownload=$(read_or_default "$UPDATES_DIR/downloaded")
		if [ "$onlineUpdated" == "$lastDownload" ] && ((forceUpdateCheck == 0)); then
			msgok "Latest update already downloaded"
		else
			download_updates
		fi
	else
		msgok "Too soon to download update, skipping..."
	fi
}

download_update_forced() {
	local timestampNow=$(date +%s)
	local lastDownload=$(read_or_default "$UPDATES_DIR/downloaded" "")

	echo "$timestampNow" >"$UPDATES_DIR/timestamp"
	ohai "Downloading updates..."
	local url=$(get_url "updated")
	local onlineUpdated=$(curl -fsSL "$url" 2>>"$LOGTO")
	if [[ -z "$onlineUpdated" && -z "$GITHUB_UNAVAILABLE" ]]; then
		mark_github_unavailable
		url=$(get_url "updated")
		ohai "GitHub failed, retrying with Gitea (version check)..."
		onlineUpdated=$(curl -fsSL "$url" 2>>"$LOGTO")
	fi
	
	if [ "$onlineUpdated" == "$lastDownload" ]; then
		msgdebug "Downloaded update will be the same as last downloaded"
	fi

	# we downlaod it anyway
	download_updates
}


do_update_tool() {
	download_update_forced

	local lastDownload=$(read_or_default "$UPDATES_DIR/downloaded" "???")
	local updateInstalled=$(read_or_default "$UPDATES_DIR/updated" "???")

	if [ "$lastDownload" == "error" ]; then
		msgerr "Aktualizacja niemożliwa" 
		msgerr "Nie można w tej chwili aktualizować narzędzia.${TL}Spróbuj ponownie później.${NL}Jeśli problem nie ustąpi - sprawdź konfigurację kanału aktualizacji"
	else

		if [ "$UPDATE_CHANNEL" == "master" ] && [[ "$lastDownload" < "$updateInstalled" ]]; then
			 warn "Downgrade na produkcyjnym kanale aktualizacji!"
    fi

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

				local okTxt=""
				if [ "$redeploy" -gt 0 ]; then
					okTxt="${TL}${uni_warn} Aktualizacja zrestartuje i zaktualizuje kontenery ${uni_warn}"
				fi

				local versionMsg="${TL}Build: ${updateInstalled}"
				if [ ! "$lastDownload" == "$updateInstalled" ]; then
					versionMsg="$(pad_multiline "${TL}Masz build: ${updateInstalled}${NL}  Dostępny: ${lastDownload}")"
				fi
  
        hline 
				echo -e "Aktualizacja plików:" "${versionMsg}" \
					"$(
						pad_multiline \
							"${TL}${uni_bullet}Skrypt instalacyjny:      $msgInst" \
							"${NL}${uni_bullet}Konfiguracja deploymentu: $msgDep" \
							"${NL}${uni_bullet}Konfiguracja Nightscout:  $msgNs" \
							"${NL}${uni_bullet}Kompozycja usług:         $msgComp${NL}"
					)" \
					"$okTxt"
        hline

				clear_last_time "update_needed"

				if [ "$redeploy" -gt 0 ]; then
          ohai "Redeploy - uninstalling containers"
					uninstall_containers
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
				fi

				if [ "$redeploy" -gt 0 ]; then
          ohai "Redeploy - installing containers"
          install_containers
				fi

        hline
				msgok "Aktualizacja zakończona"
#		fi
	fi
}
