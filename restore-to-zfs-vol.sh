#!/bin/sh -e

pool=`zfs list -H -o name | head -1` # use first pool as target for zvol

if [ -z "$1" ] ; then
	echo "Usage: $0 /path/to/uid.disk0_data.snap"
	exit 1
fi

dump=$1

size=`ls -l $dump | cut -d" " -f5`
size=`expr $size \* 11 \/ 10 \/ 1024 \/ 1024`M # add 10%

#vol_opt="-b 4k -s"
vol_opt="-b 4k -s -o compression=lz4"


instance=`dirname $dump | sed 's!^.*/!!'`
disk=`basename $dump`
disk_nr=`echo $disk | cut -d. -f2 | tr -d a-z_`


echo "# $instance | $disk | $disk_nr | $size"

path=${instance}_$disk_nr
mnt_path=/mnt/$path

umount $mnt_path || true

zfs create -V $size $vol_opt $pool/block/$path

test -d $mnt_path || mkdir $mnt_path

wait_for() {
	echo -n "waiting for $1 " 
	while [ ! -e $1 ] ; do
		echo -n .
		sleep 1
	done
	echo " found"
}

wait_for /dev/zvol/$pool/block/$path

label=`echo $instance | cut -d. -f1`-$disk_nr

time mkfs.ext4 -m 0 -O ^has_journal -L $label /dev/zvol/$pool/block/$path 

#wait_for /dev/disk/by-label/$label

mount LABEL=$label $mnt_path/ -o noatime
cd $mnt_path/
ls -alh $dump
time restore rvf $dump

zfs list $pool/backup/$instance || zfs create $pool/backup/$instance
zfs list $pool/backup/$instance/$disk_nr || zfs create $pool/backup/$instance/$disk_nr

rsync -ravH --numeric-ids --sparse --delete $mnt_path/ /$pool/backup/$instance/$disk_nr/

date=`stat $dump | grep Change: | cut -d" " -f2`
zfs snap $pool/backup/$instance/$disk_nr@$date

while ! umount $mnt_path ; do
	echo -n .
	sleep 1
done
zfs destroy $pool/block/$path
