#!/bin/sh -xe

sudo zfs list -H -t snapshot -o name $1 | while read snapshot ; do
	echo "# $snapshot"
	clone=`echo $snapshot | sed -e 's,/backup/,/clone/,' -e 's,/\([0-9]\)@,-\1-,'`
	sudo zfs clone $snapshot $clone
	cd $clone
	bash
done
