# These functions help microkiosk build
# To use them, just run the command:
# $ source ./tools.sh

dependency1=/lib/lsb/init-functions

if [ -e $dependency1 ]
then
	source $dependency1 > /dev/null 2>&1
fi

function urlEncode {

	python -c "import urllib, sys; print urllib.quote(sys.argv[1])" $1

}

function checkRoot {

	local title="Insufficient privileges error"
	local message="This script needs root level access"

	if [[ $EUID -ne 0 ]]
	then
		log_failure_msg $title
		log_failure_msg $message
		return 126
	else
		return 0
	fi

}

function setProxy {

	checkRoot
	if [ $? -ne 0 ]; then return 126; fi

	local title="Setting proxy configuration..."
	local message1="File /etc/apt/apt.conf will be replaced"
	local message2="Variables http_proxy and https_proxy will be set"
	local message3="To clean proxy configuration, use proxyUnset command"
	local success="Configuration complete"

	log_warning_msg $title
	log_warning_msg $message1
	log_warning_msg $message2

	read -p "Username: " proxy_uid
	read -sp "Password: " proxy_pwd; echo
  	read -p "Proxy IP: " proxy_ip
  	read -p "Proxy port: " proxy_port

	proxy_pwd=$(urlEncode $proxy_pwd)
	bash -c "echo -e 'Acquire::http::Proxy \"http://$proxy_uid:$proxy_pwd@$proxy_ip:$proxy_port/\";' > /etc/apt/apt.conf"
	export http_proxy=http://$proxy_uid:$proxy_pwd@$proxy_ip:$proxy_port/
	export https_proxy=http://$proxy_uid:$proxy_pwd@$proxy_ip:$proxy_port/

	log_success_msg $success
	log_warning_msg $message3

}

function unsetProxy {

	checkRoot
	if [ $? -ne 0 ]; then return 126; fi

	local title="Cleanning proxy configuration..."
	local message1="File /etc/apt/apt.conf will be replaced"
	local message2="Variables http_proxy and https_proxy will be unset"
	local message3="To set proxy configuration, use proxySet command"
	local success="Configuration complete"

	log_warning_msg $title
	log_warning_msg $message1
	log_warning_msg $message2

	echo "Press any key to continue..."
	read -n 1 x
	bash -c "echo -e '' > /etc/apt/apt.conf"
	unset http_proxy
	unset https_proxy

	log_success_msg $success
	log_warning_msg $message3

}

function setDebianPreseedFile {

	local title="Setting Debian preseed file..."
	local success="Configuration complete"
	local message="To unset, use unsetDebianPreseedFile command"

	log_warning_msg $title

	read -p "File path/url: " di_preseed

	log_success_msg $success
	log_warning_msg $message

}

function unsetDebianInstallerPreseedFile {

	local title="Unset Debian preseed file..."
	local success="Configuration complete"
	local message="To set, use setDebianPreseedFile command"

	log_warning_msg $title

	echo "Press any key to continue..."
	read -n 1 x
	unset $di_preseed

	log_success_msg $success
	log_warning_msg $message

}

function setGrubPassword {

	local title="Set grub password..."
	local message1="File /etc/grub.d/40_custom will change"
	local message2="File /etc/grub.d/10_linux will change"
	local message3="To unset, use unsetGrubPassword command"
	local success="Configuration complete"

	log_warning_msg $title
	log_warning_msg $message1
	log_warning_msg $message2

	read -p "Username: " grub_uid
	read -sp "Password: " passw1; echo
	read -sp "Repeat password: " passw2; echo
	echo "Do you want unrestricted entries? (Y/N) "
	read -n 1 x

	# See https://github.com/ryran/burg2-mkpasswd-pbkdf2
	grub_pwd=`echo -e "$passw1\n$passw2" | grub-mkpasswd-pbkdf2 | awk '/grub.pbkdf/{print$NF}'`

	# Check if grep command don't find 'set superusers'
	if [ ! grep -q "set superusers" < /etc/grub.d/40_custom ]
	then
		bash -c "echo -e 'set superusers=\"$grub_uid\"\npassword_pbkdf2 $grub_uid $grub_pwd\n' >> /etc/grub.d/40_custom"
	else
		sed -i 's:set superusers.*:set superusers=\"$grub_uid\":' /etc/grub.d/40_custom
		set -i 's:password_pbkdf2.*:password_pbkdf2 $grub_uid $grub_pwd:' /etc/grub.d/40_custom
	fi

	if [ $x = "Y" ] || [ $x = "y" ]
	then
		# Check if grep command don't find the parameter
		if [ ! grep -q 'CLASS="--class gnu-linux --class gnu --class os --unrestricted"' < /etc/grub.d/10_linux ]
		then
			# Unrestrict grub menu entry (user select menu entry without password, but edit is forbidden)
			sed -i 's:CLASS="--class gnu-linux --class gnu --class os:& --unrestricted:' /etc/grub.d/10_linux
		fi
	else
		# Check if grep command find the parameter
		if [ grep -q 'CLASS="--class gnu-linux --class gnu --class os --unrestricted"' < /etc/grub.d/10_linux ]
		then
			# Restrict grub menu entry (user select menu entry without password, but edit is forbidden)
			sed -i 's:CLASS="--class gnu-linux --class gnu --class os --unrestricted":CLASS="--class gnu-linux --class gnu --class os":' /etc/grub.d/10_linux
		fi
	fi

	log_success_msg $success
	log_warning_msg $message3

}

function unsetGrubPassword {

	local title="Unset grub password..."
	local message1="File /etc/grub.d/40_custom will change"
	local message2="File /etc/grub.d/10_linux will change"
	local message3="To set, use setGrubPassword command"
	local success="Configuration complete"

	echo "Press any key to continue..."
	read -n 1 x

	sed -i 's:set superusers.*::' /etc/grub.d/40_custom
	set -i 's:password_pbkdf2.*::' /etc/grub.d/40_custom

	log_success_msg $success
	log_warning_msg $message3

}
