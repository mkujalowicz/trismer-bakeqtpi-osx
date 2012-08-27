#!/bin/bash
#This script will download, set up, compile QT5, and set up the SDCard image ready to use.
#Pass -h to use https for git

OPT=~/opt
CC=$OPT/gcc-4.7-linaro-rpi-gnueabihf
CCT=$OPT/cross-compile-tools
MOUNT=/mnt/rasp-pi-rootfs

RASPBIAN_HTTP=http://ftp.snt.utwente.nl/pub/software/rpi/images/raspbian/2012-08-16-wheezy-raspbian/2012-08-16-wheezy-raspbian.zip
RASPBIAN_TORRENT=http://downloads.raspberrypi.org/images/raspbian/2012-08-16-wheezy-raspbian/2012-08-16-wheezy-raspbian.zip.torrent
RASPBIAN_FILE=2012-08-16-wheezy-raspbian

CC_GIT="gitorious.org/cross-compile-tools/cross-compile-tools.git"
QT_GIT="gitorious.org/qt/qt5.git"
GIT=GIT
INITREPOARGS="--no-webkit -f"

while getopts ":h" opt; do
  case $opt in
    h)
      GIT=HTTPS
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

if [ "$GIT" == "HTTPS" ]; then
	CC_GIT="https://git."$CC_GIT
	QT_GIT="https://git."$QT_GIT
	INITREPOARGS="$INITREPOARGS --http"
else
	CC_GIT="git://"$CC_GIT
	QT_GIT="git://"$QT_GIT
fi


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
		9) echo "Configuring QT Failed"
		;;
		10) echo "Make failed for QTBase"
		;;
		*) echo "Unknown error"
		;;

	esac
	exit -1
}

function downloadAndMountPi {
	cd $OPT
	echo "Would you like to download the Raspbian image using HTTP(H) or ctorrent(T)"
	read -e dl

	while [[ ! $dl =~ [TtHh] ]]; do
		echo "Please type H for HTTP or T for ctorrent"
		read dl
	done

	if [[ $dl =~ [Hh] ]]; then
		wget -c $RASPBIAN_HTTP || error 2
	else
		wget $RASPBIAN_TORRENT || error 2
		ctorrent -a -e - $RASPBIAN_FILE.zip.torrent || error 2
	fi

	unzip $RASPBIAN_FILE.zip || error 2
	if [ ! -d $MOUNT ]; then
		sudo mkdir $MOUNT || error 3
	else
		sudo umount $MOUNT
	fi
	sudo mount -o loop,offset=62914560 $RASPBIAN_FILE.img $MOUNT || error 3
}

#Download and extract cross compiler and tools
function dlcc {
	cd $OPT
	wget -c http://blueocean.qmh-project.org/gcc-4.7-linaro-rpi-gnueabihf.tbz || error 4
	tar -xf gcc-4.7-linaro-rpi-gnueabihf.tbz || error 5
	if [ ! -d $CCT/.git ]; then
		git clone git://gitorious.org/cross-compile-tools/cross-compile-tools.git || error 4
	else
		cd $CCT && git pull && cd $OPT
	fi
}

function dlqt {
	cd $OPT
	if [ ! -d $OPT/qt5/.git ]; then
		git clone git://gitorious.org/qt/qt5.git || error 6
	else
		cd $OPT/qt5/ && git pull && cd ..
	fi
	cd qt5
	while [ ! -e $OPT/qt5/.initialised ]
	do
		./init-repository $INITREPOARGS && touch $OPT/qt5/.initialised
	done || error 7
	cd $OPT/qt5/qtjsbackend
	git fetch https://codereview.qt-project.org/p/qt/qtjsbackend refs/changes/56/27256/4 && git cherry-pick FETCH_HEAD
}

function prepcctools {
	cd $CCT
	./fixQualifiedLibraryPaths $MOUNT $CC/bin/arm-linux-gnueabihf-gcc || error 8
	cd $OPT/qt5/qtbase
}

function configureandmakeqtbase {
	cd $OPT/qt5/qtbase
	./configure -opengl es2 -device linux-rasp-pi-g++ -device-option CROSS_COMPILE=$CC/bin/arm-linux-gnueabihf- -sysroot $MOUNT -opensource -confirm-license -optimized-qmake -reduce-relocations -reduce-exports -release -make libs -prefix /usr/local/qt5pi -nomake examples -nomake tests -no-pch || error 9
	CORES=`cat /proc/cpuinfo | grep "cpu cores" -m 1 | awk '{print $4}'`
	if [ `echo $CORES | awk '$1+0==$1'` ]; then
		make -j $CORES || error 10
	else
		make || error 10
	fi
}

function installqtbase {
	cd $OPT/qt5/qtbase
	sudo make install
}

function makemodules {
	for i in qtimageformats qtsvg qtjsbackend qtscript qtxmlpatterns qtdeclarative qtsensors qt3d qtgraphicaleffects qtjsondb qtlocation qtquick1 qtsystems qtmultimedia
	do
		cd $OPT/qt5/$i && echo "Building $i" && sleep 3 && /usr/local/qt5pi/bin/qmake . && make -j5 && sudo make install && touch .COMPILED
		cd $OPT/qt5/
	done
	
	for i in qtimageformats qtsvg qtjsbackend qtscript qtxmlpatterns qtdeclarative qtsensors qt3d qtgraphicaleffects qtjsondb qtlocation qtquick1 qtsystems qtmultimedia
	do
		if [ -e $OPT/qt5/$i/.COMPILED ]
		then
			echo "Compiled $i"
		else
			echo "Failed   $i"
		fi
	done
}
#Start of script

mkdir -p $OPT || error 1
cd $OPT || error 1

downloadAndMountPi
dlcc
dlqt
prepcctools
configureandmakeqtbase
makemodules
