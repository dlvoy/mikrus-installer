#=======================================
# DOCKER
#=======================================

get_docker_status() {
	local ID=$(docker ps -a --no-trunc --filter name="^$1" --format '{{ .ID }}')
	if [[ "$ID" =~ [0-9a-fA-F]{12,} ]]; then
		docker inspect "$ID" | jq -r ".[0].State.Status"
	else
		echo 'missing'
	fi
}

install_containers() {
	if [[ "$FORCE_DEBUG_LOG" == "1"  && "$NONINTERACTIVE_MODE" = "true" ]]; then
		docker compose --env-file $ENV_FILE_DEP -f $DOCKER_COMPOSE_FILE up --no-recreate -d
	else
		docker compose --env-file $ENV_FILE_DEP -f $DOCKER_COMPOSE_FILE up --no-recreate -d >>"$LOGTO" 2>&1
	fi
}

update_containers() {
	if [[ "$FORCE_DEBUG_LOG" == "1"  && "$NONINTERACTIVE_MODE" = "true" ]]; then
		docker compose --env-file $ENV_FILE_DEP -f $DOCKER_COMPOSE_FILE pull
		docker compose --env-file $ENV_FILE_DEP -f $DOCKER_COMPOSE_FILE up -d
	else
		docker compose --env-file $ENV_FILE_DEP -f $DOCKER_COMPOSE_FILE pull >>"$LOGTO" 2>&1
		docker compose --env-file $ENV_FILE_DEP -f $DOCKER_COMPOSE_FILE up -d >>"$LOGTO" 2>&1
fi
}

install_containers_progress() {
	local created=$(docker container ls -f 'status=created' -f name=ns-server -f name=ns-database | wc -l)
	local current=$(docker container ls -f 'status=running' -f name=ns-server -f name=ns-database | wc -l)
	local progr=$(((current - 1) * 2 + (created - 1)))
	echo_progress "$progr" 6 50 "$1" 60
}

uninstall_containers() {
	if [[ "$FORCE_DEBUG_LOG" == "1"  && "$NONINTERACTIVE_MODE" = "true" ]]; then
		docker compose --env-file $ENV_FILE_DEP -f $DOCKER_COMPOSE_FILE down
	else
		docker compose --env-file $ENV_FILE_DEP -f $DOCKER_COMPOSE_FILE down >>"$LOGTO" 2>&1
	fi
}

uninstall_containers_progress() {
	local running=$(docker container ls -f 'status=running' -f name=ns-server -f name=ns-database -f name=ns-backup | wc -l)
	local current=$(docker container ls -f 'status=exited' -f name=ns-server -f name=ns-database -f name=ns-backup | wc -l)
	local progr=$((current - 1))
	if [ "$(((running - 1) + (current - 1)))" -eq "0" ]; then
		echo_progress 3 3 50 "$1" 15
	else
		echo_progress "$progr" 3 50 "$1" 15
	fi
}

get_container_status() {
	local ID=$(docker ps -a --no-trunc --filter name="^$1$" --format '{{ .ID }}')
	if [[ "$ID" =~ [0-9a-fA-F]{12,} ]]; then
		local status=$(docker inspect "$ID" | jq -r ".[0].State.Status")
		case "$status" in
		"running")
			printf "\U1F7E2 działa"
			;;
		"restarting")
			printf "\U1F7E3 restart"
			;;
		"created")
			printf "\U26AA utworzono"
			;;
		"exited")
			printf "\U1F534 wyłączono"
			;;
		"paused")
			printf "\U1F7E1 zapauzowano"
			;;
		"dead")
			printf "\U1F480 zablokowany"
			;;
		esac

	else
		printf '\U2753 nie odnaleziono'
	fi
}

get_container_status_code() {
	local ID=$(docker ps -a --no-trunc --filter name="^$1$" --format '{{ .ID }}')
	if [[ "$ID" =~ [0-9a-fA-F]{12,} ]]; then
		local status=$(docker inspect "$ID" | jq -r ".[0].State.Status")
		echo "$status"
	else
		echo "unknown"
	fi
}
