# shellcheck disable=SC2148
# shellcheck disable=SC2155
# shellcheck disable=SC2034

#=======================================
# HEADERS
#=======================================

#---------------------------------------
# GLOBAL VARS
#---------------------------------------

packages=()
aptGetWasUpdated=0
freshInstall=0
cachedMenuDomain=''
lastTimeSpaceInfo=0
diagnosticsSizeOk=0
forceUpdateCheck=0

MIKRUS_APIKEY=''
MIKRUS_HOST=''
