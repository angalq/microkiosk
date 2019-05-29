#! /bin/bash

source ./tools.sh > /dev/null 2>&1

function installDependencies {

	checkRoot
	if [ $? -ne 0 ]; then exit 126; fi
	curl -sL https://de.nodesource.com/setup_12.x | bash -
	apt-get install -y nodejs \
			   live-build live-boot live-tools live-config
			   libnss3 libgdk-pixbuf2.0-0 libgtk-3-0 libxss1 libasound2

}

function buildBrowser {

	cd browser/
	npm install
	npm run package
	cd ..

}

function moveBrowser {

	mv browser/release-builds/browser-linux-x64 system/config/includes.chroot/opt/

}

function clean {

	if [ -d browser/release-builds ]
	then
		rm -R -f browser/release-builds
	fi

	if [ -d system/config/includes.chroot/opt/browser-linux-x64 ]
	then
		rm -R -f system/config/includes.chroot/opt/browser-linux-x64
	fi

	cd system/
	lb clean
	cd ..

}

case $1 in
--clean)
	clean
	;;
--build)
	installDependencies
	buildBrowser
	moveBrowser
	cd system/
	lb clean
	lb config
	lb build
	cd ..
	;;
*)
	echo -e 'Usage: $0 (--clean | --build)'
esac
