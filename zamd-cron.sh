#!/bin/sh -x

cd /srv/zfs-tools

/srv/zfs-tools/zamd-ganeti-backup.sh

/srv/zfs-tools/diskrsync.sh

# rotate logs
ls /zamd/log/*.log | while read $logfile ; do
	mv $logfile $logfile-$( date +%Y-%m-%d )
done

/srv/zfs-tools/zfs-list.pl | tee /dev/shm/zfs-list.txt

SNAPS_KEEP=90 /srv/zfs-tools/zfs-snap-to-dr.pl zamd/oscar/dataverse srce01.net.ffzg.hr srce01
SNAPS_KEEP=90 /srv/zfs-tools/zfs-snap-to-dr.pl zamd/oscar/koha.ffzg.hr srce01.net.ffzg.hr srce01
