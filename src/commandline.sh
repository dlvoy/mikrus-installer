#=======================================
# COMMANDLINE PARSER
#=======================================

parse_commandline_args() {

	load_update_channel

	CMDARGS=$(getopt --quiet -o wvdpuc: --long watchdog,version,develop,production,update,channel: -n 'nightscout-tool' -- "$@")

	# shellcheck disable=SC2181
	if [ $? != 0 ]; then
		echo "Invalid arguments: " "$@" >&2
		exit 1
	fi

	# Note the quotes around '$TEMP': they are essential!
	eval set -- "$CMDARGS"

	WATCHDOGMODE=false
	while true; do
		case "$1" in
		-w | --watchdog)
			WATCHDOGMODE=true
			shift
			;;
		-v | --version)
			echo "$SCRIPT_VERSION"
			exit 0
			;;
		-d | --develop)
			warn "Switching to DEVELOP update channel"
			UPDATE_CHANNEL=develop
			forceUpdateCheck=1
			echo "$UPDATE_CHANNEL" >"$UPDATE_CHANNEL_FILE"
			update_logto
			shift
			;;
		-p | --production)
			warn "Switching to PRODUCTION update channel"
			UPDATE_CHANNEL=master
			forceUpdateCheck=1
			echo "$UPDATE_CHANNEL" >"$UPDATE_CHANNEL_FILE"
			update_logto
			shift
			;;
		-u | --update)
			warn "Forcing update check"
			forceUpdateCheck=1
			shift
			;;
		-c | --channel)
			shift # The arg is next in position args
			UPDATE_CHANNEL_CANDIDATE=$1
			forceUpdateCheck=1

			[[ ! "$UPDATE_CHANNEL_CANDIDATE" =~ ^[a-z]{3,}$ ]] && {
				echo "Incorrect channel name provided: $UPDATE_CHANNEL_CANDIDATE"
				exit 1
			}

			warn "Switching to $UPDATE_CHANNEL_CANDIDATE update channel"
			UPDATE_CHANNEL="$UPDATE_CHANNEL_CANDIDATE"
			echo "$UPDATE_CHANNEL" >"$UPDATE_CHANNEL_FILE"
			update_logto
			shift
			;;
		--)
			shift
			break
			;;
		*) break ;;
		esac
	done

	if [ "$WATCHDOGMODE" = "true" ]; then
		watchdog_check
	fi

}
