# shellcheck disable=SC2148
# shellcheck disable=SC2155

#dev-begin
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# IMPORTS
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# shellcheck source=./headers.sh
source ./headers.sh
#dev-end

#=======================================
# CLEANUP UI
#=======================================

prompt_cleanup_container_logs() {
	yesnodlg "Usunąć logi kontenerów?" "$uni_delete" "$uni_leave_logs" \
		"Czy chcesz usunąć logi kontenerów nightscout i bazy?" \
		"${TL}Jeśli Twój serwer działa poprawnie," \
		"${NL}- możesz spokojnie usunąć logi." \
		"${TL}Jeśli masz problem z serwerem - zostaw logi!" \
		"${NL}- logi mogą być niezbędne do diagnostyki" \
		"${TL}(ta operacja uruchomi ponownie kontenery)"
}

cleanup_menu() {

	while :; do

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

		local CHOICE=$(whiptail --title "Sprzątanie" --menu \
			"${statusTitle/=/%}" \
			17 50 6 \
			"A)" "Posprzątaj wszystko" \
			"S)" "Posprzątaj zasoby systemowe" \
			"D)" "Usuń nieużywane obrazy Dockera" \
			"B)" "Usuń kopie zapasowe bazy danych" \
			"L)" "Usuń logi kontenerów" \
			"M)" "Powrót do menu" \
			--ok-button="Wybierz" --cancel-button="$uni_back" \
			3>&2 2>&1 1>&3)

		case $CHOICE in
		"A)")
			noyesdlg "Posprzątać wszystko?" "$uni_confirm_del" "$uni_resign" \
				"Czy chcesz posprzątać i usunąć:" \
				"$(pad_multiline \
					"${TL}${uni_bullet}nieużywane pliki apt i dziennika" \
					"${NL}${uni_bullet}nieużywane obrazy Dockera" \
					"${NL}${uni_bullet}kopie zapasowe bazy danych" \
					"${NL}${uni_bullet}opcjonalnie - logi Nightscouta i bazy")${NL}" \
				"${TL}(☕ to może potrwać nawet kilkadziesiąt minut)"
			if ! [ $? -eq 1 ]; then
				prompt_cleanup_container_logs
				if ! [ $? -eq 1 ]; then
					do_cleanup_container_logs
					do_cleanup_sys
					do_cleanup_docker
					do_cleanup_db
				else
					do_cleanup_sys
					do_cleanup_docker
					do_cleanup_db
				fi
			fi
			;;
		"S)")
			noyesdlg "Posprzątać zasoby systemowe?" "$uni_confirm_del" "$uni_resign" \
				"Czy chcesz usunąć nieużywane pakiety apt${NL}i poprzątać dziennik systemowy?" \
				"${TL}(☕ to może potrwać nawet kilkadziesiąt minut)"
			if ! [ $? -eq 1 ]; then
				do_cleanup_sys
			fi
			;;
		"D)")
			noyesdlg "Posprzątać obrazy Dockera?" "$uni_confirm_del" "$uni_resign" \
				"Czy chcesz usunąć nieużywane obrazy Dockera?" \
				"${TL}(☕ to może potrwać kilka minut)"
			if ! [ $? -eq 1 ]; then
				do_cleanup_docker
			fi
			;;
		"B)")
			noyesdlg "Usunąć kopie zapasowe bazy danych?" "$uni_confirm_del" "$uni_resign" \
				"Czy chcesz usunąć kopie zapasowe bazy danych?" \
				"${NL}(na razie i tak nie ma automatycznego mechanizmu ich wykorzystania)"
			if ! [ $? -eq 1 ]; then
				do_cleanup_db
			fi
			;;
		"L)")
			prompt_cleanup_container_logs
			if ! [ $? -eq 1 ]; then
				do_cleanup_container_logs
			fi
			;;
		"M)")
			break
			;;
		"")
			break
			;;
		esac
	done
}
