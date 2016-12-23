#!/bin/sh -e

pool=`zfs list -H -o name | head -1` # use first pool as target for zvol

if [ -z "$1" ] ; then
	echo "Usage: $0 /path/to/uid.disk0_data.snap"
	exit 1
fi

dump=$1

size=`ls -l $dump | cut -d" " -f5`

instance=`dirname $dump | sed -e 's!^.*/!!' -e 's/.new$//'`
disk=`basename $dump`
disk_nr=`echo $disk | cut -d. -f2 | tr -d a-z_`


echo "# $instance | $disk | $disk_nr | $size"

zfs list $pool/backup/$instance || zfs create $pool/backup/$instance
zfs list $pool/backup/$instance/$disk_nr || zfs create $pool/backup/$instance/$disk_nr
cd /$pool/backup/$instance/$disk_nr

ls -alh $dump
time restore rvf $dump

date=`stat $dump | grep Change: | cut -d" " -f2`
zfs snap $pool/backup/$instance/$disk_nr@$date

