#!/bin/sh -x

cd /srv/zfs-tools

(
./zfs-snap-sync.pl lib10:lib10 zamd/lib10
./zfs-snap-sync.pl lib15:lib15 zamd/lib15
./zfs-snap-sync.pl lib20:lib20 zamd/lib20
2>&1 ) | tee /tmp/sync.log


/srv/zfs-tools/zfs-list.pl | tee /dev/shm/zfs-list.txt
