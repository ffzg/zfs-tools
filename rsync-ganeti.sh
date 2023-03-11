#!/bin/sh -xe

cluster=$1
instance=$2
disk=$3

today=$( date +%Y-%m-%d )
test -d /zamd/log/rsync/$instance || mkdir -p /zamd/log/rsync/$instance

(
	ssh root@$cluster.gnt.ffzg.hr /srv/gnt-info/gnt-lv-snap-shell.sh $instance $disk | \
		tee /dev/shm/snap.$instance.$disk

	rsync_from=$( cat /dev/shm/snap.$instance.$disk| grep rsync-from | cut -d' ' -f2 )
	rsync_args=$( test -f /zamd/$cluster/$instance/rsync.args && cat /zamd/$cluster/$instance/rsync.args || true )
	if rsync -raHXAz --numeric-ids --inplace --delete $rsync_args \
		--log-file=/zamd/log/rsync/$instance/$today \
		$rsync_from /zamd/$cluster/$instance/$disk/ 2>&1
		then
			zfs snap zamd/$cluster/$instance/$disk@$today
		else
       			echo $cluster $instance $disk >> /dev/shm/backup.errors
	fi
	cat /dev/shm/snap.$instance.$disk | grep umount | sh -xe
2>&1 ) | tee -a /dev/shm/$cluster.log

