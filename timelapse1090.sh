#!/bin/bash

trap "kill 0" SIGINT
trap "kill -2 0" SIGTERM
SOURCE=/run/dump1090-fa
INTERVAL=10
HISTORY=24
CS=240
source /etc/default/timelapse1090

if [ $(($CHUNK_SIZE)) -lt 1 ]
# default remains set if CHUNK_SIZE is not set in configuration file
then true
elif [ $(($CHUNK_SIZE)) -lt 10 ]
# minimum allowed chunk size
then
	CS=10
elif [ $(($CHUNK_SIZE)) -lt 10000 ]
# if chunk size larger than this, use default
then
	CS=$CHUNK_SIZE
fi


dir=/run/timelapse1090
#hist=$(($HISTORY*3600/$INTERVAL))
hist=$(awk "BEGIN {printf \"%.0f\", $HISTORY * 3600 / $INTERVAL}")
chunks=$(( $hist/$CS + 2 ))
#increase chunk size to get history size as close as we can
CS=$(( CS - ( (CS - hist % CS)/(chunks-1) ) ))


while true
do
	cd $dir
	rm -f *.gz
	rm -f *.json

	if ! cp $SOURCE/receiver.json .
	then
		sleep 60
		continue
	fi
	sed -i -e "s/refresh\" : [0-9]*/refresh\" : ${INTERVAL}000/" $dir/receiver.json
	sed -i -e "s/history\" : [0-9]*/history\" : $((chunks+1))/" $dir/receiver.json

	i=0
	j=0
	while true
	do
		sleep $INTERVAL &


		cd $dir

		date=$(date +%s%N | head -c-7)

		if ! cp $SOURCE/aircraft.json history_$date.json &>/dev/null
		then
			sleep 0.05
			cp $SOURCE/aircraft.json history_$date.json
		fi
		if ! [ -f history_$date.json ]; then
			continue
		fi

		sed -i -e '$a,' history_$date.json


		if [[ $((i%42)) == 41 ]]
		then
			sed -e '1i{ "files" : [' -e '$a]}' -e '$d' history_*.json | gzip -5 > temp.gz
			mv temp.gz chunk_$j.gz
			echo "{ \"files\" : [ ] }" | gzip -1 > rec_temp.gz
			mv rec_temp.gz chunk_$chunks.gz
			rm -f latest_*.json
		else
			if [ -f history_$date.json ]; then
				ln -s history_$date.json latest_$date.json
			fi
			if [[ $((i%7)) == 6 ]]
			then
				sed -e '1i{ "files" : [' -e '$a]}' -e '$d' latest_*.json | gzip -2 > temp.gz
				mv temp.gz chunk_$chunks.gz
			fi
		fi

		i=$((i+1))

		if [[ $i == $CS ]]
		then
			sed -e '1i{ "files" : [' -e '$a]}' -e '$d' history_*.json | 7za a -si temp.gz >/dev/null
			mv temp.gz chunk_$j.gz
			echo "{ \"files\" : [ ] }" | gzip -1 > rec_temp.gz
			mv rec_temp.gz chunk_$chunks.gz
			rm -f history*.json
			rm -f latest_*.json
			i=0
			j=$((j+1))
			if [[ $j == $chunks ]]
			then
				j=0
			fi
		fi

		wait
	done
	sleep 5
done &

wait

exit 0

