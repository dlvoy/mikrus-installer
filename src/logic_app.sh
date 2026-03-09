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
# APP LOGIC
#=======================================

update_logto() {
	if [[ "$UPDATE_CHANNEL" == "develop" || "$FORCE_DEBUG_LOG" == "1" ]]; then
		LOGTO="$DEBUG_LOG_FILE"
	else
		#shellcheck disable=SC2034
		LOGTO=/dev/null
	fi
}

get_td_domain_from_api() {
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

invalidate_domain_cache() {
	echo "" >"$DOMAIN_UPDATE_TIMESTAMP"
	echo "" >"$DOMAIN_NAME_FILE"
}

get_td_domain() {
	local domain=""
	local cache_age=999999
	local now
	now=$(date +%s)

	# Check if we have a valid timestamp and cached domain
	if [[ -f "$DOMAIN_UPDATE_TIMESTAMP" && -f "$DOMAIN_NAME_FILE" ]]; then
		local last_update
		last_update=$(cat "$DOMAIN_UPDATE_TIMESTAMP" | tr -d '[:space:]')
		if [[ -n "$last_update" && "$last_update" =~ ^[0-9]+$ ]]; then
			cache_age=$((now - last_update))
		fi
	fi

	# Use cache if it's less than 24 hours old and contains a valid (non-empty) domain
	if ((cache_age < 86400)); then
		local cached_domain
		cached_domain=$(cat "$DOMAIN_NAME_FILE" 2>/dev/null | tr -d '[:space:]')
		if [[ -n "$cached_domain" ]]; then
			if [[ "$UPDATE_CHANNEL" == "develop" || "$FORCE_DEBUG_LOG" == "1" ]]; then
				echo "domain: from cache (${cache_age}s old): $cached_domain" >>"$DEBUG_LOG_FILE"
			fi
			echo "$cached_domain"
			return
		fi
	fi

	# Cache miss, stale, or empty cached value - fetch from API
	local raw_domain
	raw_domain=$(get_td_domain_from_api)
	domain=$(echo "$raw_domain" | tr -d '[:space:]')

	# Save result to cache; empty result is also saved so it can be detected as
	# "unknown" - empty cached value causes re-check on every subsequent call
	echo "$domain" >"$DOMAIN_NAME_FILE"
	if [[ -n "$domain" ]]; then
		echo "$now" >"$DOMAIN_UPDATE_TIMESTAMP"
		if [[ "$UPDATE_CHANNEL" == "develop" || "$FORCE_DEBUG_LOG" == "1" ]]; then
			echo "domain: freshly retrieved from API: $domain" >>"$DEBUG_LOG_FILE"
		fi
	else
		# Clear timestamp so next call always retries the API when domain is empty
		echo "" >"$DOMAIN_UPDATE_TIMESTAMP"
		if [[ "$UPDATE_CHANNEL" == "develop" || "$FORCE_DEBUG_LOG" == "1" ]]; then
			echo "domain: API returned empty result, cache cleared" >>"$DEBUG_LOG_FILE"
		fi
	fi

	echo "$domain"
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
		update_logto
	fi
}

startup_version() {
	local updateInstalled=$(read_or_default "$UPDATES_DIR/updated" "???")
	msgnote "nightscout-tool version $SCRIPT_VERSION ($SCRIPT_BUILD_TIME)"
	msgnote "build ${updateInstalled}"
	msgnote "$uni_copyright 2023-2026 Dominik Dzienia"
	msgnote "Licensed under CC BY-NC-ND 4.0"
	if [[ -f $UPDATE_CHANNEL_FILE ]]; then
		msgok "Loaded update channel: $UPDATE_CHANNEL"
	fi
}

startup_debug() {
	if [[ "$UPDATE_CHANNEL" == "develop" || "$FORCE_DEBUG_LOG" == "1" ]]; then
		msgdebug "Debug logging enabled - see: $DEBUG_LOG_FILE"
	fi
}

do_restart() {
	msgnote "Restarting containers..."
	uninstall_containers
	install_containers
	msgok "Restarted"
}

do_update_ns() {
	msgnote "Updating Nightscout and Mongo containers (downloading latest images)..."
	uninstall_containers
	update_containers
	msgok "Updated"
}
