#!/bin/sh -xe

cluster=$1
instance=$2
disk=$3

today=$( date +%Y-%m-%d )
test -d /zamd/log/rsync/$instance || mkdir -p /zamd/log/rsync/$instance

(
	:> /zamd/log/rsync/$instance/$today

	ssh root@$cluster.gnt.ffzg.hr /srv/gnt-info/gnt-lv-snap-shell.sh $instance $disk | \
		tee /dev/shm/snap.$instance.$disk

	rsync_from=$( cat /dev/shm/snap.$instance.$disk| grep rsync-from | cut -d' ' -f2 )
	rsync_args=$( test -f /zamd/$cluster/$instance/rsync.args && cat /zamd/$cluster/$instance/rsync.args || true )

	backup_ok=0
	backup_tries=0

	while [ $backup_ok -eq 0 -a $backup_tries -lt 9 ]
	do
		backup_tries=$( expr $backup_tries + 1 )
		echo "## try: $backup_tries $0 $cluster $instance $disk"

		if rsync -raHXAz --numeric-ids --inplace --delete $rsync_args \
			--log-file=/zamd/log/rsync/$instance/$today \
			--log-file-format="%i %n%L %b %l" \
			$rsync_from /zamd/$cluster/$instance/$disk/ 2>&1
			then
				zfs snap zamd/$cluster/$instance/$disk@$today
				backup_ok=1
			else
				echo $cluster $instance $disk >> /dev/shm/backup.errors
				grep rsync: /zamd/log/rsync/$instance/$today | grep 'Permission denied' | sed -e 's/^.*open "//' -e 's/".*$//' | tee /dev/shm/fix-permissions.$instance.files | xargs rm -v
		fi

	done

	cat /dev/shm/snap.$instance.$disk | grep umount | sh -xe
2>&1 ) | tee -a /dev/shm/$cluster.log

