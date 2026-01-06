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
# CONFIGURATION
#=======================================

source_admin() {
	if [[ -f $ENV_FILE_ADMIN ]]; then
		# shellcheck disable=SC1090
		source "$ENV_FILE_ADMIN"
		msgok "Imported admin config"
	fi
}

do_uninstall() {
	msgok "Uninstalling..."
	uninstall_containers
	ohai "Usuwanie plików, proszę czekać..." 
	uninstall_cron
	rm -r "${MONGO_DB_DIR:?}/data"
	rm -r "${CONFIG_ROOT_DIR:?}"
	rm "$TOOL_LINK"
	rm -r "${NIGHTSCOUT_ROOT_DIR:?}/tools"
	rm -r "${NIGHTSCOUT_ROOT_DIR:?}/updates"
	do_cleanup_diagnostics
	do_cleanup_app_logs
	do_cleanup_app_state
	event_mark "uninstall"
}
