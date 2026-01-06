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
# CONFIGURATION
#=======================================

source_admin() {
	if [[ -f $ENV_FILE_ADMIN ]]; then
		# shellcheck disable=SC1090
		source "$ENV_FILE_ADMIN"
		msgok "Imported admin config"
	fi
}