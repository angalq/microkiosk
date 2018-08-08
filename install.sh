#! /bin/bash

# Abort if any command fails. See more in 'help set'.
set -e

# Constants
BROWSER_SHORTCUT_SRC=https://raw.githubusercontent.com/angalq/microkiosk/master/browser.desktop
OPENBOX_CONTEXT_MENU=https://raw.githubusercontent.com/angalq/microkiosk/master/menu.xml
OPENBOX_CONFIGURATION=https://raw.githubusercontent.com/angalq/microkiosk/master/rc.xml

function installDependencies {
    echo -e "\n## Installing dependencies...\n"
	apt-get -q=2 update
    apt-get -q=2 install --no-install-recommends xorg xterm openbox pulseaudio libgtk-3-0 libxss1 libnss3 libnspr4 libgconf-2-4
	apt-get -q=2 install python-minimal python-xdg cups openssh-server
	echo -e "\n## Dependencies installed!\n"
}

function installBrowser {
    echo -e "\n## Installing the browser...\n"
	echo -e "\n# Write the URL where are the compacted (tar.gz) binaries \n"
	# The 'echo' command, after the input read, forces new lines to be writen
	read -p "URL: " url; echo
    wget --connect-timeout=5 --tries=1 -nv -P ~/ $url -O browser.tar.gz
    tar --overwrite -zxf ~/browser.tar.gz
	
	if [ -d /opt/browser ]
	then
        rm -R -f /opt/browser
	fi
	
	mv -f ~/browser/ /opt/
	rm -R -f ~/browser.tar.gz
    chown -R root /opt/browser
    chgrp -R root /opt/browser
    
	files=`find /opt/nain/ -type f`
    
	for file in $files
    do
        if [ $(basename $file) != "browser" ]; then
            sudo chmod -x $file
        fi
    done
    
	ln -f -s /opt/browser/browser /usr/local/bin
    wget --connect-timeout=5 --tries=1 -nv -P ~/ $BROWSER_SHORTCUT_SRC
    mv -f ~/browser.desktop /etc/xdg/autostart/
	echo -e "\n## Browser installed!\n"
}

function configureEnvironment {
    echo -e "\n## Configuring environment...\n"
	
	echo -e "\n# Write the URL where is the public key to access the SSH service\n"
	read -p "URL: " url; echo
	wget --connect-timeout=5 --tries=1 -nv -P ~/ $url -O key.pub
	mkdir -p ~/.ssh
	touch ~/.ssh/authorized_keys
	cat ~/key.pub >> ~/.ssh/authorized_keys
	rm -f ~/key.pub
	
	# The 'backtick' command returns the command messages to the default output. With -q, grep doesn't output any message.
	value=`grep -q "# The sshd_config for kiosk" < /etc/ssh/sshd_config; echo $?`
	if [ "$value" -ne 0 ]
	then
	    # O redirecionamento de saída '>>' não funciona no terminal corrente. É preciso abrir um subterminal para executá-lo
	    bash -c "echo -e '# The sshd_config for kiosk\nPort 22\nProtocol 2\nHostKey /etc/ssh/ssh_host_rsa_key\nHostKey /etc/ssh/ssh_host_dsa_key\nHostKey /etc/ssh/ssh_host_ecdsa_key\nHostKey /etc/ssh/ssh_host_ed25519_key\nUsePrivilegeSeparation yes\nKeyRegenerationInterval 3600\nServerKeyBits 1024\nSyslogFacility AUTH\nLogLevel INFO\nLoginGraceTime 120\nPermitRootLogin no\nStrictModes yes\nRSAAuthentication yes\nPubkeyAuthentication yes\nAuthorizedKeysFile     %h/.ssh/authorized_keys\nIgnoreRhosts yes\nRhostsRSAAuthentication no\nHostbasedAuthentication no\nPermitEmptyPasswords no\nChallengeResponseAuthentication no\nPasswordAuthentication no\nX11Forwarding yes\nX11DisplayOffset 10\nPrintMotd no\nPrintLastLog yes\nTCPKeepAlive yes\nAcceptEnv LANG LC_*\nSubsystem sftp /usr/lib/openssh/sftp-server\nUsePAM no\n' > /etc/ssh/sshd_config"
	fi
	
	value=`grep -q "user" < /etc/passwd; echo $?`
	if [ "$value" -ne 0 ]
	then
	    adduser user --disabled-password --gecos ""
	fi
	
    mkdir -p /home/user/.config/openbox/
    wget --connect-timeout=5 --tries=1 -nv -P ~/ $OPENBOX_CONTEXT_MENU -O menu.xml
    mv -f ~/menu.xml /home/user/.config/openbox/
    wget --connect-timeout=5 --tries=1 -nv -P ~/ $OPENBOX_CONFIGURATION -O rc.xml
    mv -f ~/rc.xml /home/user/.config/openbox/
    usermod -a -G audio user
	
	value=`grep -q "# Start at login time the graphical environment" < /home/usuario/.bashrc; echo $?`
	if [ "$value" -ne 0 ]
	then
	    bash -c "echo -e '\n# Start at login time the graphical environment\nif [[ ! \$WAYLAND_DISPLAY && ! \$DISPLAY && \$XDG_VTNR -eq 1 ]]; then\n\texec startx >/dev/null 2>&1; logout\nfi' >> /home/usuario/.bashrc"
	fi
    
	chown root /home/usuario/.bashrc
    chgrp root /home/usuario/.bashrc
    chown root /home/usuario/.bash_logout
    chgrp root /home/usuario/.bash_logout
    chown root /home/usuario/.profile
    chgrp root /home/usuario/.profile
	mkdir -p /etc/systemd/system/getty@tty1.service.d
    touch /etc/systemd/system/getty@tty1.service.d/override.conf
	
	value=`grep -q "[Service]" < /etc/systemd/system/getty@tty1.service.d/override.conf; echo $?`
	if [ "$value" -ne 0 ]
	then
        bash -c "echo -e '[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin usuario --nohints --nohostname %I \$TERM\nType=simple\nRestart=always\nTTYReset=yes\nTTYVTDisallocate=yes\n' >> /etc/systemd/system/getty@tty1.service.d/override.conf"
	fi
	
	value=`grep -q "# GRUB configuration for kiosk" < /etc/default/grub; echo $?`
	if [ "$value" -ne 0 ]
	then
        bash -c "echo -e '# GRUB configuration for kiosk\n\nGRUB_DEFAULT=0\nGRUB_HIDDEN_TIMEOUT=0\nGRUB_HIDDEN_TIMEOUT_QUIET=true\nGRUB_TIMEOUT=0\nGRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`\nGRUB_CMDLINE_LINUX_DEFAULT=\"quiet loglevel=0\"\nGRUB_CMDLINE_LINUX=\"console=tty12\"\nGRUB_DISABLE_RECOVERY=\"true\"\n' > /etc/default/grub"
	fi
	
    echo -e "\n## Defines the user and password for GRUB"
	read -p "Username: " grub_uid
    read -sp "Password: " passw1; echo
    read -sp "Repeat password: " passw2; echo -e "\n"
	# The credits for the command below are:
	# https://github.com/ryran/burg2-mkpasswd-pbkdf2
    grub_pwd=`echo -e "$passw1\n$passw2" | grub-mkpasswd-pbkdf2 | awk '/grub.pbkdf/{print$NF}'`
	
	value=`grep -q "set superusers" < /etc/grub.d/40_custom; echo $?`
	if [ "$value" -ne 0 ]
	then
        bash -c "echo -e '#!/bin/sh\nexec tail -n +3 \$0\nset superusers=\"$grub_uid\"\npassword_pbkdf2 $grub_uid $grub_pwd\n' > /etc/grub.d/40_custom"
	fi
	
	value=`grep -q 'CLASS="--class gnu-linux --class gnu --class os --unrestricted"' < /etc/grub.d/10_linux; echo $?`
	if [ "$value" -ne 0 ]
	then
         sed 's:CLASS="--class gnu-linux --class gnu --class os:& --unrestricted:' < /etc/grub.d/10_linux > ~/10_linux
		 mv -f ~/10_linux /etc/grub.d/
		 chmod +x /etc/grub.d/10_linux
	fi
	
	value=`grep -q "# The logind configuration for kiosk" < /etc/default/grub; echo $?`
	if [ "$value" -ne 0 ]
	then
        bash -c "echo -e '# The logind configuration for kiosk\n[Login]\nNAutoVTs=1\nReserveVT=0\n' > /etc/systemd/logind.conf"
	fi
	
	update-grub

	chmod -x /etc/update-motd.d/*
	echo -e "\n## Environment configured!\n"
}


# Check if the current user is root
if [[ $EUID -ne 0 ]]; then
   echo "## This script needs to be executed with root privilegies" 1>&2
   exit 1
fi

case "$1" in
--dependencies)
	installDependencies
	;;
--browser)
    installDependencies
	installBrowser
	;;
--environment-configuration)
    installDependencies
	configureEnvironment
	;;
--all)
    installDependencies
	installBrowser
	configureEnvironment
	;;
*)
    echo "Use: $0 (--dependencies | --browser | --environment-configuration | --all)"
esac
