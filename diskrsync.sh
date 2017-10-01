#!/bin/sh -e

# https://github.com/dop251/diskrsync

gnt_master=`ssh r1u30 gnt-cluster getmaster`
vg=oscarvg

instance=$1
disk=$2

instance=kappa.ffzg.hr
disk=0

instance=`ssh $gnt_master gnt-instance list --no-headers -o name $instance | head -1`

node=`ssh $gnt_master gnt-instance list -o pnode --no-headers $instance`
echo "# $instance on $node"

ssh $node lvs -o name,tags | grep $instance | tee /dev/shm/$instace.$node.lvs | grep disk${disk}_data | while read lv origin ; do
	disk_nr=`echo $lv | cut -d. -f2 | tr -d a-z_`
	echo "# $lv | $origin | $disk_nr"

	ssh $node lvcreate -L20480m -s -n$lv.snap /dev/$vg/$lv

	time /usr/local/bin/diskrsync --no-compress --verbose $node:/dev/$vg/$lv.snap /lib15/diskrsync/$instance/$disk

	ssh $node lvremove -f /dev/$vg/$lv.snap
	date=`date +%Y-%m-%d`

	zfs snap lib15/diskrsync/$instance@$date
done

zfs list -t snapshot -r lib15/diskrsync


