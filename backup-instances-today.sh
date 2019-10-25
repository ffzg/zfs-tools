#!/bin/sh -e

test -z "$backup" && backup="backup"
run=/dev/shm/$backup
pool=`zpool list -o name -H`

:> $run.instances
:> $run.instances.finished

now_i=`date +%Y%m%d`
zfs list -H -o name -t snapshot -r $pool/$backup | grep '/[0-9]@20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]$' | tee $run.snapshots | while read snapshot ; do
	instance=`echo $snapshot | cut -d@ -f1 | cut -d/ -f3`
	disk=`echo $snapshot | cut -d@ -f1 | cut -d/ -f4`
	date=`echo $snapshot | cut -d@ -f2`

	#echo "# $instance $disk $date"

	date_i=`echo $date | sed 's/-//g'`
	if [ $date_i -lt $now_i ] ; then
		#echo "OLD $instance $disk $date"
		echo "$instance $disk" >> $run.instances
	elif [ $date_i -eq $now_i ] ; then
		#echo "EXISTING $instance $disk $date"
		echo "$instance $disk" >> $run.instances.finished
	else
		#echo "ERROR $snapshot $instance $disk $date"
		exit 1
	fi
done

grep -v -f $run.instances.finished $run.instances | sort -u
