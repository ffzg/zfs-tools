#!/bin/sh -x

cd /srv/zfs-tools

/srv/zfs-tools/zamd-ganeti-backup.sh

# moved to rsync-ganeti.sh
#/srv/zfs-tools/fix-permission-denied.sh

/srv/zfs-tools/diskrsync.sh

./zfs-snap-sync.pl r1u38:zfs zamd/proxmox/r1u38

ZFS_POOL=zamd /srv/zfs-tools/zfs-list.pl | tee /dev/shm/zfs-list.txt

SNAPS_KEEP=90 /srv/zfs-tools/zfs-snap-to-dr.pl zamd/oscar/dataverse srce01.net.ffzg.hr srce01
SNAPS_KEEP=90 /srv/zfs-tools/zfs-snap-to-dr.pl zamd/oscar/koha.ffzg.hr srce01.net.ffzg.hr srce01

