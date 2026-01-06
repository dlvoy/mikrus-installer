#dev-begin
# shellcheck disable=SC2148
# shellcheck disable=SC2155
# shellcheck disable=SC2034

if [ "EXECUTED" != "true" ]; then

    msgerr "Headers USED!"
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

else 
    msgdebug "Headers ignored"
fi
#dev-end
