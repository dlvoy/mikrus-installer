#=======================================
# DIAGNOSTICS
#=======================================

gather_diagnostics() {

	local maxNsLogs=$1
	local maxDbLogs=$2
	local curr_time=$3

	diagnosticsSizeOk=0

	do_cleanup_diagnostics

	ohai "Zbieranie diagnostyki"

	local domain=$(get_td_domain)
	local ns_tag=$(dotenv-tool -r get -f "$ENV_FILE_DEP" "NS_NIGHTSCOUT_TAG")
	local mikrus_h=$(hostname)
	local updateInstalled=$(read_or_default "$UPDATES_DIR/updated" "???")

	local LOG_DIVIDER="======================================================="

	{
		echo "Dane diagnostyczne zebrane $curr_time"
		echo "                 serwer : $mikrus_h"
		echo "                 domena : $domain"
		echo "      wersja nightscout : $ns_tag"
		echo " wersja nightscout-tool : $SCRIPT_VERSION ($SCRIPT_BUILD_TIME) $UPDATE_CHANNEL"
		echo "                  build : ${updateInstalled}"
	} >"$SUPPORT_LOG"

	ohai "Zbieranie statusu usług"

	{
		echo "$LOG_DIVIDER"
		echo " Statusy usług"
		echo "$LOG_DIVIDER"
		echo "   Nightscout:  $(get_container_status 'ns-server')"
		echo "  Baza danych:  $(get_container_status 'ns-database')"
		echo "       Backup:  $(get_container_status 'ns-backup')"
		echo "     Watchdog:  $(get_watchdog_status "$(get_watchdog_status_code)" "$uni_watchdog_ok")"
	} >>"$SUPPORT_LOG"

	local spaceInfo=$(get_space_info)
	local remainingTxt=$(echo "$spaceInfo" | awk '{print $3}' | numfmt --to iec-i --suffix=B)
	local totalTxt=$(echo "$spaceInfo" | awk '{print $2}' | numfmt --to iec-i --suffix=B)
	local percTxt=$(echo "$spaceInfo" | awk '{print $4}')

	{
		echo "$LOG_DIVIDER"
		echo " Miejsce na dysku"
		echo "$LOG_DIVIDER"
		echo "  Dostępne: ${remainingTxt}"
		echo "    Zajęte: ${percTxt} (z ${totalTxt})"
	} >>"$SUPPORT_LOG"

	ohai "Zbieranie zdarzeń"
	{
		echo "$LOG_DIVIDER"
		echo " Zdarzenia"
		echo "$LOG_DIVIDER"
		event_list
	} >>"$SUPPORT_LOG"

	ohai "Zbieranie logów watchdoga"

	if [[ -f $WATCHDOG_LOG_FILE ]]; then
		{
			echo "$LOG_DIVIDER"
			echo " Watchdog log"
			echo "$LOG_DIVIDER"
			timeout -k 15 10 tail -n 200 "$WATCHDOG_LOG_FILE"
		} >>"$SUPPORT_LOG"
	fi

	if [[ -f $WATCHDOG_FAILURES_FILE ]]; then
		{
			echo "$LOG_DIVIDER"
			echo " Watchdog failures log"
			echo "$LOG_DIVIDER"
			timeout -k 15 10 tail -n 200 "$WATCHDOG_FAILURES_FILE"
		} >>"$SUPPORT_LOG"
	fi

	ohai "Zbieranie logów usług"

	{
		echo "$LOG_DIVIDER"
		echo " Nightscout log"
		echo "$LOG_DIVIDER"
		timeout -k 15 10 docker logs ns-server --tail "$maxNsLogs" >>"$SUPPORT_LOG" 2>&1
		echo "$LOG_DIVIDER"
		echo " MongoDB database log"
		echo "$LOG_DIVIDER"
		timeout -k 15 10 docker logs ns-database --tail "$maxDbLogs" >>"$SUPPORT_LOG" 2>&1
	} >>"$SUPPORT_LOG"

	ohai "Kompresowanie i szyfrowanie raportu"

	gzip -9 "$SUPPORT_LOG"

	local logkey=$(<"$LOG_ENCRYPTION_KEY_FILE")

	gpg --passphrase "$logkey" --batch --quiet --yes -a -c "$SUPPORT_LOG.gz"
}

retry_diagnostics() {
	local maxNsLogs=$1
	local maxDbLogs=$2
	local curr_time=$3

	if ((diagnosticsSizeOk == 0)); then

		ohai "Sprawdzanie rozmiaru raportu"

		local logSize=$(stat --printf="%s" "$SUPPORT_LOG.gz.asc")
		local allowedTxt=$(echo "18000" | numfmt --to si --suffix=B)
		local currentTxt=$(echo "$logSize" | numfmt --to si --suffix=B)

		if ((logSize > 18000)); then
			msgerr "Zebrana diagnostyka jest zbyt duża do wysłania (${currentTxt})"
			ohai "Spróbuję zebrać mniej danych aby zmieścić się w limicie (${allowedTxt})"
			gather_diagnostics "$maxNsLogs" "$maxDbLogs" "$curr_time"
		else
			diagnosticsSizeOk=1
			msgok "Raport ma rozmiar ${currentTxt} i mieści się w limicie ${allowedTxt} dla usługi pusher-a"
		fi
	fi
}