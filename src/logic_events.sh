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
# EVENTS MARKERS LOGIC
#=======================================

event_mark() {
	local eventName=$1
	local eventTime=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	mkdir -p "/srv/nightscout/data" >>"$LOGTO" 2>&1
	dotenv-tool -r -i "${EVENTS_DB}" -m "${eventName}=${eventTime}"
}

event_label() {
	case $1 in
	cleanup)
		echo "Czyszczenie"
		;;
	install)
		echo "Instalacja"
		;;
	update_system)
		echo "Aktualizacja systemu"
		;;
	update_tool)
		echo "Aktualizacja narzędzia"
		;;
	update_containers)
		echo "Aktualizacja kontenerów"
		;;
	uninstall)
		echo "Odinstalowanie"
		;;
	remove_containers)
		echo "Usunięcie kontenerów"
		;;
	remove_db_data)
		echo "Usunięcie danych bazy"
		;;
	remove_all_data)
		echo "Usunięcie danych"
		;;
	change_ns_version)
		echo "Zmiana wersji Nightscout"
		;;
	edit_env_manual)
		echo "Edycja konfiguracji"
		;;
	restart_both)
		echo "Wymuszony restart NS+DB"
		;;
	restart_ns)
		echo "Wymuszony restart NS"
		;;
	last_disk_warning)
		echo "Brak miejsca"
		;;
	last_disk_critical)
		echo "Krytyczny brak miejsca"
		;;
	last_docker_down)
		echo "Awaria Dockera"
		;;
	last_server_restart_needed)
		echo "Potrzebny restart serwera"
		;;
	last_update_needed)
		echo "Potrzebna aktualizacja"
		;;
	*)
		echo "$1"
		;;
	esac
}

event_count() {
	if [ ! -f "${EVENTS_DB}" ]; then
		echo "0"
	else
		local eventsJSON=$(dotenv-tool parse -r -f "${EVENTS_DB}")
		local eventsKeysStr=$(echo "${eventsJSON}" | jq -r ".values | keys[]")

		if [[ -z "$eventsKeysStr" ]]; then
			echo "0"
			return
		fi

		mapfile -t eventList < <(echo "${eventsKeysStr}")
		local count=0
		local processedNames=()

		for eventId in "${eventList[@]}"; do
			# Parse eventName and eventTail (suffix)
			mapfile -t -d '_' eventIdSplit <<<"${eventId}"
			local eventTail=$(echo "${eventIdSplit[-1]}" | tr -d '\n')
			unset "eventIdSplit[-1]"
			printf -v eventBase '%s_' "${eventIdSplit[@]}"
			local eventName="${eventBase%_}"
			if [ ${#eventIdSplit[@]} -eq 0 ]; then
				eventName="$eventTail"
				eventTail=""
			fi

			if [[ "$eventTail" == "start" ]] || [[ "$eventTail" == "end" ]]; then
				# Group start/end as one
				if [[ ! " ${processedNames[*]} " =~ [[:space:]]${eventName}[[:space:]] ]]; then
					processedNames+=("${eventName}")
					((count++))
				fi
			elif [[ "$eventTail" == "set" ]]; then
				((count++))
			elif [[ "$eventTail" == "clear" ]]; then
				# Count clear only if set exists
				local hasSet=$(echo "$eventsJSON" | jq -r ".values.${eventName}_set")
				if [[ "$hasSet" != "null" ]]; then
					((count++))
				fi
			else
				# Lone event (no suffix)
				((count++))
			fi
		done
		echo "$count"
	fi
}

event_list() {
	if [ ! -f "${EVENTS_DB}" ]; then
		echo "Nie odnotowano zdarzeń"
	else
		local eventsJSON=$(dotenv-tool parse -r -f "${EVENTS_DB}")
		local eventsKeysStr=$(echo "${eventsJSON}" | jq -r ".values | keys[]")
		local eventsCount=${#eventsKeysStr}

		if ((eventsCount > 0)); then
			mapfile -t eventList < <(echo "${eventsKeysStr}")

			local namesTab=()
			local labelsTab=()
			local valuesTab=()
			for eventId in "${eventList[@]}"; do
				mapfile -t -d '_' eventIdSplit <<<"${eventId}"
				local eventTail=$(echo "${eventIdSplit[-1]}" | tr -d '\n')
				unset "eventIdSplit[-1]"
				printf -v eventBase '%s_' "${eventIdSplit[@]}"
				local eventName="${eventBase%_}"
				if [ ${#eventIdSplit[@]} -eq 0 ]; then
					eventName="$eventTail"
					eventTail=""
				fi

				if [[ "$eventTail" == "start" ]] || [[ "$eventTail" == "end" ]]; then
					if [[ ! " ${namesTab[*]} " =~ [[:space:]]${eventName}[[:space:]] ]]; then
						namesTab+=("${eventName}")
						local startVar=$(echo "$eventsJSON" | jq -r ".values.${eventName}_start")
						local endVar=$(echo "$eventsJSON" | jq -r ".values.${eventName}_end")
						local joinedVar="od: $startVar do: $endVar"
						local fixedVar=$(echo "$joinedVar" | sed -E -e "s/ ?(od|do): null ?//g")
						if [[ "$fixedVar" =~ od: ]] && [[ "$fixedVar" =~ do: ]]; then
							fixedVar=$(echo "$fixedVar" | sed -E -e "s/do:/\ndo:/g")
						fi
						fixedVar=$(echo "$fixedVar" | sed -E -e "s/od:/🕓/g")
						fixedVar=$(echo "$fixedVar" | sed -E -e "s/do:/✅/g")
						valuesTab+=("$fixedVar")
					fi
				else
					if [[ "$eventTail" == "set" ]] || [[ "$eventTail" == "clear" ]]; then
						local startVar=$(echo "$eventsJSON" | jq -r ".values.${eventName}_set")
						local endVar=$(echo "$eventsJSON" | jq -r ".values.${eventName}_clear")

						# Filter out orphaned clear events (clear exists but set does not)
						if [[ "$startVar" == "null" ]] && [[ "$endVar" != "null" ]]; then
							continue
						fi

						if [[ ! " ${namesTab[*]} " =~ [[:space:]]${eventName}[[:space:]] ]]; then
							namesTab+=("${eventName}")
							local joinedVar="od: $startVar zdjęto: $endVar"
							local fixedVar=$(echo "$joinedVar" | sed -E -e "s/ ?(od|zdjęto): null ?//g")
							if [[ "$fixedVar" =~ od: ]] && [[ "$fixedVar" =~ zdjęto: ]]; then
								fixedVar=$(echo "$fixedVar" | sed -E -e "s/zdjęto:/\nzdjęto:/g")
							fi
							fixedVar=$(echo "$fixedVar" | sed -E -e "s/od:/🚩/g")
							fixedVar=$(echo "$fixedVar" | sed -E -e "s/zdjęto:/🏁/g")
							valuesTab+=("$fixedVar")
						fi
					else
						namesTab+=("${eventId}")
						local exactVar=$(echo "$eventsJSON" | jq -r ".values.${eventId}")
						valuesTab+=("🕓 $exactVar")
					fi
				fi
			done

			local maxLen=0

			for ((i = 0; i < ${#namesTab[@]}; i++)); do
				local eventLab="$(event_label "${namesTab[$i]}")"
				local labelLen=${#eventLab}
				maxLen=$((labelLen > maxLen ? labelLen : maxLen))
				labelsTab+=("$eventLab")
			done

			maxLen=$((maxLen + 1))

			for ((i = 0; i < ${#namesTab[@]}; i++)); do
				mapfile -t valuesLines <<<"${valuesTab[$i]}"
				local linesCount=${#valuesLines[@]}
				if ((linesCount > 1)); then
					local spaces="                                                                      "
					echo "$(lpad_text "${labelsTab[$i]}" "$maxLen") = ${valuesLines[0]}"
					for ((l = 1; l < linesCount; l++)); do
						echo "${spaces:0:$((maxLen + 3))}${valuesLines[l]}"
					done
				else
					echo "$(lpad_text "${labelsTab[$i]}" "$maxLen") = ${valuesTab[$i]}"
				fi
			done
		else
			echo "Nie odnotowano zdarzeń"
		fi
	fi
}

get_since_last_time() {
	local actionName=$1
	local actionFile="${DATA_ROOT_DIR}/last_${actionName}"
	if [ -f "$actionFile" ]; then
		local actionLast="$(<"$actionFile")"
		local nowDate="$(date +'%s')"
		echo $((nowDate - actionLast))
	else
		echo -1
	fi
}

set_last_time() {
	local actionName=$1
	local actionFile="${DATA_ROOT_DIR}/last_${actionName}"
	local nowDate="$(date +'%s')"
	echo "$nowDate" >"$actionFile"
	event_mark "last_${actionName}_set"
}

clear_last_time() {
	local actionName=$1
	local actionFile="${DATA_ROOT_DIR}/last_${actionName}"
	rm -f "$actionFile"
	event_mark "last_${actionName}_clear"
}

get_events_status() {
	local count="$(event_count)"
	if ((count == 0)); then
		printf "\U2728 brak zdarzeń"
	elif ((count == 1)); then
		printf "\U1F4C5 jedno zdarzenie"
	elif (((count % 10) > 1)) && (((count % 10) < 5)); then
		printf "\U1F4C5 %s zdarzenia" "$count"
	else
		printf "\U1F4C5 %s zdarzeń" "$count"
	fi
}
