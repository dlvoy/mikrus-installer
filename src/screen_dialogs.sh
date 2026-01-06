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
# SCREEN DIALOGS
#=======================================

echo_progress() {
	local realProg=$1       # numerical real progress
	local realMax=$2        # max value of that progress
	local realStart=$3      # where real progress starts, %
	local countr=$4         # real ticker, 3 ticks/s
	local firstPhaseSecs=$5 # how long first, ticked part, last

	if [ "$realProg" -eq "0" ]; then
		local progrsec=$(((countr * realStart) / (3 * firstPhaseSecs)))
		if [ "$progrsec" -lt "$realStart" ]; then
			echo "$progrsec"
		else
			echo "$realStart"
		fi
	else
		echo $(((realProg * (100 - realStart) / realMax) + realStart))
	fi
}

process_gauge() {
	local process_to_measure=$1
	local lenmsg
	lenmsg=$(echo "$4" | wc -l)
	eval "$process_to_measure" &
	local thepid=$!
	local num=1
	while true; do
		echo 0
		while kill -0 "$thepid" >/dev/null 2>&1; do
			eval "$2" "$num"
			num=$((num + 1))
			sleep 0.3
		done
		echo 100
		break
	done | whiptail --title "$3" --gauge "\n  $4\n" $((lenmsg + 6)) 70 0
}

okdlg() {
	local title=$1
	shift 1
	local msg="$*"
	local lcount=$(echo -e "$msg" | grep -c '^')
	local width=$(multiline_length "$msg")
	whiptail --title "$title" --msgbox "$(center_multiline $((width + 4)) "$msg")" $((lcount + 6)) $((width + 9))
}

confirmdlg() {
	local title=$1
	local btnlabel=$2
	shift 2
	local msg="$*"
	local lcount=$(echo -e "$msg" | grep -c '^')
	local width=$(multiline_length "$msg")
	whiptail --title "$title" --ok-button "$btnlabel" --msgbox "$(center_multiline $((width + 4)) "$msg")" $((lcount + 6)) $((width + 9))
}

yesnodlg() {
	yesnodlg_base "y" "$@"
}

noyesdlg() {
	yesnodlg_base "n" "$@"
}

yesnodlg_base() {
	local defaultbtn=$1
	local title=$2
	local ybtn=$3
	local nbtn=$4
	shift 4
	local msg="$*"
	# shellcheck disable=SC2059
	local linec=$(printf "$msg" | grep -c '^')
	local width=$(multiline_length "$msg")
	local ylen=${#ybtn}
	local nlen=${#nbtn}
	# we need space for all < > around buttons
	local minbtn=$((ylen + nlen + 6))
	# minimal nice width of dialog
	local minlen=$((minbtn > 15 ? minbtn : 15))
	local mwidth=$((minlen > width ? minlen : width))

	# whiptail has bug, buttons are NOT centered
	local rpad=$((width < minbtn ? (nlen - 2) + ((nlen - 2) / 2) : 4))
	local padw=$((mwidth + rpad))

	if [[ "$defaultbtn" == "y" ]]; then
		whiptail --title "$title" --yesno "$(center_multiline "$padw" "$msg")" \
			--yes-button "$ybtn" --no-button "$nbtn" \
			$((linec + 7)) $((padw + 4))
	else
		whiptail --title "$title" --yesno --defaultno "$(center_multiline "$padw" "$msg")" \
			--yes-button "$ybtn" --no-button "$nbtn" \
			$((linec + 7)) $((padw + 4))
	fi
}
