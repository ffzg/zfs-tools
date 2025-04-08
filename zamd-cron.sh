#!/bin/sh -x

cd /srv/zfs-tools

/srv/zfs-tools/zamd-ganeti-backup.sh

# moved to rsync-ganeti.sh
#/srv/zfs-tools/fix-permission-denied.sh

/srv/zfs-tools/diskrsync.sh

#./zfs-snap-sync.pl r1u38:zfs zamd/proxmox/r1u38
./r1u38-pull-backup.sh

sh -x mlin-pull.sh

ZFS_POOL=zamd /srv/zfs-tools/zfs-list.pl | tee /dev/shm/zfs-list.txt

#SNAPS_KEEP=60 /srv/zfs-tools/zfs-snap-to-dr.pl zamd/oscar/dataverse srce02.net.ffzg.hr srce02
SNAPS_KEEP=60 /srv/zfs-tools/zfs-snap-to-dr.pl zamd/proxmox/r1u38/vm-119-disk-0 srce02.net.ffzg.hr srce02
SNAPS_KEEP=60 /srv/zfs-tools/zfs-snap-to-dr.pl zamd/oscar/koha.ffzg.hr srce02.net.ffzg.hr srce02
# rasip
SNAPS_KEEP=60 /srv/zfs-tools/zfs-snap-to-dr.pl zamd/proxmox/r1u38/vm-112-disk-0 srce02.net.ffzg.hr srce02

sudo -u dpavlin /home/dpavlin/wordfence-ws-scan.sh
