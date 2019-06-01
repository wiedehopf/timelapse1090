#!/bin/bash

ipath=/usr/local/share/timelapse1090
install=0

packages="lighttpd unzip"

for i in $packages
do
	if ! dpkg -s $i 2>/dev/null | grep 'Status.*installed' &>/dev/null
	then
		install=1
	fi
done

if [ $install == 1 ]
then
	echo "Installing required packages: $packages"
	apt-get update
	apt-get upgrade -y
	if ! apt-get install -y $packages
	then
		echo "Failed to install required packages: $packages"
		echo "Exiting ..."
		exit 1
	fi
fi

if [ -z $1 ] || [ $1 != "test" ]
then
	cd /tmp
	if ! wget --timeout=30 -q -O master.zip https://github.com/wiedehopf/timelapse1090/archive/master.zip || ! unzip -q -o master.zip
	then
		echo "Unable to download files, exiting! (Maybe try again?)"
		exit 1
	fi
	cd timelapse1090-master
fi

! diff timelapse1090.sh /usr/local/share/timelapse1090/timelapse1090.sh || ! diff timelapse1090.service /lib/systemd/system/timelapse1090.service
changed=$?

cp -n default /etc/default/timelapse1090
cp timelapse1090.service /lib/systemd/system

cp 88-timelapse1090.conf /etc/lighttpd/conf-available
lighty-enable-mod timelapse1090 >/dev/null

cp -r -T . $ipath

if grep -q '^server.modules += ( "mod_setenv" )' /etc/lighttpd/conf-enabled/89-dump1090-fa.conf
then
	sed -i -e 's/^server.modules += ( "mod_setenv" )/#server.modules += ( "mod_setenv" )/'  $(find /etc/lighttpd/conf-enabled/* | grep -v dump1090-fa)
fi

systemctl daemon-reload
systemctl enable timelapse1090 &>/dev/null
systemctl restart lighttpd
if [ 0 -eq $changed ]; then
	systemctl restart timelapse1090
fi


echo --------------
echo "All done!"
