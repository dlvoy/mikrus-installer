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
