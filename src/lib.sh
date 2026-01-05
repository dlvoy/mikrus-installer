# shellcheck disable=SC2148
# shellcheck disable=SC2155

#=======================================
# CONFIG
#=======================================

REQUIRED_NODE_VERSION=18.0.0
REQUIRED_DOTENV_VERSION=1.3.0
LOGTO=/dev/null
DEBUG_LOG_FILE=/srv/nightscout/data/debug.log
NIGHTSCOUT_ROOT_DIR=/srv/nightscout
CONFIG_ROOT_DIR=/srv/nightscout/config
DATA_ROOT_DIR=/srv/nightscout/data
ENV_FILE_ADMIN=/srv/nightscout/config/admin.env
ENV_FILE_NS=/srv/nightscout/config/nightscout.env
ENV_FILE_DEP=/srv/nightscout/config/deployment.env
LOG_ENCRYPTION_KEY_FILE=/srv/nightscout/config/log.key
DOCKER_COMPOSE_FILE=/srv/nightscout/config/docker-compose.yml
PROFANITY_DB_FILE=/srv/nightscout/data/profanity.db
RESERVED_DB_FILE=/srv/nightscout/data/reserved.db
WATCHDOG_STATUS_FILE=/srv/nightscout/data/watchdog_status
WATCHDOG_TIME_FILE=/srv/nightscout/data/watchdog_time
WATCHDOG_LOG_FILE=/srv/nightscout/data/watchdog.log
WATCHDOG_FAILURES_FILE=/srv/nightscout/data/watchdog-failures.log
WATCHDOG_CRON_LOG=/srv/nightscout/data/watchdog-cron.log
SUPPORT_LOG=/srv/nightscout/data/support.log
EVENTS_DB=/srv/nightscout/data/events.env
UPDATE_CHANNEL_FILE=/srv/nightscout/data/update_channel
MONGO_DB_DIR=/srv/nightscout/data/mongodb
TOOL_FILE=/srv/nightscout/tools/nightscout-tool
TOOL_LINK=/usr/bin/nightscout-tool
UPDATES_DIR=/srv/nightscout/updates
UPDATE_CHANNEL=master
UPDATE_CHECK=86400              # == 1 day
UPDATE_MAIL=2592000             # == 30 days
DISK_LOW_WARNING=838860800      # == 800 MiB
DISK_LOW_MAIL=5184000           # == 60 days in seconds
DISK_CRITICAL_WARNING=104857600 # == 100 MiB
DISK_CRITICAL_MAIL=604800       # == 7 days in seconds
DOCKER_DOWN_MAIL=604800         # == 7 days in seconds
SCRIPT_VERSION="1.10.1"         #auto-update
SCRIPT_BUILD_TIME="2026.01.05"  #auto-update
FORCE_DEBUG_LOG=""

#=======================================
# DOWNLOAD CONFIG
#=======================================

GITHUB_BASE_URL="https://raw.githubusercontent.com/dlvoy/mikrus-installer"
GITEA_BASE_URL="https://gitea.dzienia.pl/shared/mikrus-installer/raw/branch"
GITHUB_UNAVAILABLE="" # Empty string = GitHub is available, set to "1" if GitHub fails

#dev-begin
#=======================================
# IMPORTS - generic
#=======================================

DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$DIR" ]]; then DIR="$PWD"; fi
# shellcheck source=/dev/null
. "$DIR/screen_config.sh"
. "$DIR/screen_formaters.sh"
. "$DIR/utils_console.sh"
. "$DIR/utils.sh"
. "$DIR/utils_string.sh"
. "$DIR/screen_dialogs.sh"
#dev-end

#include screen_config.sh
#include screen_formaters.sh
#include utils_console.sh
#include utils.sh
#include utils_string.sh
#include screen_dialogs.sh

#=======================================
# VARIABLES
#=======================================

packages=()
aptGetWasUpdated=0
freshInstall=0
cachedMenuDomain=''
lastTimeSpaceInfo=0
diagnosticsSizeOk=0
forceUpdateCheck=0

MIKRUS_APIKEY=''
MIKRUS_HOST=''

#dev-begin
#=======================================
# IMPORTS - app specific
#=======================================

# shellcheck source=/dev/null
. "$DIR/logic_events.sh"
. "$DIR/logic_setup.sh"
. "$DIR/logic_setup_checks.sh"
. "$DIR/logic_patch.sh"
. "$DIR/logic_docker.sh"

. "$DIR/utils_app.sh"

. "$DIR/logic_watchdog.sh"
. "$DIR/logic_cleanup.sh"
. "$DIR/logic_config.sh"
. "$DIR/logic_update.sh"
. "$DIR/logic_diagnostics.sh"
. "$DIR/logic_app.sh"

. "$DIR/app_other_dialogs.sh"
. "$DIR/app_setup_prompts.sh"
. "$DIR/app_setup.sh"

. "$DIR/utils_reminders.sh"
. "$DIR/commandline.sh"

. "$DIR/app_watchdog.sh"
. "$DIR/app_cleanup.sh"
. "$DIR/app_config.sh"
. "$DIR/app_update.sh"
. "$DIR/app_diagnostics.sh"
. "$DIR/app_main.sh"

#dev-end

#include logic_events.sh
#include logic_setup.sh
#include logic_setup_checks.sh
#include logic_patch.sh
#include logic_docker.sh

#include utils_app.sh

#include logic_watchdog.sh
#include logic_cleanup.sh
#include logic_config.sh
#include logic_update.sh
#include logic_diagnostics.sh
#include logic_app.sh

#include app_other_dialogs.sh
#include app_setup_prompts.sh
#include app_setup.sh

#include utils_reminders.sh
#include commandline.sh

#include app_watchdog.sh
#include app_cleanup.sh
#include app_config.sh
#include app_update.sh
#include app_diagnostics.sh
#include app_main.sh

