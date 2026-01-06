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
# COMMANDLINE PARSER
#=======================================

help() {
	cat <<EOF
Usage: nightscout-tool [options]

Description:

  Nightscout-tool is a command-line tool for managing Nightscout instance
  and its containers on mikr.us hosting.

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
  -u, --update      Perform unattended update of tool
  -c, --channel     Switch to specified update channel
  -s, --cleanup     Perform cleanup
  -r, --restart     Restart containers
      --update-ns   Update Nightscout and Mongo containers
	  --force-check Force update check in UI mode
  -h, --help        Show this help message
EOF
}

parse_commandline_args() {

	load_update_channel

	CMDARGS=$(getopt --quiet \
		-o wvldpuc:srh \
		--long watchdog,version,loud,develop,production,update,force-check,channel:,cleanup,restart,update-ns,help \
		-n 'nightscout-tool' -- "$@")

	# shellcheck disable=SC2181
	if [ $? != 0 ]; then
		echo "Invalid arguments: " "$@" >&2
		exit 1
	fi

	# Note the quotes around '$TEMP': they are essential!
	eval set -- "$CMDARGS"

	WATCHDOGMODE=false
	NONINTERACTIVE_MODE=false
	local action=""
	local new_channel=""

	# First pass: gather configuration and determine action
	while true; do
		case "$1" in
		-w | --watchdog)
			WATCHDOGMODE=true
			NONINTERACTIVE_MODE=true
			shift
			;;
		-v | --version)
			action="version"
			shift
			;;
		-l | --loud)
			FORCE_DEBUG_LOG="1"
			shift
			;;
		-d | --develop)
			new_channel="develop"
			forceUpdateCheck=1
			shift
			;;
		-p | --production)
			new_channel="master"
			forceUpdateCheck=1
			shift
			;;
		-f | --force-check)
			forceUpdateCheck=1
			shift
			;;
		-u | --update)
			NONINTERACTIVE_MODE=true
			action="update"
			shift
			;;
		-c | --channel)
			shift # The arg is next in position args
			new_channel=$1
			forceUpdateCheck=1

			[[ ! "$new_channel" =~ ^[a-z]{3,}$ ]] && {
				echo "Incorrect channel name provided: $new_channel"
				exit 1
			}
			shift
			;;
		-s | --cleanup)
			NONINTERACTIVE_MODE=true
			action="cleanup"
			shift
			;;
		-r | --restart)
			NONINTERACTIVE_MODE=true
			action="restart"
			shift
			;;
		--update-ns)
			#shellcheck disable=SC2034
			NONINTERACTIVE_MODE=true
			action="update-ns"
			shift
			;;
		-h | --help)
			action="help"
			shift
			;;
		--)
			shift
			break
			;;
		*) break ;;
		esac
	done

	# Apply configuration
	if [ -n "$FORCE_DEBUG_LOG" ]; then
		warn "Loud mode, enabling debug logging"
		update_logto
	fi

	if [ -n "$new_channel" ]; then
		warn "Switching to $new_channel update channel"
		UPDATE_CHANNEL="$new_channel"
		echo "$UPDATE_CHANNEL" >"$UPDATE_CHANNEL_FILE"
		update_logto
	fi

	if [ "$forceUpdateCheck" = "1" ]; then
		warn "Forcing update check"
	fi

	# Second pass: execute action or continue
	case "$action" in
	version)
		echo "$SCRIPT_VERSION"
		exit 0
		;;
	help)
		help
		exit 0
		;;
	cleanup)
		do_cleanup_all
		exit 0
		;;
	restart)
		do_restart
		exit 0
		;;
	update)
		do_update_tool
		exit 0
		;;
	update-ns)
		do_update_ns
		exit 0
		;;
	esac

	if [ "$WATCHDOGMODE" = "true" ]; then
		startup_version
		startup_debug
		watchdog_check
	fi
}
