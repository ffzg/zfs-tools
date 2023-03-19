#!/bin/sh -e

cd /srv/zfs-tools

ssh root@cluster.gnt.ffzg.hr /srv/gnt-info/gnt-lv-remove-snap.sh
ssh root@oscar.gnt.ffzg.hr /srv/gnt-info/gnt-lv-remove-snap.sh

:> /dev/shm/cluster.log
:> /dev/shm/oscar.log
:> /dev/shm/backup.today.sh
:> /dev/shm/backup.errors

today=$( date +%Y-%m-%d )

zfs list -H -o name -d 2 zamd/cluster zamd/oscar | grep '/[0-9]$' | while read path ; do
	cluster=$( echo $path | cut -d / -f 2 )
	instance=$( echo $path | cut -d / -f 3 )
	disk=$( echo $path | cut -d / -f 4 )
	zfs list -H -t snapshot $path@$today || echo "/srv/zfs-tools/rsync-ganeti.sh $cluster $instance $disk" >> /dev/shm/backup.today.sh
done

sh -x /dev/shm/backup.today.sh

test -s /dev/shm/backup.errors && mail -s "zamd backup errors" dpavlin+zamd@ffzg.hr,dpavlin+zamd@zamd.ffzg.hr < /dev/shm/backup.errors 
