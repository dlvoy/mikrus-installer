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

	if ! curl -fsSL -o "$target" "$url"; then
		if [[ -z "$GITHUB_UNAVAILABLE" ]]; then
			mark_github_unavailable
			url=$(get_url_branch "$branch" "$path")
			ohai "GitHub failed, retrying with Gitea ($label)..."
			curl -fsSL -o "$target" "$url"
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
	local onlineUpdated=$(curl -fsSL "$url")

	if [[ -z "$onlineUpdated" && -z "$GITHUB_UNAVAILABLE" ]]; then
		mark_github_unavailable
		url=$(get_url "updated")
		ohai "GitHub failed, retrying with Gitea (update check)..."
		onlineUpdated=$(curl -fsSL "$url")
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
		local onlineUpdated=$(curl -fsSL "$url")

		if [[ -z "$onlineUpdated" && -z "$GITHUB_UNAVAILABLE" ]]; then
			mark_github_unavailable
			url=$(get_url "updated")
			ohai "GitHub failed, retrying with Gitea (version check)..."
			onlineUpdated=$(curl -fsSL "$url")
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
