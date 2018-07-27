#!/bin/sh -xe

snapshot=$1

if [ -z "$snapshot" ]; then
	host_disk=`zfs list -H -o name -r lib15/backup | grep '/[0-9]*$' | iselect --all --name="Select host and disk"`
	echo "# reading snapshots for $host_disk"
	snapshot=`zfs list -o name -r -t snapshot $host_disk | sort -r | iselect --all --name="Select snapshot date to diff"`
	test -z "$snapshot" && echo "no snapshot selected, aborting" && exit 1
fi

test -z "$snapshot" && echo "Usage: $0 zfs-snapshot" && exit 1

sudo zfs list -H -t snapshot -o name $snapshot | while read snapshot ; do
	echo "# clone $snapshot"
	clone=`echo $snapshot | sed -e 's,/backup/,/clone/,' -e 's,/\([0-9]\)@,-\1-,'`
	sudo zfs clone $snapshot $clone
	cd /$clone
	echo "# CTRL+D to exit this shell"
	bash
done
