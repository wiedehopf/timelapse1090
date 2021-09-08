#!/bin/bash
set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR
renice 10 $$

repository="https://github.com/wiedehopf/timelapse1090.git"
ipath=/usr/local/share/timelapse1090
install=0

mkdir -p "$ipath"

packages="lighttpd gzip "

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
	if ! apt-get install -y $packages
	then
		echo "Failed to install required packages: $packages"
		echo "Exiting ..."
		exit 1
	fi
fi

function getGIT() {
    # getGIT $REPO $BRANCH $TARGET-DIR
    if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ -z "$3" ]]; then
        echo "getGIT wrong usage, check your script or tell the author!" 1>&2
        return 1
    fi
    if ! cd "$3" &>/dev/null || ! git fetch --depth 1 origin "$2" || ! git reset --hard FETCH_HEAD; then
        if ! rm -rf "$3" || ! git clone --depth 1 --single-branch --branch "$2" "$1" "$3"; then
            return 1
        fi
    fi
    return 0
}
if [[ "$1" != "test" ]]
then
    cd
    if ! getGIT "$repository" "master" "$ipath/git" || ! cd "$ipath/git"; then
        echo "Unable to download files, exiting! (Maybe try again?)"
		exit 1
	fi
fi

if [[ -f /run/dump1090-fa/aircraft.json ]] ; then
    srcdir=/run/dump1090-fa
elif [[ -f /run/readsb/aircraft.json ]]; then
    srcdir=/run/readsb
elif [[ -f /run/adsbexchange-feed/aircraft.json ]]; then
    srcdir=/run/adsbexchange-feed
elif [[ -f /run/dump1090/aircraft.json ]]; then
    srcdir=/run/dump1090
elif [[ -f /run/dump1090-mutability/aircraft.json ]]; then
    srcdir=/run/dump1090-mutability
elif [[ -f /run/skyaware978/aircraft.json ]]; then
    srcdir=/run/skyaware978
else
    echo --------------
    echo FATAL: could not find aircraft.json in any of the usual places!
    echo "checked these: /run/readsb /run/dump1090-fa /run/dump1090 /run/dump1090-mutability /run/adsbexchange-feed /run/skyaware978"
    echo --------------
    exit 1
fi

cp -n default /etc/default/timelapse1090
changed=0

if ! grep -qs -e "SOURCE=${srcdir}" /etc/default/timelapse1090; then
    changed=1
    sed -i -e "s#SOURCE.*#SOURCE=${srcdir}#" /etc/default/timelapse1090
fi

if ! { diff timelapse1090.sh /usr/local/share/timelapse1090/timelapse1090.sh &>/dev/null \
	&&  diff timelapse1090.service /lib/systemd/system/timelapse1090.service &>/dev/null \
	&&  diff 88-timelapse1090.conf /etc/lighttpd/conf-available/88-timelapse1090.conf &>/dev/null \
	&&  diff 88-timelapse1090.conf /etc/lighttpd/conf-enabled/88-timelapse1090.conf &>/dev/null; }
then
    changed=1
fi

cp timelapse1090.service /lib/systemd/system

cp 88-timelapse1090.conf /etc/lighttpd/conf-available
lighty-enable-mod timelapse1090 >/dev/null || true

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
