#=======================================
# CLEANUP LOGIC
#=======================================

do_cleanup_sys() {
	ohai "Sprzątanie dziennik systemowego..."
	event_mark "cleanup"
	journalctl --vacuum-size=50M >>"$LOGTO" 2>&1
	ohai "Czyszczenie systemu apt..."
	msgnote "Ta operacja może TROCHĘ potrwać (od kilku do kilkudziesięciu minut...)"
	apt-get -y autoremove >>"$LOGTO" 2>&1 && apt-get -y clean >>"$LOGTO" 2>&1
	msgcheck "Czyszczenie dziennika i apt zakończono"
}

do_cleanup_docker() {
	ohai "Usuwanie nieużywanych obrazów Dockera..."
	event_mark "cleanup"
	msgnote "Ta operacja może TROCHĘ potrwać (do kilku minut...)"
	docker image prune -af >>"$LOGTO" 2>&1
	msgcheck "Czyszczenie Dockera zakończono"
}

do_cleanup_db() {
	ohai "Usuwanie kopii zapasowych bazy danych..."
	event_mark "cleanup"
	find /srv/nightscout/data/dbbackup ! -type d -delete
	msgcheck "Czyszczenie kopii zapasowych zakończono"
}

do_cleanup_container_logs() {
	ohai "Zatrzymywanie kontenerów..."
	event_mark "cleanup"
	docker stop 'ns-server'
	docker stop 'ns-database'
	docker stop 'ns-backup'
	ohai "Usuwanie logów kontenerów..."
	truncate -s 0 "$(docker inspect --format='{{.LogPath}}' 'ns-server')"
	truncate -s 0 "$(docker inspect --format='{{.LogPath}}' 'ns-database')"
	truncate -s 0 "$(docker inspect --format='{{.LogPath}}' 'ns-backup')"
	ohai "Ponowne uruchamianie kontenerów..."
	docker start 'ns-server'
	docker start 'ns-database'
	docker start 'ns-backup'
	msgok "Logi usunięte"
}

do_cleanup_diagnostics() {
	ohai "Sprzątanie diagnostyki"
	rm -f "$SUPPORT_LOG"
	rm -f "$SUPPORT_LOG.gz"
	rm -f "$SUPPORT_LOG.gz.asc"
}

do_cleanup_app_state() {
	ohai "Sprzątanie stanu aplikacji"
	rm -f "$UPDATE_CHANNEL_FILE"
	rm -f "$EVENTS_DB"
}

do_cleanup_app_logs() {
	ohai "Sprzątanie logów aplikacji"
	rm -f "$WATCHDOG_STATUS_FILE"
	rm -f "$WATCHDOG_TIME_FILE"
	rm -f "$WATCHDOG_LOG_FILE"
	rm -f "$WATCHDOG_FAILURES_FILE"
	rm -f "$WATCHDOG_CRON_LOG"
}

cleanup_stats() {
	local spaceInfo=$(get_space_info)
	local remainingTxt=$(echo "$spaceInfo" | awk '{print $3}' | numfmt --to iec-i --suffix=B)
	local totalTxt=$(echo "$spaceInfo" | awk '{print $2}' | numfmt --to iec-i --suffix=B)
	local percTxt=$(echo "$spaceInfo" | awk '{print $4}')
	local fixedPerc=${percTxt/[%]/=}

	local nowB=$(echo "$spaceInfo" | awk '{print $3}')
	local lastTimeB=$(echo "$lastTimeSpaceInfo" | awk '{print $3}')
	local savedB=$((nowB - lastTimeB))
	local savedTxt=$(echo "$savedB" | numfmt --to iec-i --suffix=B)

	if ((savedB < 1)); then
		savedTxt="---"
	fi

	local statusTitle="\n$(center_multiline 45 "$(
		pad_multiline \
			"  Dostępne: ${remainingTxt}" \
			"\n Zwolniono: ${savedTxt}" \
			"\n    Zajęte: ${fixedPerc} (z ${totalTxt})"
	)")\n"

	hline
	echo "${statusTitle/=/%}"
	hline
}

do_cleanup_all() {
	echo "Cleanup"
	hline
	do_cleanup_container_logs
	do_cleanup_sys
	do_cleanup_docker
	do_cleanup_db
	do_cleanup_diagnostics
	cleanup_stats
}