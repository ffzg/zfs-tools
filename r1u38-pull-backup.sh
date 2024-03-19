#!/bin/sh

today=$( date +%Y-%m-%d )

#ssh r1u38 zfs list -o name -t volume | grep -f r1u38.backup | xargs -i echo zfs snap {}@$today | tee /dev/shm/r1u38.sh
#scp /dev/shm/r1u38.sh r1u38:/tmp/
#ssh r1u38 sh -x /tmp/r1u38.sh

./zfs-snap-sync.pl r1u38:zfs zamd/proxmox/r1u38

# TODO: expire snapshots on r1u38
