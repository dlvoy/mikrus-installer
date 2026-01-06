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
# DIAGNOSTICS UI
#=======================================

send_diagnostics() {

	setup_security

	LOG_KEY=$(<"$LOG_ENCRYPTION_KEY_FILE")

	yesnodlg "Wysyłać diagnostykę?" \
		"$uni_send" "$uni_resign" \
		"Czy chcesz zgromadzić i wysłać sobie mailem dane diagnostyczne?" \
		"\n$(
			pad_multiline \
				"\n${uni_bullet}diagnostyka zawiera logi i informacje o serwerze i usługach" \
				"\n${uni_bullet}wysyłka na e-mail na który zamówiono serwer Mikr.us" \
				"\n${uni_bullet}dane będą skompresowane i zaszyfrowane" \
				"\n${uni_bullet}maila prześlij dalej do zaufanej osoby wspierającej" \
				"\n${uni_bullet_pad}(z którą to wcześniej zaplanowano i uzgodniono!!!)" \
				"\n${uni_bullet}hasło przekaż INNĄ DROGĄ (komunikatorem, SMSem, osobiście)" \
				"\n\n${uni_bullet_pad}Hasło do logów: $LOG_KEY"
		)"

	if ! [ $? -eq 1 ]; then

		local curr_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

		gather_diagnostics 500 100 "$curr_time"
		retry_diagnostics 200 50 "$curr_time"
		retry_diagnostics 100 50 "$curr_time"
		retry_diagnostics 50 50 "$curr_time"
		retry_diagnostics 50 20 "$curr_time"

		ohai "Wysyłanie maila"

		local sentStatus=$({
			echo "Ta wiadomość zawiera poufne dane diagnostyczne Twojego serwera Nightscout."
			echo "Mogą one pomóc Tobie lub zaufanej osobie w identyfikacji problemu."
			echo " "
			echo "Prześlij ten mail dalej do zaufanej osoby, umówionej na udzielenie wsparcia."
			echo "Przekaż tej osobie w bezpieczny sposób hasło szyfrowania"
			echo "  (w narzędziu nightscout-tool można je znaleźć w pozycji 'O tym narzędziu...')."
			echo "Do przekazania hasła użyj INNEJ metody (komunikator, SMS, osobiście...)."
			echo "Nie przesyłaj tej wiadomości do administratorów grupy lub serwera bez wcześniejszego uzgodnienia!"
			echo " "
			echo "Instrukcje i narzędzie do odszyfrowania logów dostępne pod adresem: https://t1d.dzienia.pl/decoder/"
			echo " "
			echo " "
			cat "$SUPPORT_LOG.gz.asc"
		} | pusher "Diagnostyka_serwera_Nightscout_-_$curr_time")

		local regexEm='Email sent'
		if [[ "$sentStatus" =~ $regexEm ]]; then
			do_cleanup_diagnostics
			msgcheck "Mail wysłany!"
			okdlg "Diagnostyka wysłana" \
				"Sprawdź swoją skrzynkę pocztową,\n" \
				"otrzymanego maila przekaż zaufanemu wspierającemu.\n\n" \
				"Komunikatorem lub SMS przekaż hasło do logów:\n\n$LOG_KEY"
		else
			msgerr "Błąd podczas wysyłki maila: $sentStatus"
			okdlg "Błąd wysyłki maila" \
				"Nieststy nie udało się wysłać diagnostyki" \
				"${NL}zgłoś poniższy błąd twórcom narzędzia (na grupie Technologie Diabetyka)" \
				"${TL}$sentStatus"
		fi

	fi
}
