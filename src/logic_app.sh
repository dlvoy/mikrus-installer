#=======================================
# APP LOGIC
#=======================================

get_td_domain() {
	local MHOST=$(hostname)
	if ! [[ "$MHOST" =~ [a-zA-Z]{2,16}[0-9]{3} ]]; then
		MIKRUS_APIKEY=$(cat "/klucz_api")
		MIKRUS_INFO_HOST=$(curl -s -d "srv=$MHOST&key=$MIKRUS_APIKEY" -X POST https://api.mikr.us/info | jq -r .imie_id)
		if [[ "$MIKRUS_INFO_HOST" =~ [a-zA-Z]{2,16}[0-9]{3} ]]; then
			MHOST="$MIKRUS_INFO_HOST"
		fi
	fi
	local APIKEY=$(dotenv-tool -r get -f "$ENV_FILE_ADMIN" "MIKRUS_APIKEY")
	curl -sd "srv=$MHOST&key=$APIKEY" https://api.mikr.us/domain | jq -r ".[].name" | grep ".ns.techdiab.pl" | head -n 1
}

get_domain_status() {
	local domain=$(get_td_domain)
	local domainLen=${#domain}
	if ((domainLen > 15)); then
		printf "\U1F7E2 %s" "$domain"
	else
		printf "\U26AA nie zarejestrowano"
	fi
}

load_update_channel() {
	if [[ -f $UPDATE_CHANNEL_FILE ]]; then
		UPDATE_CHANNEL=$(cat "$UPDATE_CHANNEL_FILE")
		msgok "Loaded update channel: $UPDATE_CHANNEL"
	fi
}

startup_version() {
	local updateInstalled=$(read_or_default "$UPDATES_DIR/updated" "???")
	msgnote "nightscout-tool version $SCRIPT_VERSION ($SCRIPT_BUILD_TIME)"
	msgnote "build ${updateInstalled}"
	msgnote "$uni_copyright 2023-2026 Dominik Dzienia"
	msgnote "Licensed under CC BY-NC-ND 4.0"
}
