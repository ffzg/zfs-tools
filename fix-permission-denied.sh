#!/bin/sh

today=$( date +%Y-%m-%d ) 

:> /dev/shm/fix-permission.sh

cat /dev/shm/backup.errors | while read cluster instance disk ; do

	if zfs list -t snapshot zamd/$cluster/$instance/$disk@$today ; then
		echo "OK"
	else

		grep rsync: /zamd/log/rsync/$instance/$today | grep 'Permission denied' | sed -e 's/^.*open "//' -e 's/".*$//' | tee /dev/shm/fix-permissions.files | xargs rm -v
		echo /srv/zfs-tools/rsync-ganeti.sh $cluster $instance $disk >> /dev/shm/fix-permission.sh
	fi
done

sh /dev/shm/fix-permission.sh
