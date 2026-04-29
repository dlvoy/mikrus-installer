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

# Run a single docker compose subcommand, writing output to DOCKER_OP_LOG always,
# and also to stdout (debug mode) or LOGTO (normal mode).
# Returns the exit code of docker compose.
_run_docker_compose() {
	local ts
	ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	echo "[$ts] docker compose $*" >>"$DOCKER_OP_LOG"
	if [[ "$FORCE_DEBUG_LOG" == "1" && "$NONINTERACTIVE_MODE" = "true" ]]; then
		docker compose --env-file "$ENV_FILE_DEP" -f "$DOCKER_COMPOSE_FILE" "$@" 2>&1 | tee -a "$DOCKER_OP_LOG"
		local ret="${PIPESTATUS[0]}"
	else
		docker compose --env-file "$ENV_FILE_DEP" -f "$DOCKER_COMPOSE_FILE" "$@" 2>&1 | tee -a "$DOCKER_OP_LOG" >>"$LOGTO"
		local ret="${PIPESTATUS[0]}"
	fi
	local ts2
	ts2=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	echo "[$ts2] exit code: $ret" >>"$DOCKER_OP_LOG"
	return $ret
}

# Returns 0 if the docker operation succeeded (good exit code + no failure strings in log).
# Pass the exit code and the line-offset in DOCKER_OP_LOG where this operation began.
_docker_op_succeeded() {
	local ret=$1
	local log_start=$2
	if [[ $ret -ne 0 ]]; then
		return 1
	fi
	local op_output
	op_output=$(tail -n +"$((log_start + 1))" "$DOCKER_OP_LOG" 2>/dev/null)
	if echo "$op_output" | grep -qE "Failed to Setup|exit status 1"; then
		return 1
	fi
	return 0
}

# Rotate DOCKER_OP_LOG when it gets too large (keep last 2000 lines).
_rotate_docker_op_log() {
	if [[ -f "$DOCKER_OP_LOG" ]]; then
		local lc
		lc=$(wc -l <"$DOCKER_OP_LOG")
		if ((lc > 5000)); then
			tail -2000 "$DOCKER_OP_LOG" >"${DOCKER_OP_LOG}.tmp"
			mv -f "${DOCKER_OP_LOG}.tmp" "$DOCKER_OP_LOG"
		fi
	fi
}

install_containers() {
	_rotate_docker_op_log
	local ts
	ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	local log_start
	log_start=$(wc -l <"$DOCKER_OP_LOG" 2>/dev/null || echo 0)
	echo "[$ts] === install_containers ===" >>"$DOCKER_OP_LOG"

	_run_docker_compose up --no-recreate -d
	local ret=$?

	if ! _docker_op_succeeded "$ret" "$log_start"; then
		echo "[$ts] install_containers FAILED (attempt 1) — restarting docker service..." >>"$DOCKER_OP_LOG"
		sudo systemctl restart docker >>"$DOCKER_OP_LOG" 2>&1
		sleep 5
		local log_start2
		log_start2=$(wc -l <"$DOCKER_OP_LOG")
		_run_docker_compose up --no-recreate -d
		ret=$?
		if ! _docker_op_succeeded "$ret" "$log_start2"; then
			local ts2
			ts2=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
			echo "[$ts2] install_containers FAILED (attempt 2 after docker restart)" >>"$DOCKER_OP_LOG"
			echo "failed" >"$DOCKER_OP_STATUS_FILE"
			return 1
		fi
	fi

	local ts_ok
	ts_ok=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	echo "[$ts_ok] install_containers OK" >>"$DOCKER_OP_LOG"
	echo "ok" >"$DOCKER_OP_STATUS_FILE"
}

update_containers() {
	_rotate_docker_op_log
	local ts
	ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	local log_start
	log_start=$(wc -l <"$DOCKER_OP_LOG" 2>/dev/null || echo 0)
	echo "[$ts] === update_containers ===" >>"$DOCKER_OP_LOG"

	_run_docker_compose pull
	local ret_pull=$?
	_run_docker_compose up -d
	local ret_up=$?
	local ret=$ret_up
	if [[ $ret_pull -ne 0 && $ret_up -eq 0 ]]; then
		ret=$ret_pull
	fi

	if ! _docker_op_succeeded "$ret" "$log_start"; then
		echo "[$ts] update_containers FAILED (attempt 1) — restarting docker service..." >>"$DOCKER_OP_LOG"
		sudo systemctl restart docker >>"$DOCKER_OP_LOG" 2>&1
		sleep 5
		local log_start2
		log_start2=$(wc -l <"$DOCKER_OP_LOG")
		_run_docker_compose pull
		ret_pull=$?
		_run_docker_compose up -d
		ret_up=$?
		ret=$ret_up
		if [[ $ret_pull -ne 0 && $ret_up -eq 0 ]]; then
			ret=$ret_pull
		fi
		if ! _docker_op_succeeded "$ret" "$log_start2"; then
			local ts2
			ts2=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
			echo "[$ts2] update_containers FAILED (attempt 2 after docker restart)" >>"$DOCKER_OP_LOG"
			echo "failed" >"$DOCKER_OP_STATUS_FILE"
			return 1
		fi
	fi

	local ts_ok
	ts_ok=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
	echo "[$ts_ok] update_containers OK" >>"$DOCKER_OP_LOG"
	echo "ok" >"$DOCKER_OP_STATUS_FILE"
}

install_containers_progress() {
	local created=$(docker container ls -f 'status=created' -f name=ns-server -f name=ns-database | wc -l)
	local current=$(docker container ls -f 'status=running' -f name=ns-server -f name=ns-database | wc -l)
	local progr=$(((current - 1) * 2 + (created - 1)))
	echo_progress "$progr" 6 50 "$1" 60
}

uninstall_containers() {
	if [[ "$FORCE_DEBUG_LOG" == "1" && "$NONINTERACTIVE_MODE" = "true" ]]; then
		docker compose --env-file "$ENV_FILE_DEP" -f "$DOCKER_COMPOSE_FILE" down
	else
		docker compose --env-file "$ENV_FILE_DEP" -f "$DOCKER_COMPOSE_FILE" down >>"$LOGTO" 2>&1
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
