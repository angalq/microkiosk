# These functions help microkiosk build
# To use them, just run the command:
# $ source ./build-tools.sh

dependency1=/lib/lsb/init-functions

if [ -e $dependency1 ]
then
	source $dependency1 > /dev/null 2>&1
fi

function exitIfCanceled {

	# Parameter extension syntax
	# See https://www.gnu.org/software/bash/manual/html_node/Brace-Expansion.html
	if [ ! -z ${1+x} ] && [ $1 -ne 0 ]
	then
		return $1
	else
		return 0
	fi

}

function urlEncode {

	python -c "import urllib, sys; print urllib.quote(sys.argv[1])" $1

}

function checkRoot {

	local title="Insufficient privileges error"
	local alert="This script needs root level access"

	if [[ $EUID -ne 0 ]]
	then
		log_failure_msg $title
		log_failure_msg $alert
		return 126
	fi

}

function proxySet {

	checkRoot

	local title="Setting proxy configuration..."
	local alert1="File /etc/apt/apt.conf will be replaced"
	local alert2="Variable http_proxy will be set or replaced"
	local success="Configuration complete"
	local alert3="To clean proxy configuration, use proxyUnset command"

	log_warning_msg $title
	log_warning_msg $alert1
	log_warning_msg $alert2

	read -p "Username: " proxy_uid
	read -sp "Password: " proxy_pwd; echo
  	read -p "Proxy IP: " proxy_ip
  	read -p "Proxy port: " proxy_port

	proxy_pwd=$(urlEncode $proxy_pwd)
	bash -c "echo -e 'Acquire::http::Proxy \"http://$proxy_uid:$proxy_pwd@$proxy_ip:$proxy_port/\";' > /etc/apt/apt.conf"
	export http_proxy=http://$proxy_uid:$proxy_pwd@$proxy_ip:$proxy_port/

	log_success_msg $success
	log_warning_msg $alert3

}

function proxyUnset {

	checkRoot
	local title="Cleanning proxy configuration"
	local alert1="File /etc/apt/apt.conf will be replaced"
	local alert2="Variable http_proxy will be unset"
	local success="Configuration complete"
	local alert3="To set proxy configuration, use proxySet command"
	log_warning_msg $title
	log_warning_msg $alert1
	log_warning_msg $alert2
	echo "Press any key to continue..."
	read -n 1 x
	bash -c "echo -e '' > /etc/apt/apt.conf"
	unset http_proxy
	log_success_msg $success
	log_warning_msg $alert3

}
