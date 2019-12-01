#!/bin/sh -e

# https://github.com/dop251/diskrsync

zpool=`sudo zpool list -H -o name | head -1`

# to work with ganeti masterfailover we need to ignore host key
ssh='ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

backup() {
# broken ident for better readability

cluster_node=$1
vg=$2
instance=$3
disk=$4

zfs list $zpool/diskrsync/$instance || ( echo "ERROR fix with: zfs create -p $zpool/diskrsync/$instance" && exit 1 )

gnt_master=`$ssh $cluster_node gnt-cluster getmaster`


instance=`$ssh $gnt_master gnt-instance list --no-headers -o name $instance | head -1`

node=`$ssh $gnt_master gnt-instance list -o pnode --no-headers $instance`
echo "# $instance on $node"

$ssh $node lvs -o name,tags | grep $instance | tee /dev/shm/$instace.$node.lvs | grep disk${disk}_data | while read lv origin ; do
	disk_nr=`echo $lv | cut -d. -f2 | tr -d a-z_`
	echo "# $lv | $origin | $disk_nr"

	$ssh $node lvcreate -L20480m -s -n$lv.snap /dev/$vg/$lv

	time /usr/local/bin/diskrsync --no-compress --verbose $node:/dev/$vg/$lv.snap /$zpool/diskrsync/$instance/$disk

	$ssh $node lvremove -f /dev/$vg/$lv.snap
	date=`date +%Y-%m-%d`

	zfs snap $zpool/diskrsync/$instance@$date
done

}

if [ "$zpool" = "lib15" ] ; then

	backup oscar.gnt.ffzg.hr oscarvg kappa.ffzg.hr 0
	backup cluster.gnt.ffzg.hr ffzgvg theta.ffzg.hr 0

	zfs list -t snapshot -r $zpool/diskrsync

elif [ "$zpool" = "lib20" ] ; then

	backup cluster.gnt.ffzg.hr ffzgvg safeq 0

	zfs list -t snapshot -r $zpool/diskrsync

else
	echo "Unknown pool [$zpool] edit script to add config"
	exit 1
fi
