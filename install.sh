#!/bin/bash

repository="https://github.com/wiedehopf/timelapse1090/archive/master.zip"
ipath=/usr/local/share/timelapse1090
install=0

packages="lighttpd unzip p7zip-full "

if ! id -u timelapse1090 &>/dev/null
then
    adduser --system --home $ipath --no-create-home --quiet timelapse1090
fi

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
	if ! wget --timeout=30 -q -O master.zip $repository || ! unzip -q -o master.zip
	then
		echo "Unable to download files, exiting! (Maybe try again?)"
		exit 1
	fi
	cd timelapse1090-master
fi

changed=0
 diff timelapse1090.sh /usr/local/share/timelapse1090/timelapse1090.sh &>/dev/null \
	&&  diff timelapse1090.service /lib/systemd/system/timelapse1090.service &>/dev/null \
	&&  diff 88-timelapse1090.conf /etc/lighttpd/conf-available/88-timelapse1090.conf &>/dev/null \
	&&  diff 88-timelapse1090.conf /etc/lighttpd/conf-enabled/88-timelapse1090.conf &>/dev/null
changed=$?

cp -n default /etc/default/timelapse1090
cp timelapse1090.service /lib/systemd/system

cp 88-timelapse1090.conf /etc/lighttpd/conf-available
lighty-enable-mod timelapse1090 >/dev/null

cp -r -T . $ipath

if [ -d /etc/lighttpd/conf-enabled/ ]
then
	while read -r FILE; do
		sed -i -e 's/^server.modules += ( "mod_setenv" )/#server.modules += ( "mod_setenv" )/'  "$FILE"
	done < <(find /etc/lighttpd/conf-available/* | grep -v dump1090-fa)

    # add mod_setenv to lighttpd modules, check if it's one too much
    if [ -f /etc/lighttpd/conf-enabled/87-mod_setenv.conf ]; then
        setenv_file="present"
    fi
    echo 'server.modules += ( "mod_setenv" )' > /etc/lighttpd/conf-available/87-mod_setenv.conf
    ln -s -f /etc/lighttpd/conf-available/87-mod_setenv.conf /etc/lighttpd/conf-enabled/87-mod_setenv.conf
    if lighttpd -tt -f /etc/lighttpd/lighttpd.conf 2>&1 | grep mod_setenv >/dev/null
    then
        rm /etc/lighttpd/conf-enabled/87-mod_setenv.conf
        if [[ "$setenv_file" == "present" ]]; then
            changed=1
        fi
    else
        if [[ "$setenv_file" != "present" ]]; then
            changed=1
        fi
    fi
fi

if [[ "$changed" != 0 ]]; then
    echo "Restarting lighttpd"
	systemctl daemon-reload
	systemctl restart lighttpd
    echo "Restarting timelapse1090"
	systemctl restart timelapse1090
fi
if ! systemctl is-enabled timelapse1090 &>/dev/null; then
	systemctl enable timelapse1090 &>/dev/null
fi


echo --------------
echo "All done! Webinterface available at http://$(ip route | grep -m1 -o -P 'src \K[0-9,.]*')/timelapse"
