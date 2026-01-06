#=======================================
# COMMANDLINE PARSER
#=======================================

help() {
	cat <<EOF
Usage: nightscout-tool [options]

Description:

  Nightscout-tool is a command-line tool for managing Nightscout.

  In UI mode, tool provides a menu-driven interface for managing 
  Nightscout server, its configuration, updates, cleanup, and diagnostics.
	
  In watchdog mode, it can be used to monitor the status of Nightscout
  and send an email alert if the service is down.

Options:
  -w, --watchdog    Run in watchdog mode
  -v, --version     Show version
  -l, --loud        Enable debug logging (UI) or verbose mode (non-int.)
  -d, --develop     Switch to DEVELOP update channel
  -p, --production  Switch to PRODUCTION update channel
  -u, --update      Force update check
  -c, --channel     Switch to specified update channel
  -s, --cleanup     Perform cleanup
  -r, --restart     Restart containers
      --update-ns   Update Nightscout and Mongo containers
  -h, --help        Show this help message
EOF
}

parse_commandline_args() {

	load_update_channel

	CMDARGS=$(getopt --quiet -o wvldpuc:srh --long watchdog,version,loud,develop,production,update,channel:,cleanup,restart,update-ns,help -n 'nightscout-tool' -- "$@")

	# shellcheck disable=SC2181
	if [ $? != 0 ]; then
		echo "Invalid arguments: " "$@" >&2
		exit 1
	fi

	# Note the quotes around '$TEMP': they are essential!
	eval set -- "$CMDARGS"

	WATCHDOGMODE=false
  NONINTERACTIVE_MODE=false
	while true; do
		case "$1" in
		-w | --watchdog)
			WATCHDOGMODE=true
			NONINTERACTIVE_MODE=true
			shift
			;;
		-v | --version)
			echo "$SCRIPT_VERSION"
			exit 0
			;;
		-l | --loud)
			warn "Loud mode, enabling debug logging"
			FORCE_DEBUG_LOG="1"	
			update_logto
			shift
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
		-s | --cleanup)
			NONINTERACTIVE_MODE=true
			do_cleanup_all
			exit 0
			;;
		-r | --restart)
			NONINTERACTIVE_MODE=true
			do_restart
			exit 0
			;;
		--update-ns)
			NONINTERACTIVE_MODE=true
			do_update_ns
			exit 0
			;;
		-h | --help)
			help
			exit 0
			;;
		--)
			shift
			break
			;;
		*) break ;;
		esac
	done

	if [ "$WATCHDOGMODE" = "true" ]; then
    startup_version
    startup_debug
		watchdog_check
	fi

}
