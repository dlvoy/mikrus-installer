#=======================================
# WATCHDOG LOGIC
#=======================================

get_watchdog_age_string() {
	local last_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	local curr_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

	if [[ -f $WATCHDOG_TIME_FILE ]]; then
		last_time=$(cat "$WATCHDOG_TIME_FILE")
		local status_ago=$(dateutils.ddiff "$last_time" "$curr_time" -f '%Mmin. %Ssek.')
		echo "$last_time ($status_ago temu)"
	else
		echo "jescze nie uruchomiony"
	fi
}

get_watchdog_status_code() {
	local curr_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	local last_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	local status="unknown"

	if [[ -f $WATCHDOG_TIME_FILE ]]; then
		last_time=$(cat "$WATCHDOG_TIME_FILE")
	fi

	if [[ -f $WATCHDOG_STATUS_FILE ]]; then
		status=$(cat "$WATCHDOG_STATUS_FILE")
	fi

	local status_ago=$(dateutils.ddiff "$curr_time" "$last_time" -f '%S')

	if [ "$status_ago" -gt 900 ]; then
		status="unknown"
	fi

	echo "$status"
}

get_watchdog_status_code_live() {
	local curr_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	local last_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	local status="unknown"

	if [[ -f $WATCHDOG_TIME_FILE ]]; then
		last_time=$(cat "$WATCHDOG_TIME_FILE")
	fi

	if [[ -f $WATCHDOG_STATUS_FILE ]]; then
		status=$(cat "$WATCHDOG_STATUS_FILE")
	fi

	local status_ago=$(dateutils.ddiff "$curr_time" "$last_time" -f '%S')

	if [ "$status_ago" -gt 900 ]; then
		status="unknown"
	fi

	local NS_STATUS=$(get_container_status_code 'ns-server')
	local DB_STATUS=$(get_container_status_code 'ns-database')
	local COMBINED_STATUS="$NS_STATUS $DB_STATUS"

	if [ "$COMBINED_STATUS" = "running running" ]; then

		status="detection_failed"

		local domain=$cachedMenuDomain
		local cachedDomainLen=${#cachedMenuDomain}
		if ((cachedDomainLen < 16)); then
			domain=$(get_td_domain)
		fi

		local domainLen=${#domain}
		if ((domainLen > 15)); then
			cachedMenuDomain=$domain
			local html=$(curl -Lks "$domain")

			if [[ "$html" =~ github.com/nightscout/cgm-remote-monitor ]]; then
				status="ok"
			fi

			if [[ "$html" =~ 'MongoDB connection failed' ]]; then
				status="crashed"
			fi

			regex3='poszło nie tak'
			if [[ "$html" =~ $regex3 ]]; then
				status="awaiting"
			fi

		else
			status="domain_failed"
		fi

	else
		if [ "$NS_STATUS" = "restarting" ] || [ "$DB_STATUS" = "restarting" ]; then
			status="awaiting"
		else
			local logSample=$(timeout -k 15 10 docker logs ns-server --tail "10" 2>&1)
			local regexSample='Cannot connect to the Docker daemon'
			if [[ "$logSample" =~ $regexSample ]]; then
				status="docker_down"
			else
				status="not_running"
			fi
		fi
	fi

	echo "$status"
}

get_watchdog_status() {
	local status="$1"
	case "$status" in
	"ok")
		echo "$2"
		;;
	"restart")
		printf "\U1F680 wymuszono restart NS"
		;;
	"awaiting")
		printf "\U23F3 uruchamia się"
		;;
	"restart_failed")
		printf "\U1F680 restart NS to za mało"
		;;
	"full_restart")
		printf "\U1F680 restart NS i DB"
		;;
	"unknown")
		printf "\U1F4A4 brak statusu"
		;;
	"not_running")
		printf "\U1F534 serwer nie działa"
		;;
	"detection_failed")
		printf "\U2753 nieznany stan"
		;;
	"domain_failed")
		printf "\U2753 problem z domeną"
		;;
	"crashed")
		printf "\U1F4A5 awaria NS"
		;;
	"docker_down")
		printf "\U1F4A5 awaria Dockera"
		;;
	esac

}

watchdog_check() {
	echo "---------------------------"
  echo " Nightscout Watchdog mode"
	echo "---------------------------"

	WATCHDOG_LAST_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	WATCHDOG_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	WATCHDOG_LAST_STATUS="unknown"
	WATCHDOG_STATUS="unknown"

	if [[ -f $WATCHDOG_TIME_FILE ]]; then
		echo "Found $WATCHDOG_TIME_FILE"
		WATCHDOG_LAST_TIME=$(cat "$WATCHDOG_TIME_FILE")
	else
		echo "First watchdog run"
	fi

	if [[ -f $WATCHDOG_STATUS_FILE ]]; then
		echo "Found $WATCHDOG_STATUS_FILE"
		WATCHDOG_LAST_STATUS=$(cat "$WATCHDOG_STATUS_FILE")
	fi

	local STATUS_AGO=$(dateutils.ddiff "$WATCHDOG_TIME" "$WATCHDOG_LAST_TIME" -f '%S')

	if [ "$STATUS_AGO" -gt 900 ]; then
		echo "Watchdog last status is $STATUS_AGO seconds old, ignoring"
		WATCHDOG_LAST_STATUS="unknown"
	fi

	free_space_check
	update_background_check

	local NS_STATUS=$(get_container_status_code 'ns-server')
	local DB_STATUS=$(get_container_status_code 'ns-database')
	local COMBINED_STATUS="$NS_STATUS $DB_STATUS"

	echo "Server container: $NS_STATUS"
	echo "Database container: $DB_STATUS"

	if [ "$COMBINED_STATUS" = "running running" ]; then

		clear_last_time "docker_down"
		clear_last_time "server_restart_needed"

		echo "Will check page contents"
		local domain=$(get_td_domain)

		local domainLen=${#domain}
		if ((domainLen > 15)); then
			local html=$(curl -iLsk "$domain")

			WATCHDOG_STATUS="detection_failed"

			if [[ "$html" =~ github.com/nightscout/cgm-remote-monitor ]]; then
				echo "Nightscout is running"
				WATCHDOG_STATUS="ok"
			fi

			if [[ "$html" =~ 'MongoDB connection failed' ]]; then
				echo "Nightscout crash detected"
				WATCHDOG_STATUS="restart"
				if [ "$WATCHDOG_LAST_STATUS" == "restart_failed" ]; then
					event_mark "restart_both"
					echo "Restarting DB first..."
					docker restart 'ns-database'
					echo "Then, restarting Nightscout..."
					docker restart 'ns-server'
					echo "...done"
					WATCHDOG_STATUS="full_restart"
				else
					if [ "$WATCHDOG_LAST_STATUS" != "restart" ]; then
						event_mark "restart_ns"
						echo "Restarting only Nightscout..."
						docker restart 'ns-server'
						echo "...done"
					else
						echo "Restart was tried but NS still crashed, will retry restart next time"
						WATCHDOG_STATUS="restart_failed"
					fi
				fi
			else
				regex3='poszło nie tak'
				if [[ "$html" =~ $regex3 ]]; then
					echo "Nightscout is still restarting..."
					WATCHDOG_STATUS="awaiting"
				fi
			fi

			if [ "$WATCHDOG_STATUS" = "detection_failed" ]; then
				{
					hline
					echo "[$WATCHDOG_TIME] Unknown server failure:"
					echo "CONTAINERS:"
					docker stats --no-stream
					echo "HTTP DUMP:"
					echo "$html"
				} >>"$WATCHDOG_FAILURES_FILE"
			fi

		else
			WATCHDOG_STATUS="domain_failed"
		fi

	else
		if [ "$NS_STATUS" = "restarting" ] || [ "$DB_STATUS" = "restarting" ]; then
			WATCHDOG_STATUS="awaiting"
		else
			WATCHDOG_STATUS="not_running"

			local logSample=$(timeout -k 15 10 docker logs ns-server --tail "10" 2>&1)
			local regexSample='Cannot connect to the Docker daemon'
			if [[ "$logSample" =~ $regexSample ]]; then
				WATCHDOG_STATUS="docker_down"
				if [ "$WATCHDOG_LAST_STATUS" != "docker_down" ]; then
					echo "Cannot connect to Docker, will restart service..."
					set_last_time "docker_down"
					sudo systemctl restart docker
				else
					echo "Cannot connect to Docker, and service cannot be restarted"
					local lastCalled=$(get_since_last_time "server_restart_needed")
					if ((lastCalled == -1)) || ((lastCalled > DOCKER_DOWN_MAIL)); then
						set_last_time "server_restart_needed"
						echo "Sending mail to user - manual server restart needed"
						mail_restart_needed "Usługa Docker uległa awarii i nie można automatycznie jej uruchomić"
					else
						echo "Mail for manual restart already recently sent"
					fi
				fi
			fi
		fi
	fi

	echo "Watchdog observation: $WATCHDOG_STATUS"

	# if [ "$WATCHDOG_LAST_STATUS" != "$WATCHDOG_STATUS" ]; then
	echo "$WATCHDOG_TIME [$WATCHDOG_STATUS]" >>"$WATCHDOG_LOG_FILE"
	LOGSIZE=$(wc -l <"$WATCHDOG_LOG_FILE")
	if [ "$LOGSIZE" -gt 1000 ]; then
		tail -1000 "$WATCHDOG_LOG_FILE" >"$WATCHDOG_LOG_FILE.tmp"
		mv -f "$WATCHDOG_LOG_FILE.tmp" "$WATCHDOG_LOG_FILE"
	fi
	# fi

	if [[ -f $WATCHDOG_FAILURES_FILE ]]; then
		FAILSIZE=$(wc -l <"$WATCHDOG_FAILURES_FILE")
		if [ "$FAILSIZE" -gt 10000 ]; then
			tail -10000 "$WATCHDOG_FAILURES_FILE" >"$WATCHDOG_FAILURES_FILE.tmp"
			mv -f "$WATCHDOG_FAILURES_FILE.tmp" "$WATCHDOG_FAILURES_FILE"
		fi
	fi

	echo "$WATCHDOG_TIME" >"$WATCHDOG_TIME_FILE"
	echo "$WATCHDOG_STATUS" >"$WATCHDOG_STATUS_FILE"

	exit 0
}
