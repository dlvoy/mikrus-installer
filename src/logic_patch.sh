#=======================================
# PATCH OLDER CONFIGS
#=======================================

patch_docker_compose() {
	if [[ -f $DOCKER_COMPOSE_FILE ]]; then
		local patched=0
		local containers_running=0

		# Check if containers are already running before patching
		local ns_status=$(get_docker_status "ns-server")
		local db_status=$(get_docker_status "ns-database")
		if [[ "$ns_status" == "running" ]] || [[ "$db_status" == "running" ]]; then
			containers_running=1
		fi

		# Check if mongodb image needs patching (bitnami/mongodb)
		if grep -q "bitnami/mongodb" "$DOCKER_COMPOSE_FILE"; then
			ohai "Patching docker-compose.yml MongoDB image..."
			# Replace bitnami/mongodb with official mongo image
			sed -i -E 's|image:\s*"*(bitnami/)?mongodb:.*"|image: "mongo:${NS_MONGODB_TAG}"|g' "$DOCKER_COMPOSE_FILE"
			patched=1
		fi
		# Check if volume path needs patching (bitnami/mongodb -> data/db)
		if grep -q "/bitnami/mongodb" "$DOCKER_COMPOSE_FILE"; then
			ohai "Patching docker-compose.yml MongoDB volume path..."
			# Replace both host path and container path for mongodb volume
			sed -i -E 's|(\$\{NS_DATA_DIR\}/mongodb):/bitnami/mongodb"|\1/data/db:/data/db"|g' "$DOCKER_COMPOSE_FILE"
			patched=1
		fi

		if [ "$patched" -eq 1 ]; then
			msgcheck "Docker compose file patched"
			# Restart containers only if they were already running
			if [ "$containers_running" -eq 1 ]; then
        do_cleanup_sys
				ohai "Restarting containers to apply patched configuration..."
				update_containers
        do_cleanup_docker
				msgcheck "Containers restarted"
			fi
		fi
	fi
}