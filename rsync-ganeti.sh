#!/bin/sh -x

cluster=$1
instance=$2
disk=$3

today=$( date +%Y-%m-%d )

(
	ssh root@$cluster.gnt.ffzg.hr /srv/gnt-info/gnt-lv-snap-shell.sh $instance $disk | \
		tee /dev/shm/snap.$instance.$disk

	rsync_from=$( cat /dev/shm/snap.$instance.$disk| grep rsync-from | cut -d' ' -f2 )
	rsync_args=$( test -f /zamd/$cluster/$instance/rsync.args && cat /zamd/$cluster/$instance/rsync.args )
	rsync -ravHXAz --numeric-ids --inplace --delete $rsync_args \
		--log-file-format="$cluster $instance $disk %o %m %f %l" \
		--log-file=/zamd/log/rsync.log-$today \
		$rsync_from /zamd/$cluster/$instance/$disk/ && \
		zfs snap zamd/$cluster/$instance/$disk@$today
	cat /dev/shm/snap.$instance.$disk | grep umount | sh -xe
2>&1 ) | tee -a /dev/shm/$cluster.log

