#!/bin/bash

trap "kill 0" SIGINT
trap "kill -2 0" SIGTERM
SOURCE=/run/dump1090-fa
INTERVAL=10
HISTORY=24
source /etc/default/timelapse1090

dir=/run/timelapse1090
CS=360
hist=$(($HISTORY*3600/$INTERVAL))
chunks=$(( 1 + ($hist/$CS) ))
partial=$(($hist%$CS))
if [[ $partial != 0 ]]
then actual_chunks=$(($chunks+1))
else actual_chunks=$chunks
fi


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
	sed -i -e "s/history\" : [0-9]*/history\" : $actual_chunks/" $dir/receiver.json

	i=0
	j=0
	while true
	do
		sleep $INTERVAL &


		cd $dir
		cp $SOURCE/aircraft.json history_$((i%$CS)).json
		sed -i -e '$a,' history_$((i%$CS)).json


		if [[ $((i%5)) == 3 ]]
		then
			#sed -s '$adirty_hack' history_*.json | sed '$d' | gzip > temp.gz
			sed -e '1i{ "files" : [' -e '$a]}' -e '$d' history_*.json | gzip > temp.gz
			mv temp.gz chunk_$j.gz
		fi

		i=$((i+1))

		if [[ $i == $CS ]]
		then
			sed -e '1i{ "files" : [' -e '$a]}' -e '$d' history_*.json | gzip > temp.gz
			mv temp.gz chunk_$j.gz
			i=0
			j=$((j+1))
			rm -f history*.json
		fi
		if [[ $j == $chunks ]] && [[ $i == $partial ]]
		then
			sed -e '1i{ "files" : [' -e '$a]}' -e '$d' history_*.json 2>/dev/null | gzip > temp.gz
			mv temp.gz chunk_$j.gz 2>/dev/null
			i=0
			j=0
			rm -f history*.json
		fi

		wait
	done
	sleep 5
done &

while true
do
	sleep 1024
done &

wait

exit 0

