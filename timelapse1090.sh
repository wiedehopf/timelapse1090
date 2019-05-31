#!/bin/bash

trap "kill 0" SIGINT
trap "kill -2 0" SIGTERM

source default
dir=/run/timelapse1090
CS=100
hist=$(($HISTORY*3600/$INTERVAL))
chunks=$(($hist/$CS))


while true
do
	cd $dir
	rm *.gz
	rm *.json

	cp $SOURCE/receiver.json $dir/receiver.json
	sed -i -e "s/refresh\" : [0-9]*/refresh\" : ${INTERVAL}000/" $dir/receiver.json
	sed -i -e "s/history\" : [0-9]*/history\" : $hist/" $dir/receiver.json

	i=0
	j=0
	while true
	do
		cd $dir
		cp $SOURCE/aircraft.json .
		cp aircraft.json history_$((i%$CS)).json


		if [[ $((i%5)) == 0 ]]
		then
			sed -s '$adirty_hack' history_*.json | sed '$d' | gzip > temp.gz
			mv temp.gz chunk_$(($j%$chunks)).gz
		fi

		i=$((i+1))
		if [[ $((i%CS)) == 0 ]]
		then
			j=$((j+1))
			rm history*.json
		fi
		sleep $INTERVAL
	done
	sleep 5
done &

while true
do
	sleep 1024
done &

wait

exit 0

