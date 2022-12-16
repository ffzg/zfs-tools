#!/bin/sh -e

ip link | grep DOWN | grep -- -br | cut -d: -f2 | while read link ; do
	if=$( echo $link | cut -d@ -f1 )
	br=$( echo $if | cut -d- -f2 )
	echo "# $link -> $br $if"
	brctl show $br | tee /dev/shm/$br || brctl addbr $br
	grep $if /dev/shm/$br || brctl addif $br $if
	ip link set $if up
	ip link set $br up
done
