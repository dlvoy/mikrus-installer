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
# WATCHDOG UI
#=======================================

show_watchdog_logs() {
	local col=$((COLUMNS - 10))
	local rws=$((LINES - 3))
	if [ "$col" -gt 120 ]; then
		col=160
	fi
	if [ "$col" -lt 60 ]; then
		col=60
	fi
	if [ "$rws" -lt 12 ]; then
		rws=12
	fi

	local tmpfile=$(mktemp)
	{
		echo "Ostatnie uruchomienie watchdoga:"
		get_watchdog_age_string
		hline

		if [[ -f $WATCHDOG_LOG_FILE ]]; then
			echo "Statusy ostatnich przebiegów watchdoga:"
			tail -5 "$WATCHDOG_LOG_FILE"
		else
			echo "Brak logów z ostatnich przebiegów watchdoga"
		fi
		hline

		if [[ -f $WATCHDOG_CRON_LOG ]]; then
			echo "Log ostatniego przebiegu watchdoga:"
			cat "$WATCHDOG_CRON_LOG"
		fi
	} >"$tmpfile"

	whiptail --title "Logi Watchdoga" --scrolltext --textbox "$tmpfile" "$rws" "$col"
	rm "$tmpfile"
}
