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
# SETUP
#=======================================

setup_update_repo() {
	if [ "$aptGetWasUpdated" -eq "0" ]; then
		aptGetWasUpdated=1
		ohai "Updating package repository"
		apt-get -yq update >>"$LOGTO" 2>&1
	fi
}

setup_provisional_key() {
	ohai "Generating provisional log encryption key"
	local randPass=$(openssl rand -base64 30)
	local fixedPass=$(echo "$randPass" | sed -e 's/[+\/]/-/g')
	echo "tymczasowe-${fixedPass}" >"$LOG_ENCRYPTION_KEY_FILE"
	msgcheck "Provisional key generated"
}

setup_security() {
	if [[ -f $LOG_ENCRYPTION_KEY_FILE ]]; then
		# --------------------
		# JAKIŚ klucz istnieje
		# --------------------
		local logKey=$(<"$LOG_ENCRYPTION_KEY_FILE")
		local regexTemp='tymczasowe-'

		# -----------------------
		# ...ale jest tymczasowy
		# -----------------------
		if [[ "$logKey" =~ $regexTemp ]]; then
			msgerr "Using provisional key"
			test_diceware
			local RESULT=$?
			if [ "$RESULT" -eq 0 ]; then
				ohai "Generating proper log encryption file..."
				diceware -n 5 -d - >"$LOG_ENCRYPTION_KEY_FILE"
				msgcheck "Key generated"
			else
				msgerr "Required tool (diceware) still cannot be installed - apt is locked!"
				msgnote "Zrestartuj serwer mikr.us i sprawdź czy ten błąd nadal występuje - wtedy odbokuj apt-get i zainstaluj diceware (apt-get install diceware)"
			fi
		else
			local keySize=${#logKey}

			# ----------------------
			# ...ale jest za krótki
			# ----------------------
			if ((keySize < 12)); then
				msgerr "Encryption key empty or too short, generating better one"
				test_diceware
				local RESULT=$?
				if [ "$RESULT" -eq 0 ]; then
					ohai "Generating proper log encryption file..."
					diceware -n 5 -d - >"$LOG_ENCRYPTION_KEY_FILE"
					msgcheck "Key generated"
				else
					msgerr "Generating provisional key while diceware tool is not installed"
					setup_provisional_key
				fi
			else
				msgok "Found log encryption key"
			fi
		fi
	else

		# ---------------------
		# jescze nie ma klucza
		# ---------------------

		test_diceware
		local RESULT=$?
		if [ "$RESULT" -eq 0 ]; then
			ohai "Generating log encryption key..."
			diceware -n 5 -d - >"$LOG_ENCRYPTION_KEY_FILE"
			msgcheck "Key generated"
		else
			msgerr "Generating provisional key while diceware tool is not installed"
			setup_provisional_key
		fi

	fi
}

setup_packages() {
	# shellcheck disable=SC2145
	# shellcheck disable=SC2068
	(if_is_set packages && setup_update_repo &&
		ohai "Installing packages: ${packages[@]}" &&
		apt-get -yq install ${packages[@]} >>"$LOGTO" 2>&1 &&
		msgcheck "Install successfull") || msgok "All required packages already installed"
}

setup_node() {
	test_node
	local RESULT=$?
	if [ "$RESULT" -eq 0 ]; then
		msgcheck "Node installed in correct version"
	else
		ohai "Cleaning old Node.js"
		{
			rm -f /etc/apt/sources.list.d/nodesource.list
			apt-get -yq --fix-broken install
			apt-get -yq update
			apt-get -yq remove nodejs nodejs-doc libnode*
		} >>"$LOGTO" 2>&1

		ohai "Preparing Node.js setup"
		curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null 2>&1

		ohai "Installing Node.js"
		apt-get install -y nodejs >>"$LOGTO" 2>&1

		test_node
		local RECHECK=$?
		if [ "$RECHECK" -ne 0 ]; then

			msgerr "Nie udało się zainstalować Node.js"

			msgerr "Instalacja Node.js jest skomplikowanym procesem i zależy od wersji systemu Linux i konfiguracji Mikr.us-a"
			msgerr "Spróbuj ręcznie uruchomić instalację poniższą komendą i sprawdź czy pojawiają się błędy (i jakie):"
			msgerr "    apt-get install -y nodejs   "

			exit 1
		fi

	fi
}

setup_users() {
	id -u mongodb &>/dev/null
	local RESULT=$?
	if [ "$RESULT" -eq 0 ]; then
		msgcheck "Mongo DB user detected"
	else
		ohai "Configuring Mongo DB user"
		useradd -u 1001 -g 0 mongodb
	fi
}

setup_dir_structure() {
	ohai "Configuring folder structure"
	mkdir -p "$MONGO_DB_DIR"
	mkdir -p /srv/nightscout/config
	mkdir -p /srv/nightscout/tools
	mkdir -p /srv/nightscout/data
	mkdir -p "$UPDATES_DIR"
	chown -R mongodb:root "$MONGO_DB_DIR"
}

setup_firewall() {
	ohai "Configuring firewall"

	{
		ufw default deny incoming
		ufw default allow outgoing

		ufw allow OpenSSH
		ufw allow ssh
	} >>"$LOGTO" 2>&1

	host=$(hostname)

	# Extract the last 3 digits from the hostname
	port_number=$(echo "$host" | grep -oE '[0-9]{3}$')

  ohai "Firewall port: $port_number"

	port1=$((10000 + port_number))
	port2=$((20000 + port_number))
	port3=$((30000 + port_number))

	if ufw allow "$port1" >>"$LOGTO" 2>&1; then
		msgcheck "Do regul firewalla poprawnie dodano port $port1"
	else
		msgerr "Blad dodawania $port1 do regul firewalla"
	fi

	if ufw allow "$port2" >>"$LOGTO" 2>&1; then
		msgcheck "Do regul firewalla poprawnie dodano port $port2"
	else
		msgerr "Blad dodawania $port2 do regul firewalla"
	fi

	if ufw allow "$port3" >>"$LOGTO" 2>&1; then
		msgcheck "Do regul firewalla poprawnie dodano port $port3"
	else
		msgerr "Blad dodawania $port3 do regul firewalla"
	fi

	ufw --force enable >>"$LOGTO" 2>&1
}

setup_firewall_for_ns() {
	ns_external_port=$(dotenv-tool -r get -f "$ENV_FILE_DEP" "NS_PORT")
	if ufw allow "$ns_external_port" >>"$LOGTO" 2>&1; then
		msgcheck "Do regul firewalla poprawnie dodano port Nightscout: $ns_external_port"
	else
		msgerr "Blad dodawania portu Nightscout: $ns_external_port do reguł firewalla"
	fi
}

install_cron() {
	local croncmd="$TOOL_LINK -w > $WATCHDOG_CRON_LOG 2>&1"
	local cronjob="*/5 * * * * $croncmd"
	msgok "Configuring watchdog..."
	(
		crontab -l | grep -v -F "$croncmd" || :
		echo "$cronjob"
	) | crontab -
}

uninstall_cron() {
	local croncmd="nightscout-tool"
	(crontab -l | grep -v -F "$croncmd") | crontab -
}
