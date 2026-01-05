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