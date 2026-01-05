#=======================================
# UPGRADE
#=======================================

download_if_not_exists() {
	if [[ -f $2 ]]; then
		msgok "Found $1"
	else
		ohai "Downloading $1..."
		curl -fsSL -o "$2" "$3"
		msgcheck "Downloaded $1"
	fi
}

download_conf() {
	download_if_not_exists "deployment config" "$ENV_FILE_DEP" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/templates/deployment.env"
	download_if_not_exists "nightscout config" "$ENV_FILE_NS" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/templates/nightscout.env"
	download_if_not_exists "docker compose file" "$DOCKER_COMPOSE_FILE" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/templates/docker-compose.yml"
	download_if_not_exists "profanity database" "$PROFANITY_DB_FILE" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/profanity/templates/profanity.db"
	download_if_not_exists "reservation database" "$RESERVED_DB_FILE" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/profanity/templates/reserved.db"
}

download_tools() {
	download_if_not_exists "update stamp" "$UPDATES_DIR/updated" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/updated"

	if ! [[ -f $TOOL_FILE ]]; then
		download_if_not_exists "nightscout-tool file" "$TOOL_FILE" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/install.sh"
		local timestamp=$(date +%s)
		echo "$timestamp" >"$UPDATES_DIR/timestamp"
	else
		msgok "Found nightscout-tool"
	fi

	if ! [[ -f $TOOL_LINK ]]; then
		ohai "Linking nightscout-tool"
		ln -s "$TOOL_FILE" "$TOOL_LINK"
	fi

	chmod +x "$TOOL_FILE"
	chmod +x "$TOOL_LINK"
}

download_updates() {
	ohai "Downloading updated scripts and config files"
	local onlineUpdated="$(curl -fsSL "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/updated")"
	if [ ! "$onlineUpdated" == "" ]; then
		curl -fsSL -o "$UPDATES_DIR/install.sh" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/install.sh"
		curl -fsSL -o "$UPDATES_DIR/deployment.env" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/templates/deployment.env"
		curl -fsSL -o "$UPDATES_DIR/nightscout.env" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/templates/nightscout.env"
		curl -fsSL -o "$UPDATES_DIR/docker-compose.yml" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/templates/docker-compose.yml"
		curl -fsSL -o "$PROFANITY_DB_FILE" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/profanity/templates/profanity.db"
		curl -fsSL -o "$RESERVED_DB_FILE" "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/profanity/templates/reserved.db"
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
		local onlineUpdated="$(curl -fsSL "https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch/$UPDATE_CHANNEL/updated")"
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

update_background_check() {
	download_if_needed

	local lastDownload=$(read_or_default "$UPDATES_DIR/downloaded" "")
	local updateInstalled=$(read_or_default "$UPDATES_DIR/updated" "")

	if [ ! "$lastDownload" == "$updateInstalled" ] && [ ! "$lastDownload" == "" ] && [ ! "$lastDownload" == "error" ]; then
		echo "Update needed"
		local lastCalled=$(get_since_last_time "update_needed")
		if ((lastCalled == -1)) || ((lastCalled > UPDATE_MAIL)); then
			set_last_time "update_needed"
			echo "Sending mail to user - tool update needed"
			{
				echo "✨ Na Twoim serwerze mikr.us z Nightscoutem można zaktualizować narzędzie nightscout-tool!"
				echo " "
				echo "🐕 Watchdog wykrył że dostępna jest nowa aktualizacja nightscout-tool."
				echo "Na Twoim serwerze zainstalowana jest starsza wersja narzędzia - zaktualizuj go by poprawić stabilność systemu i uzyskać dostęp do nowych funkcji."
				echo " "
				echo "Aby zaktualizować narzędzie:"
				echo " "
				echo "1. Zaloguj się do panelu administracyjnego mikrusa i zaloguj się do WebSSH:"
				echo "   https://mikr.us/panel/?a=webssh"
				echo " "
				echo "2. Uruchom narzędzie komendą:"
				echo "   nightscout-tool"
				echo " "
				echo "3. Potwierdź naciskając przycisk:"
				echo "   【 Aktualizacja 】"
				echo " "
			} | pusher "✨_Na_Twoim_serwerze_Nightscout_dostępna_jest_aktualizacja"
		fi
	fi
}
