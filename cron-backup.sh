#!/bin/sh -xe

# add authorized key on ganeti master node with
# command="/srv/gnt-info/gnt-lv-snap-rsync.sh -" ssh-rsa

/srv/zfs-tools/backup-instances-today.sh | xargs -i echo 'echo {} | ssh -i /root/.ssh/lib30-id_rsa lib30 | tee "/dev/shm/cron.{}.log"' | tee /dev/shm/cron.sh
sh -xe /dev/shm/cron.sh
/srv/zfs-tools/zfs-list.pl 
