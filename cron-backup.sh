#!/bin/sh -xe

# add authorized key on ganeti master node with
# command="/srv/gnt-info/gnt-lv-snap-rsync.sh -" ssh-rsa

/srv/zfs-tools/backup-instances-today.sh | xargs -i echo 'echo {} | ssh -i /root/.ssh/lib30-id_rsa lib30 | tee "/dev/shm/cron.{}.log"' | tee /dev/shm/cron.sh
sh -xe /dev/shm/cron.sh

export backup=oscar
/srv/zfs-tools/backup-instances-today.sh | xargs -i echo 'echo {} | ssh -i /root/.ssh/r1u28-id_dsa r1u28 | tee "/dev/shm/cron.{}.log"' | tee /dev/shm/cron-$backup.sh

/srv/zfs-tools/zfs-list.pl

/srv/zfs-tools/diskrsync.sh

