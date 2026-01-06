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
# STRING UTILS
#=======================================

join_by() {
	local d=${1-} f=${2-}
	if shift 2; then
		printf %s "$f" "${@/#/$d}"
	fi
}

lpad_text() {
	local inText="$1"
	local len=${#inText}
	local spaces="                                                                      "
	if ((len == 0)); then
		echo ""
	else
		echo "${spaces:0:$(($2 - len))}$1"
	fi
}

center_text() {
	local inText="$1"
	local len=${#inText}
	local spaces="                                                                                                     "
	if ((len == 0)); then
		echo ""
	else
		echo "${spaces:0:$((($2 - len) / 2))}$1"
	fi
}

rpad_text() {
	local inText="$1"
	local len=${#inText}
	local spaces="                                                                                                     "
	if ((len == 0)); then
		echo ""
	else
		local padSize=$(($2 - len))
		echo "$1${spaces:0:${padSize}}"
	fi
}

multiline_length() {
	local string=$1
	local maxLen=0
	# shellcheck disable=SC2059
	readarray -t array <<<"$(printf "$string")"
	for i in "${!array[@]}"; do
		local line=${array[i]}
		lineLen=${#line}
		if [ "$lineLen" -gt "$maxLen" ]; then
			maxLen="$lineLen"
		fi
	done

	echo "$maxLen"
}

center_multiline() {
	local maxLen=70
	local string="$*"

	if [ $# -gt 1 ]; then
		maxLen=$1
		shift 1
		string="$*"
	else
		maxLen=$(multiline_length "$string")
	fi

	# shellcheck disable=SC2059
	readarray -t array <<<"$(printf "$string")"
	for i in "${!array[@]}"; do
		local line=${array[i]}
		# shellcheck disable=SC2005
		echo "$(center_text "$line" "$maxLen")"
	done
}

pad_multiline() {

	local string="$*"
	local maxLen=$(multiline_length "$string")

	# shellcheck disable=SC2059
	readarray -t array <<<"$(printf "$string")"
	for i in "${!array[@]}"; do
		local line=${array[i]}
		# shellcheck disable=SC2005
		echo "$(rpad_text "$line" "$maxLen")"
	done
}
