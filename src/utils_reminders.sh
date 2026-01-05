#=======================================
# REMINDERS
#=======================================

free_space_check() {
	lastTimeSpaceInfo=$(get_space_info)

	local remainingB=$(echo "$lastTimeSpaceInfo" | awk '{print $3}')
	local remainingTxt=$(echo "$lastTimeSpaceInfo" | awk '{print $3}' | numfmt --to iec-i --suffix=B)

	if ((remainingB < DISK_LOW_WARNING)); then
		if ((remainingB < DISK_CRITICAL_WARNING)); then
			local lastCalled=$(get_since_last_time "disk_critical")
			local domain=$(get_td_domain)
			if ((lastCalled == -1)) || ((lastCalled > DISK_CRITICAL_MAIL)); then
				set_last_time "disk_critical"
				{
					echo "Na twoim serwerze mikr.us z Nightscoutem (https://$domain) zostało krytycznie mało miejsca (${remainingTxt})!"
					echo " "
					echo "Tak mała ilość miejsca nie pozwala serwerowi na stabilne działanie!"
					echo "🚨PILNIE🚨 posprzątaj na serwerze, aby to zrobić możesz:"
					echo " "
					echo "1. Usunąć stare statusy i wpisy z poziomu strony Nightscout:"
					echo "   - wejdź do hamburger menu strony Nightscout i wybierz: 【 Narzędzia administratora 】- wymaga zalogowania"
					echo "     to powinno otwórzyć adres: https://${domain}/admin"
					echo "   - w polach tekstowych poustawiaj ile dni historii chcesz zachować, i w odpowiednich sekcjach kliknij:"
					echo "     【 Usuń stare dokumenty 】"
					echo " "
					echo "2. Posprzątać nieużywane pliki na serwerze mikr.us:"
					echo "   - zaloguj się na swój mikr.us do panelu administracyjnego, przejdź do WebSSH"
					echo "     https://mikr.us/panel/?a=webssh"
					echo "   - zaloguj się, uruchom narzędzie komendą: nightscout-tool"
					echo "   - wybierz: 【 C) Sprztąj... 】"
					echo "   - wybierz: 【 A) Posprzątaj wszystko 】 i potwierdź 【 Tak 】"
					echo "   - cierpliwie poczekaj, po sprzątaniu narzędzie pokaże ile miejsca zwolniono"
				} | pusher "🚨_Krytycznie_mało_miejsca_na_Twoim_serwerze_Nightscout!"
				echo "Free space on server: CRITICALLY LOW (${remainingTxt}) - sending email to user"
			else
				echo "Free space on server: CRITICALLY LOW (${remainingTxt}) - user already notified"
			fi
		else
			local lastCalled=$(get_since_last_time "disk_warning")
			local domain=$(get_td_domain)
			if ((lastCalled == -1)) || ((lastCalled > DISK_LOW_MAIL)); then
				set_last_time "disk_warning"
				{
					echo "Na twoim serwerze mikr.us z Nightscout-em (https://$domain) powoli kończy się miejsce (${remainingTxt})!"
					echo " "
					echo "🧹 W wolnej chwili posprzątaj na serwerze, aby to zrobić możesz:"
					echo " "
					echo "1. Usunąć stare statusy i wpisy z poziomu strony Nightscout:"
					echo "   - wejdź do hamburger menu strony Nightscout i wybierz:【 Narzędzia administratora 】- wymaga zalogowania"
					echo "     to powinno otwórzyć adres: https://${domain}/admin"
					echo "   - w polach tekstowych poustawiaj ile dni historii chcesz zachować, i w odpowiednich sekcjach kliknij:"
					echo "     【 Usuń stare dokumenty 】"
					echo " "
					echo "2. Posprzątać nieużywane pliki na serwerze mikr.us:"
					echo "   - zaloguj się na swój mikr.us do panelu administracyjnego, przejdź do WebSSH"
					echo "     https://mikr.us/panel/?a=webssh"
					echo "   - zaloguj się, uruchom narzędzie komendą: nightscout-tool"
					echo "   - wybierz: 【 C) Sprztąj... 】"
					echo "   - wybierz: 【 A) Posprzątaj wszystko 】 i potwierdź 【 Tak 】"
					echo "   - cierpliwie poczekaj, po sprzątaniu narzędzie pokaże ile miejsca zwolniono"
				} | pusher "🧹_Powoli_kończy_sie_miejsce_na_Twoim_serwerze_Nightscout!"
				echo "Free space on server: LOW (${remainingTxt}) - sending email to user"
			else
				echo "Free space on server: LOW (${remainingTxt}) - user already notified"
			fi
		fi
	else
		clear_last_time "disk_critical"
		clear_last_time "disk_warning"
		echo "Free space on server: OK (${remainingTxt})"
	fi
}

mail_restart_needed() {
	local whyRestart="$1"
	local mikrusSerwer=$(hostname)
	{
		echo "🛟 Twój serwer mikr.us z Nightscoutem potrzebuje restartu!"
		echo " "
		echo "🐕 Watchdog wykrył awarię której nie jest w stanie automatycznie naprawić:"
		echo "$whyRestart"
		echo " "
		echo "Potrzebna będzie Twoja pomoc z ręcznym restartem serwera:"
		echo " "
		echo "1. Zaloguj się do panelu administracyjnego mikrusa"
		echo "   https://mikr.us/panel/"
		echo " "
		echo "2. Znajdź kafelek z nazwą serwera (${mikrusSerwer}) i kliknij na przycisk pod nim:"
		echo "   【 Restart 】"
		echo " "
		echo "3. Potwierdź naciskając przycisk:"
		echo "   【 Poproszę o restart VPSa 】"
		echo " "
		echo "=========================================================="
		echo " "
		echo "⏳ Restart serwera potrwa kilka minut, kolejne kilka minut potrwa uruchomienie serwera Nightscout"
		echo "Jeśli po kilkunastu minutach serwer nie zacznie działać poprawnie:"
		echo "Zaloguj się do panelu mikr.us-a, zaloguj się do WebSSH i w nightscout-tool sprawdź:"
		echo "- czy kontenery są uruchomione - ich status i logi"
		echo "- czy jest dosyć wolnego miejsca"
		echo "W razie potrzeby - 🔄 zrestartuj kontenery i uruchom 🧹 sprzątanie (ale NIE usuwaj logów!)."
		echo " "
		echo "=========================================================="
		echo " "
		echo "Jeśli to nie pomoże, poszukaj wsparcia na grupie Technologie Diabetyka"
		echo "   🙋 https://www.facebook.com/groups/techdiab"
		echo "i - po uzgodnieniu!!! - wyślij diagnostykę do autora skryptu:"
		echo "   📜 https://t1d.dzienia.pl/nightscout_mikrus_tutorial/stabilna/5.troubleshooting/#wysyanie-diagnostyki"
		echo " "
	} | pusher "🛟_Twoj_serwer_Nightscout_potrzebuje_ręcznego_restartu!"
}