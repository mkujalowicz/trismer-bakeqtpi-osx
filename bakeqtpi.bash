#!/bin/bash

function error {
	case "$1" in

		1) echo "Error making directories"
		;;
		2) echo "Error downloading raspbian image"
		;;
		3) echo "Error mounting raspbian image"
		;;
		4) echo "Error downloading cross compilation tools"
		;;
		5) echo "Error extracting cross compilation tools"
		;;
		6) echo "Error cloning qt5 repo"
		;;
		7) echo "Error initialising qt5 repo"
		;;
		8) echo "Error running fixQualifiedLibraryPaths"
		;;
		*) echo "Unknown error"
		;;

	esac
	exit -1
}

function downloadAndMountPi {
	echo "Would you like to download the Raspbian image using HTTP(H) or ctorrent(T)"
	read -e dl

	while [[ ! $dl =~ [TtHh] ]]; do
		echo "Please type H for HTTP or T for ctorrent"
		read dl
	done

	if [[ $dl =~ [Hh] ]]; then
		wget -c http://ftp.snt.utwente.nl/pub/software/rpi/images/raspbian/2012-08-16-wheezy-raspbian/2012-08-16-wheezy-raspbian.zip || error 2
	else
		wget http://downloads.raspberrypi.org/images/raspbian/2012-08-16-wheezy-raspbian/2012-08-16-wheezy-raspbian.zip.torrent || error 2
		ctorrent -a -e - 2012-08-16-wheezy-raspbian.zip.torrent || error 2
	fi

	unzip 2012-08-16-wheezy-raspbian.zip || error 2
	if [ ! -d /mnt/rasp-pi-rootfs ]; then
		sudo mkdir /mnt/rasp-pi-rootfs || error 3
	else
		sudo umount /mnt/rasp-pi-rootfs
	fi
	sudo mount -o loop,offset=62914560 2012-08-16-wheezy-raspbian.img /mnt/rasp-pi-rootfs || error 3
}

#Download and extract cross compiler and tools
function dlcc {
	wget -c http://blueocean.qmh-project.org/gcc-4.7-linaro-rpi-gnueabihf.tbz || error 4
	tar -xf gcc-4.7-linaro-rpi-gnueabihf.tbz || error 5
	git clone git://gitorious.org/cross-compile-tools/cross-compile-tools.git || error 4
}

function dlqt {
	git clone git://gitorious.org/qt/qt5.git || error 6
	cd qt5
	while [ ! -e ~/opt/qt5/.initialised ]
	do
		./init-repository --no-webkit -f && touch ~/opt/qt5/.initialised
	done || error 7
	cd ~/opt/qt5/qtjsbackend
	git fetch https://codereview.qt-project.org/p/qt/qtjsbackend refs/changes/56/27256/4 && git cherry-pick FETCH_HEAD
}

function prepcctools {
	cd ~/opt/cross-compile-tools
	./fixQualifiedLibraryPaths /mnt/rasp-pi-rootfs/ ~/opt/gcc-4.7-linaro-rpi-gnueabihf/bin/arm-linux-gnueabihf-gcc || error 8
	cd ~/opt/qt5/qtbase
}

#Start of script

mkdir -p ~/opt || error 1
cd ~/opt || error 1

downloadAndMountPi
dlcc
dlqt
prepcctools
